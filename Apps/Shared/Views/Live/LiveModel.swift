import AntennaCore
import Foundation
import Observation
import SwiftData

/// State and rules of the Live screen on iPhone, iPad and Mac
/// (live-tv-on-iphone-ipad-mac capability): the sources as they load, the
/// catalogue, the group on screen and the channel playing in place. Both
/// the narrow and the wide layout read one model, so switching between
/// them never touches the player.
@MainActor @Observable
final class LiveModel {
    /// Thrown by a loader for a source whose login is not on this device.
    enum LoadFailure: Error { case waitingForLogin }

    private(set) var sources: [LiveSource] = []
    private(set) var channels: [Channel] = []
    var catalogue = Catalogue<PersistentIdentifier>(channels: [], groupOrder: [:], favorites: []) { didSet { refreshRows() } }
    var groupRules = GroupRules()
    /// The group whose channels the list shows.
    var group: CatalogueGroup = .all { didSet { refreshRows() } }
    /// What the user typed into the filter field on iPad and Mac.
    var filter = "" { didSet { refreshRows() } }
    /// The filter field has the keyboard, so single-key shortcuts stay off.
    var typing = false
    /// The channel playing in place, nil until the user picks one.
    private(set) var playing: Channel?
    /// The channel that played before the last change of channel, what
    /// Previous channel goes back to.
    private(set) var lastChannel: Channel?
    /// A later programme picked in Search, shown under what is on next
    /// until the channel changes (search/pick-a-programme).
    private(set) var later: Programme?
    /// The engine's state, as last reported.
    private(set) var playback: PlaybackState = .idle
    /// The engine can move the picture into Picture in Picture.
    private(set) var canPictureInPicture = false
    /// The player controls are over the picture.
    private(set) var controlsShown = false
    /// The picture fills the window, or the iPhone screen.
    private(set) var fullScreen = false
    /// False until the first `sourcesChanged`, so no empty state flashes at launch.
    private(set) var launched = false
    /// Sources whose failure banner the user dismissed.
    private(set) var dismissed: Set<UUID> = []
    /// The description of the last failed source in source order. Never
    /// shown on screen; each source's row shows its own status.
    private(set) var error: String?
    /// Multi-view in the Mac window, nil while one channel plays.
    var multiView: MultiViewModel?

    @ObservationIgnored let engine: any PlaybackEngine
    @ObservationIgnored let programmes: OverlayGuide
    /// The spinner, the reconnect count and the error for the playing channel.
    @ObservationIgnored let player: PlayerModel
    @ObservationIgnored let dependencies: Dependencies
    @ObservationIgnored let languages: ChannelLanguages
    /// Stores the last channel and counts a channel as watched.
    @ObservationIgnored let session: SessionTracker
    @ObservationIgnored private(set) var descriptors: [UUID: SourceDescriptor] = [:]
    @ObservationIgnored private(set) var loads: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored var channelsBySource = SourceChannels()
    @ObservationIgnored private var failures: [UUID: String] = [:]
    /// Each loaded source's memory of its channels (new-channels).
    @ObservationIgnored var seen: [UUID: SeenChannels] = [:]
    /// Counts changes to `seen`, so a catalogue build can tell it missed one.
    @ObservationIgnored var seenChanges = 0
    /// Each source's seen-channel record, written after its channels show.
    @ObservationIgnored var records: [UUID: (ticket: Int, task: Task<Void, Never>)] = [:]
    @ObservationIgnored var recordTickets = 0
    @ObservationIgnored private(set) var favorites: [FavoriteSnapshot<PersistentIdentifier>] = []
    /// The recents the catalogue lists. While Recents is on screen a newer
    /// list waits in `latestRecents` (session-restore-and-recently-watched/the-list-holds-still-while-you-use-it).
    @ObservationIgnored var shownRecents: [LastChannelKey] = []
    @ObservationIgnored var latestRecents: [LastChannelKey] = []
    /// The tab, group and channel to bring back from the last session.
    @ObservationIgnored var restore = LiveRestore()
    /// The movie or series watched last, whose page opens at launch.
    @ObservationIgnored let launchTitle: LaunchTitle
    @ObservationIgnored private var tuning: Task<Void, Never>?
    @ObservationIgnored private var loginWatch: Task<Void, Never>?
    @ObservationIgnored var names = ChannelNameIndex(Catalogue<PersistentIdentifier>(channels: [], groupOrder: [:], favorites: [])) {
        didSet { refreshRows(namesChanged: true) }
    }
    /// What `rows` was worked out from.
    @ObservationIgnored var rowsFrom: RowsSource?
    /// The catalogue being built away from the main actor.
    @ObservationIgnored var building: Task<Void, Never>?
    /// Counts the builds started; only the newest one's catalogue shows.
    @ObservationIgnored var builds = 0
    @ObservationIgnored private var hiding: Task<Void, Never>?
    @ObservationIgnored private var lastInput = ControlsTimer.Input.touch
    @ObservationIgnored private(set) var suspended = false
    /// The pause, then stop, behind Movies, Series and Search.
    @ObservationIgnored let hold: LiveHold
    /// Movies, Series or Search is open and the channel is held behind it.
    @ObservationIgnored var behindContent = false
    /// The last tab change, which the next one waits for.
    @ObservationIgnored var tabChange: Task<Void, Never>?

