import AntennaCore
import Foundation

/// What Live brings back from the last session on iPhone, iPad and Mac
/// (session-restore-and-recently-watched capability): the stored tab and
/// group, the group still to select and the channel still to play.
struct LiveRestore {
    let store: RecentsStore?
    /// As stored: the last tab and the last group the user picked.
    private(set) var session = LiveSession()
    /// The channel to play once its source loads and Live shows; nil once
    /// it played or the user picked a channel.
    var channel: LastChannelKey?
    /// `channel` as saved for launch, tuned before its source loads; nil
    /// when nothing was saved or it has been used.
    var saved: SavedChannel?
    /// The channel tuned from `saved`, until its source's list arrives or
    /// the user picks a channel.
    var started: LastChannelKey?
    /// The group to select once the catalogue has it; nil once selected or
    /// the user picked a group.
    var group: CatalogueGroup?
    /// Live has been on screen since launch.
    var liveShown = false
    /// True while Live is the open tab or section, nil until the screen
    /// has switched to the one it restores. Live shows for a moment before
    /// that switch, so `liveShown` alone does not say the user sees it.
    var onLive: Bool?
    /// The scene has been active since launch. A tune before that leaves
    /// the iPhone tab bar over a sideways full screen.
    var sceneActive = false

    init(store: RecentsStore? = nil) {
        self.store = store
        guard let store else { return }
        session = store.session
        channel = store.read()
        saved = store.readLaunch()
        group = session.group?.group
    }

    /// The tab to open on, as stored.
    var tab: LiveSession.Tab? { session.tab }

    /// The user picked `group`: it is the one to restore, and no other is
    /// selected for them.
    mutating func picked(_ group: CatalogueGroup) {
        self.group = nil
        session.group = LiveSession.Group(group)
        store?.write(session)
    }

    /// The user opened `tab`.
    mutating func opened(_ tab: LiveSession.Tab) {
        if onLive != nil { onLive = tab == .live }
        guard session.tab != tab else { return }
        session.tab = tab
        store?.write(session)
    }
}

extension LiveModel {
    var isPaused: Bool {
        if case .paused = playback { return true }
        return false
    }

    /// Selects the restored group once the catalogue has it, unless the
    /// user picked one first. A group that disappears falls back to the
    /// first group the user may open, All channels unless hidden, while the
    /// channel plays on (session-restore-and-recently-watched/reopen-on-the-same-tab-and-group,
    /// group-management/a-channel-that-gets-locked-stops-playing).
    func restoreGroup() {
        if let wanted = restore.group, catalogue.groups.contains(wanted) {
            group = wanted
            restore.group = nil
        } else if !catalogue.groups.contains(group) {
            group = catalogue.fallbackGroup
        }
    }

    /// Live is on screen: a channel a movie stopped plays again, and the
    /// last channel plays once its source has loaded
    /// (session-restore-and-recently-watched/the-last-channel-plays-again).
    func appeared() {
        restore.liveShown = true
        resumeIfSuspended()
        replay()
    }

    /// Plays the last channel when Live has shown and nothing plays yet:
    /// from its source's list once loaded, or before that from what was
    /// saved for launch. Otherwise it waits for the next source to load
    /// (session-restore-and-recently-watched/the-last-channel-starts-before-its-source-loads).
    func replay() {
        guard restore.liveShown, playing == nil, let key = restore.channel else { return }
        if let channel = loadedChannels(of: key.sourceID)?.first(where: key.matches) {
            restore.channel = nil
            restore.saved = nil
            return tune(channel)
        }
        guard restore.onLive == true, restore.sceneActive, loadedChannels(of: key.sourceID) == nil, let channel = launchChannel(key) else {
            return
        }
        restore.channel = nil
        restore.saved = nil
        restore.started = key
        tune(channel)
    }

