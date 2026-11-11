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
    /// The group to select once the catalogue has it; nil once selected or
    /// the user picked a group.
    var group: CatalogueGroup?
    /// Live has been on screen since launch.
    var liveShown = false

    init(store: RecentsStore? = nil) {
        self.store = store
        guard let store else { return }
        session = store.session
        channel = store.read()
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
    /// user picked one first. A group that disappears falls back to All
    /// channels while the channel plays on
    /// (session-restore-and-recently-watched/reopen-on-the-same-tab-and-group).
    func restoreGroup() {
        if let wanted = restore.group, catalogue.groups.contains(wanted) {
            group = wanted
            restore.group = nil
        } else if !catalogue.groups.contains(group) {
            group = .all
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

    /// Plays the last channel when Live has shown, nothing plays yet and
    /// the channel is loaded. Otherwise it waits for the next source to load.
    func replay() {
        guard restore.liveShown, playing == nil, let key = restore.channel,
            let channel = channels.first(where: key.matches)
        else { return }
        restore.channel = nil
        tune(channel)
    }

    /// The tab to open on: Search, Settings and an unknown tab open Live
    /// (session-restore-and-recently-watched/reopen-on-the-same-tab-and-group).
    var restoredTab: LiveSession.Tab {
        switch restore.tab {
        case .guide: .guide
        case .movies: .movies
        case .series: .series
        case .live, .search, .settings, nil: .live
        }
    }

    /// The user opened `tab`; the next launch opens on it.
    func opened(_ tab: LiveSession.Tab) {
        restore.opened(tab)
    }
}