    init(_ dependencies: Dependencies) {
        self.dependencies = dependencies
        engine = dependencies.engine
        programmes = dependencies.programmes
        languages = ChannelLanguages(store: dependencies.languages, watching: dependencies.engine)
        session = SessionTracker(store: dependencies.recents, sleep: dependencies.sleep)
        latestRecents = dependencies.recents.recents.entries
        restore = LiveRestore(store: dependencies.recents)
        launchTitle = LaunchTitle(dependencies.recents.readLastWatched()?.title)
        shownRecents = latestRecents
        player = PlayerModel(
            .init(
                engine: dependencies.engine, network: dependencies.network, slowDelay: dependencies.slowDelay,
                airPlay: dependencies.airPlay, pictureInPicture: dependencies.pictureInPicture))
        hold = LiveHold(engine: dependencies.engine, timeshift: player.timeshift, sleep: dependencies.sleep)
        session.recorded = { [weak self] list in self?.recentsChanged(list.entries) }
        session.saved = { [weak self] channel in self?.saveForLaunch(channel) }
        player.reload = { [weak self] channel in self?.load(channel) }
        player.timeshift.restartChannel = { [weak self] in self?.restartWithNewBuffer() }
        wireHold()
        wireStartOver()
        player.hasLogin = { [weak self] id in
            guard let self, let source = descriptors[id] else { return false }
            return self.dependencies.hasLogin(source)
        }
        restoreGroup()
    }

    // MARK: Sources

    /// Call on appearance and whenever the stored sources change. New
    /// sources load, edited ones load again, removed ones drop out, and
    /// unchanged ones keep their channels. A repeated id counts once, the
    /// first wins. With every source gone, playback stops.
    func sourcesChanged(_ all: [SourceDescriptor]) {
        launched = true
        var seen: Set<UUID> = []
        let list = all.filter { seen.insert($0.id).inserted }
        let ids = Set(list.map(\.id))
        for id in descriptors.keys where !ids.contains(id) {
            loads[id]?.cancel()
            loads[id] = nil
            records.removeValue(forKey: id)?.task.cancel()
            descriptors[id] = nil
            channelsBySource[id] = nil
            failures[id] = nil
            self.seen[id] = nil
        }
        var changed: [SourceDescriptor] = []
        // A rename loads nothing again (sources-and-settings/changes-from-other-devices-show-up-by-themselves).
        for source in list where descriptors[source.id] != source {
            if descriptors[source.id]?.loadsLike(source) != true { changed.append(source) }
            descriptors[source.id] = source
        }
        let previous = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
        sources = list.map { source in
            var row = previous[source.id] ?? LiveSource(id: source.id, name: source.name, state: .loading)
            row.name = source.name
            return row
        }
        // A deleted source's channel stops (sources-and-settings/delete-a-source-and-everything-that-came-with-it).
        let gone = playing?.sourceID.map { !ids.contains($0) } ?? false
        if playing != nil, list.isEmpty || gone { stop() }
        rebuild()
        changed.forEach(startLoad)
        replay()
    }

    /// Loads again every source that added nothing. The playing channel plays on.
    func retry() {
        for row in sources where row.state.addedNothing {
            if let source = descriptors[row.id] { startLoad(source) }
        }
    }

    /// Hides the failure banner until another source fails or adds nothing.
    func dismissBanner() {
        dismissed.formUnion(sources.filter { $0.state.addedNothing && $0.state != .waitingForLogin }.map(\.id))
    }

    /// Loads each source still waiting for its login whose login has
    /// arrived. Call when the scene becomes active and now and then while
    /// a source waits.
    func checkLogins() {
        for row in sources where row.state == .waitingForLogin {
            if let source = descriptors[row.id], dependencies.hasLogin(source) { startLoad(source) }
        }
    }

    /// A source with channels keeps them while it loads again and when that
    /// load fails (sources-and-settings/a-failed-refresh-keeps-your-channels).
    private func startLoad(_ source: SourceDescriptor) {
        loads[source.id]?.cancel()
        failures[source.id] = nil
        dismissed.remove(source.id)
        if channelsBySource[source.id]?.isEmpty ?? true {
            channelsBySource[source.id] = nil
            setState(.loading, for: source.id)
        }
        rebuild()
        loads[source.id] = Task { [weak self] in
            guard let self, let result = await loaded(source), !Task.isCancelled else { return }
            loads[source.id] = nil
            await finish(source, with: result)
        }
    }