    /// The saved channel with its logins put back, when it is `key`'s and
    /// its source has a login here. Its source's User-Agent goes with it.
    private func launchChannel(_ key: LastChannelKey) -> Channel? {
        guard let saved = restore.saved, saved.key == key, let source = descriptors[key.sourceID], dependencies.hasLogin(source),
            let logins = dependencies.launchLogins?(source), let channel = saved.channel(logins: logins)
        else { return nil }
        StreamHeaderBook.shared.register(source.headers, server: channel.streamURL, source: source.id)
        return channel
    }

    /// `source`'s list arrived: the channel started at launch follows it.
    /// The same stream plays on with the list's details, a changed link or
    /// a failed start tunes again, and a channel the list lacks stops
    /// (session-restore-and-recently-watched/the-fresh-list-decides).
    func reconcileLaunch(_ source: UUID) {
        guard let started = restore.started, started.sourceID == source, let fresh = loadedChannels(of: source) else { return }
        restore.started = nil
        guard let playing, started.matches(playing) else { return }
        guard let channel = fresh.first(where: started.matches) else { return stop() }
        let logins = descriptors[source].flatMap { dependencies.launchLogins?($0) } ?? []
        if player.failure == nil, SavedChannel.sameStream(playing, channel, logins: logins) {
            adopt(channel)
        } else {
            tune(channel)
        }
    }

    /// Saves `channel`, the new last channel, for the next launch, or
    /// clears what was saved when it cannot be saved.
    func saveForLaunch(_ channel: Channel) {
        guard let launchLogins = dependencies.launchLogins else { return }
        let logins = channel.sourceID.flatMap { descriptors[$0] }.flatMap(launchLogins)
        session.store.saveLaunch(channel, logins: logins)
    }

    /// The scene became active; the saved channel may start.
    func sceneBecameActive() {
        restore.sceneActive = true
        replay()
    }

    /// The screen switched to the tab or section it restores; `onLive` is
    /// true when that is Live. Live shows for a moment before the switch,
    /// and nothing starts from what was saved for launch until it settles.
    /// The tune waits for the next turn, out of the launch's first appearance.
    func screenRestored(onLive: Bool) {
        restore.onLive = onLive
        Task { [weak self] in self?.replay() }
    }

    /// The screen switched to `tab`, the one it restores. The title watched
    /// last waits for its section to list it when `tab` is that section, and
    /// gives way otherwise (session-restore-and-recently-watched/a-title-that-cannot-open-gives-way).
    func screenRestored(_ tab: LiveSession.Tab) {
        if launchTitle.waiting?.tab == tab {
            launchTitle.start(sleep: dependencies.launchSleep)
        } else {
            launchTitle.drop()
        }
        screenRestored(onLive: tab == .live)
    }

    /// `chosen`, the screen onboarding's Browse movies or a launch screen
    /// other than Live opens, wins over the title watched last
    /// (session-restore-and-recently-watched/a-title-that-cannot-open-gives-way).
    func launchWins<Screen>(_ chosen: Screen?) -> Screen? {
        if chosen != nil { launchTitle.drop() }
        return chosen
    }

    /// The tab to open on: the section of the title watched last, else the
    /// stored tab, where Search, Settings and an unknown tab open Live
    /// (session-restore-and-recently-watched/reopen-on-the-same-tab-and-group).
    var restoredTab: LiveSession.Tab {
        if let title = launchTitle.waiting { return title.tab }
        return switch restore.tab {
        case .guide: .guide
        case .movies: .movies
        case .series: .series
        case .live, .search, .settings, nil: .live
        }
    }

    /// The user opened `tab`; the next launch opens on it, and the channel
    /// pauses behind Movies, Series and Search
    /// (live-tv-on-iphone-ipad-mac/the-channel-pauses-behind-movies-series-and-search).
    func opened(_ tab: LiveSession.Tab) {
        if let title = launchTitle.waiting, title.tab != tab { launchTitle.drop() }
        restore.opened(tab)
        if tab == .live { replay() }
        queue { await $0.tabOpened(tab) }
    }
}