    /// Looks for arriving logins every few seconds while a source waits for
    /// one (live-tv-on-iphone-ipad-mac/a-login-that-syncs-later).
    private func watchLogins() {
        guard loginWatch == nil else { return }
        loginWatch = Task { [weak self] in
            while let self, sources.contains(where: { $0.state == .waitingForLogin }) {
                try? await Task.sleep(for: dependencies.loginCheck)
                guard !Task.isCancelled else { break }
                checkLogins()
            }
            self?.loginWatch = nil
        }
    }

    private static func state(for error: any Error) -> LiveSource.State {
        if case LoadFailure.waitingForLogin? = error as? LoadFailure { return .waitingForLogin }
        let offline: Set<URLError.Code> = [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed]
        if let urlError = error as? URLError, offline.contains(urlError.code) { return .offline }
        return .failed
    }

    private func setState(_ state: LiveSource.State, for id: UUID) {
        guard let index = sources.firstIndex(where: { $0.id == id }) else { return }
        sources[index].state = state
        sources[index].waitsForICloud = state == .waitingForLogin && descriptors[id].map(dependencies.waitsForICloud) == true
    }

    /// Rebuilds the channels and the catalogue from the sources that loaded.
    private func rebuild() {
        error = sources.last { failures[$0.id] != nil }.flatMap { failures[$0.id] }
        guard let all = channelsBySource.changed(order: sources.map(\.id)) else { return }
        if multiView != nil { Task { await multiViewChannelsChanged() } }
        channels = all
        startCatalogueBuild(
            CatalogueInputs(channels: all, favorites: favorites, recents: shownRecents, rules: groupRules, seen: seen, now: .now))
    }

    // MARK: Favorites and groups

    /// The stored favorites changed, on this device or through sync.
    func favoritesChanged(_ snapshots: [FavoriteSnapshot<PersistentIdentifier>]) {
        guard snapshots != favorites else { return }
        favorites = snapshots
        catalogue = catalogue.replacingFavorites(snapshots)
    }

    /// The open group's rows in catalogue order, narrowed by the filter
    /// (live-tv-on-iphone-ipad-mac/type-to-narrow-the-list). Set by `refreshRows`.
    var rows: [RowKey] = []

    // MARK: Playback

    /// Follows the engine's state until the calling task ends.
    func observeEngine() async {
        for await state in await engine.states() {
            let wasPaused = isPaused
            playback = state
            player.stateChanged(state)
            session.stateChanged(state)
            // Paused, the controls stay; playing again, they go after a while.
            if controlsShown, wasPaused != isPaused { showControls(after: lastInput) }
        }
    }

    /// Plays `channel` in place (live-tv-on-iphone-ipad-mac/watch-without-leaving-the-list).
    /// The channel already playing carries on; when paused it resumes, and
    /// when it failed or never started it loads again.
    func pick(_ channel: Channel) {
        restore.channel = nil
        restore.started = nil
        // In multi-view the list fills the selected tile (multi-view/change-a-tile-s-channel).
        if let multiView {
            Task { await multiView.change(multiView.session.selected, to: channel) }
            return
        }
        guard channel == playing else { return tune(channel) }
        switch playback {
        case .paused: player.timeshift.userPlay()
        case .failed, .idle: tune(channel)
        case .loading, .playing, .buffering, .reconnecting, .ended: break
        }
    }

    func tune(_ channel: Channel) {
        endHoldForPick()
        if channel != playing {
            later = nil
            if let playing { lastChannel = playing }
        }
        playing = channel
        player.tuned(subject(for: channel))
        load(channel)
    }

    /// Loads `channel` without telling the player it changed, so Try
    /// again keeps its spinner.
    func load(_ channel: Channel) {
        tuning?.cancel()
        tuning = Task { [weak self] in
            guard let self else { return }
            do {
                try await session.load(channel, on: engine, options: languages.options(for: channel).recordingLive())
            } catch {
                if let failure = error as? PlaybackFailure, playing?.isSame(as: channel) == true { player.loadFailed(failure) }
                return
            }
            guard !Task.isCancelled, playing?.isSame(as: channel) == true else { return }
            canPictureInPicture = await engine.capabilities.supportsPictureInPicture
            // A load that lands behind Movies, Series or Search stays paused.
            if behindContent, !player.playsElsewhere { return hold.loadLanded() }
            await engine.play()
        }
    }

    /// Plays `channel` and shows `programme` as Later under what is on next.
    func pick(_ channel: Channel, later programme: Programme) {
        pick(channel)
        later = programme
    }

    /// A movie or episode is about to play: the channel stops and starts
    /// again the next time Live opens
    /// (movies-and-series-browsing/resume-where-you-left-off).
    func suspend() async {
        guard playing != nil else { return }
        suspended = true
        tuning?.cancel()
        session.interrupt()
        hideControls()
        fullScreen = false
        await engine.stop()
    }

    /// Live opened: the channel a movie stopped plays again.
    func resumeIfSuspended() {
        guard suspended, let playing else { return }
        suspended = false
        tune(playing)
    }

    /// Shows the player controls and hides them again when `ControlsTimer`
    /// says (live-tv-on-iphone-ipad-mac/player-controls-when-you-want-them).
    /// The pointer leaving shows nothing that was hidden.
    func showControls(after input: ControlsTimer.Input) {
        guard playing != nil else { return }
        lastInput = input
        hiding?.cancel()
        if input != .pointerLeft { controlsShown = true }
        guard controlsShown, let delay = ControlsTimer.delay(after: input, isPaused: isPaused, touchHold: dependencies.touchHold) else {
            return
        }
        hiding = Task { [weak self] in
            try? await Task.sleep(for: delay)
            // The controls stay while the track list hangs from them.
            guard !Task.isCancelled, self?.player.pickerOpen == false else { return }
            self?.controlsShown = false
        }
    }

    func hideControls() {
        hiding?.cancel()
        controlsShown = false
    }

    func stop() {
        later = nil
        playing = nil
        player.tuned(nil)
        session.tuned(nil)
        fullScreen = false
        hideControls()
        tuning?.cancel()
        Task { await engine.stop() }
    }
}

// The setters these need are private to this file.
extension LiveModel {
    /// Fills the window, or the iPhone screen, with the picture, or goes
    /// back to the list (live-tv-on-iphone-ipad-mac/full-screen). The channel plays on.
    func setFullScreen(_ on: Bool) {
        fullScreen = on && playing != nil
    }

    /// Multi-view ended with `channel`'s player now playing in the window
    /// with no reload, or with every tile stopped when nil
    /// (multi-view/leave-multi-view). It counts as one channel change, and
    /// the channel is the last one.
    func multiViewEnded(keeping channel: Channel?) async {
        multiView = nil
        guard let channel else { return stop() }
        later = nil
        playing = channel
        player.tuned(subject(for: channel))
        session.tuned(channel)
        session.remember(channel)
        let state = await engine.state
        playback = state
        player.stateChanged(state)
        session.stateChanged(state)
        player.restoreVolume()
    }

    /// The fresh list brought `channel`, the one playing, with fresher
    /// details: it takes the playing one's place with no reload
    /// (session-restore-and-recently-watched/the-fresh-list-decides).
    func adopt(_ channel: Channel) {
        guard let playing, playing.isSame(as: channel) else { return }
        self.playing = channel
        player.retitle(subject(for: channel))
        session.adopt(channel)
    }
}

extension LiveModel {
    /// `source`'s channels and what the device has seen of them, or why it
    /// did not load; nil once the load was cancelled.
    private func loaded(_ source: SourceDescriptor) async -> Result<TaggedPlaylist, any Error>? {
        guard dependencies.hasLogin(source) else { return .failure(LoadFailure.waitingForLogin) }
        do {
            let playlist = try await dependencies.load(source)
            guard !Task.isCancelled else { return nil }
            return .success(await dependencies.seen.tagging(playlist, of: source.id, previous: channelsBySource[source.id]))
        } catch {
            return .failure(error)
        }
    }

    private func finish(_ source: SourceDescriptor, with result: Result<TaggedPlaylist, any Error>) async {
        switch result {
        case .success(let loaded):
            let playlist = loaded.playlist
            let tagged = loaded.channels
            if !loaded.unchanged { channelsBySource[source.id] = tagged }
            setState(.loaded(channels: tagged.count), for: source.id)
            rebuild()
            reconcileLaunch(source.id)
            replay()
            record(source.id, tagged)
            if let guide = dependencies.guide {
                await guide.register(epgURLs: playlist.epgURLs, for: source.id)
                if !loaded.unchanged { await guide.update(channels: tagged) }
                await guide.refreshIfStale(now: .now)
            }
        case .failure(let failure):
            let state = Self.state(for: failure)
            if state != .waitingForLogin { failures[source.id] = failure.localizedDescription }
            if let kept = channelsBySource[source.id], !kept.isEmpty, state != .waitingForLogin {
                setState(.loaded(channels: kept.count), for: source.id)
                rebuild()
                return
            }
            channelsBySource[source.id] = nil
            setState(state, for: source.id)
            rebuild()
            if state == .waitingForLogin { watchLogins() }
        }
    }

    /// Loads `ids` again in order; their channels stay meanwhile (sources-and-settings/refresh-by-hand).
    func reload(_ ids: [UUID]) {
        for source in ids.compactMap({ descriptors[$0] }) { startLoad(source) }
    }
}
