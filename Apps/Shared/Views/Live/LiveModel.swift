import AntennaCore
import Foundation
import Observation
import SwiftData

/// One source as Live lists it while channels load.
struct LiveSource: Identifiable, Equatable, Sendable {
    enum State: Equatable, Sendable {
        case loading
        case loaded(channels: Int)
        case offline
        case failed
        case waitingForLogin

        /// True once the source finished and added nothing: loaded empty,
        /// offline, failed or waiting for its login.
        var addedNothing: Bool { self != .loading && !isLoadedWithChannels }

        var isLoadedWithChannels: Bool {
            if case .loaded(let count) = self { return count > 0 }
            return false
        }
    }

    var id: UUID
    var name: String
    var state: State
}

/// State and rules of the Live screen on iPhone, iPad and Mac
/// (live-tv-on-iphone-ipad-mac capability): the sources as they load, the
/// catalogue, the group on screen and the channel playing in place. Both
/// the narrow and the wide layout read one model, so switching between
/// them never touches the player.
@MainActor @Observable
final class LiveModel {
    struct Dependencies {
        var engine: any PlaybackEngine
        var load: @MainActor (SourceDescriptor) async throws -> Playlist
        var hasLogin: @MainActor (SourceDescriptor) -> Bool
        /// Told about each loaded playlist so its guide downloads.
        var guide: AppGuideStore?
        /// What the rows, the now-playing line and the details read.
        var programmes: OverlayGuide
        var languages = ChannelLanguageStore()
        /// How often to look for a login that has not arrived yet.
        var loginCheck = Duration.seconds(5)
        /// How long a tap keeps the controls up while playing. UI tests
        /// raise it, since a slow runner can take longer than that to read them.
        var touchHold = ControlsTimer.touchHold
        /// The connection the player watches to recover from an offline error.
        var network: NetworkWatch = .system
        /// How long the spinner shows before it names the source as slow.
        var slowDelay = Duration.seconds(10)
        /// The current profile's recents, session and last channel. Tests and
        /// previews keep theirs apart from the app's.
        var recents = RecentsStore.scratch
        /// How the ten-second count waits.
        var sleep: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
        /// The lock screen and Control Center; nil uses the system's.
        var nowPlaying: NowPlayingSink?
        /// How often the lock screen catches up with the programme.
        var nowPlayingInterval = Duration.seconds(5)
        /// The Picture in Picture window; nil watches the engine's.
        var pictureInPicture: PictureInPictureHooks?
        /// The tiles' engines and limit when multi-view starts on a Mac.
        var multiView = MultiViewModel.Dependencies()
        /// Builds Start over's catch-up addresses.
        var catchup = CatchupAddresses()
    }

    /// Thrown by a loader for a source whose login is not on this device.
    enum LoadFailure: Error { case waitingForLogin }

    private(set) var sources: [LiveSource] = []
    private(set) var channels: [Channel] = []
    var catalogue = Catalogue<PersistentIdentifier>(channels: [], groupOrder: [:], favorites: [])
    var groupRules = GroupRules()
    /// The group whose channels the list shows.
    var group: CatalogueGroup = .all
    /// What the user typed into the filter field on iPad and Mac.
    var filter = ""
    /// The filter field has the keyboard, so single-key shortcuts stay off.
    var typing = false
    /// The channel playing in place, nil until the user picks one.
    private(set) var playing: Channel?
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
    /// The description of the last failed source in source order
    /// (source-management/load-failure-is-recorded). Never shown on screen.
    private(set) var error: String?
    /// Multi-view in the Mac window, nil while one channel plays.
    var multiView: MultiViewModel?

    @ObservationIgnored let engine: any PlaybackEngine
    @ObservationIgnored let programmes: OverlayGuide
    /// The spinner, the reconnect count and the error for the playing channel.
    @ObservationIgnored let player: PlayerModel
    @ObservationIgnored let dependencies: Dependencies
    @ObservationIgnored private let languages: ChannelLanguages
    /// Stores the last channel and counts a channel as watched.
    @ObservationIgnored let session: SessionTracker
    @ObservationIgnored private(set) var descriptors: [UUID: SourceDescriptor] = [:]
    @ObservationIgnored private var loads: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var channelsBySource: [UUID: [Channel]] = [:]
    @ObservationIgnored private var failures: [UUID: String] = [:]
    @ObservationIgnored private var favorites: [FavoriteSnapshot<PersistentIdentifier>] = []
    /// The recents the catalogue lists. While Recents is on screen a newer
    /// list waits in `latestRecents` (session-restore-and-recently-watched/the-list-holds-still-while-you-use-it).
    @ObservationIgnored var shownRecents: [LastChannelKey] = []
    @ObservationIgnored var latestRecents: [LastChannelKey] = []
    /// The tab, group and channel to bring back from the last session.
    @ObservationIgnored var restore = LiveRestore()
    @ObservationIgnored private var tuning: Task<Void, Never>?
    @ObservationIgnored private var loginWatch: Task<Void, Never>?
    @ObservationIgnored var names = ChannelNameIndex(Catalogue<PersistentIdentifier>(channels: [], groupOrder: [:], favorites: []))
    @ObservationIgnored private var hiding: Task<Void, Never>?
    @ObservationIgnored private var lastInput = ControlsTimer.Input.touch
    @ObservationIgnored private var suspended = false

    init(_ dependencies: Dependencies) {
        self.dependencies = dependencies
        engine = dependencies.engine
        programmes = dependencies.programmes
        languages = ChannelLanguages(store: dependencies.languages, watching: dependencies.engine)
        session = SessionTracker(store: dependencies.recents, sleep: dependencies.sleep)
        latestRecents = dependencies.recents.recents.entries
        restore = LiveRestore(store: dependencies.recents)
        shownRecents = latestRecents
        player = PlayerModel(
            .init(
                engine: dependencies.engine, network: dependencies.network, slowDelay: dependencies.slowDelay,
                pictureInPicture: dependencies.pictureInPicture))
        session.recorded = { [weak self] list in self?.recentsChanged(list.entries) }
        player.reload = { [weak self] channel in self?.load(channel) }
        player.timeshift.restartChannel = { [weak self] in self?.restartWithNewBuffer() }
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
            descriptors[id] = nil
            channelsBySource[id] = nil
            failures[id] = nil
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

    /// Waits until no source is loading. For tests.
    func settled() async {
        while let next = loads.values.first {
            await next.value
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
            guard let self else { return }
            let result: Result<Playlist, any Error>
            if !dependencies.hasLogin(source) {
                result = .failure(LoadFailure.waitingForLogin)
            } else {
                do {
                    result = .success(try await dependencies.load(source))
                } catch {
                    result = .failure(error)
                }
            }
            guard !Task.isCancelled else { return }
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
    }

    /// Rebuilds the channels and the catalogue from the sources that loaded.
    private func rebuild() {
        let all = sources.flatMap { channelsBySource[$0.id] ?? [] }
        error = sources.last { failures[$0.id] != nil }.flatMap { failures[$0.id] }
        guard all != channels else { return }
        if multiView != nil { Task { await multiViewChannelsChanged() } }
        channels = all
        catalogue = Catalogue(channels: all, groupOrder: [:], favorites: favorites, recents: shownRecents, rules: groupRules)
        names = ChannelNameIndex(catalogue)
        restoreGroup()
    }

    // MARK: Favorites and groups

    /// The stored favorites changed, on this device or through sync.
    func favoritesChanged(_ snapshots: [FavoriteSnapshot<PersistentIdentifier>]) {
        guard snapshots != favorites else { return }
        favorites = snapshots
        catalogue = catalogue.replacingFavorites(snapshots)
    }

    /// The open group's rows in catalogue order, narrowed by the filter
    /// (live-tv-on-iphone-ipad-mac/type-to-narrow-the-list).
    var rows: [RowKey] {
        names.filter(catalogue.rows(in: group), by: ChannelFilter(filter))
    }

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
        if channel != playing { later = nil }
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
                if let failure = error as? PlaybackFailure, playing == channel { player.loadFailed(failure) }
                return
            }
            guard !Task.isCancelled, playing == channel else { return }
            canPictureInPicture = await engine.capabilities.supportsPictureInPicture
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
    /// Pauses a playing channel, plays a paused one, as the user's own pause.
    func playPause() {
        // Space and the lock screen pause no tile (multi-view/sound-follows-the-highlighted-tile).
        guard playing != nil, multiView == nil else { return }
        player.timeshift.toggle(isPaused: isPaused)
    }

    /// Fills the window, or the iPhone screen, with the picture, or goes
    /// back to the list (live-tv-on-iphone-ipad-mac/full-screen). The channel plays on.
    func setFullScreen(_ on: Bool) {
        fullScreen = on && playing != nil
    }

    /// The options a channel opens with, its remembered languages among them.
    var languageOptions: @MainActor (Channel) -> PlaybackOptions {
        { [languages] in languages.options(for: $0) }
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
        if let key = LastChannelKey(channel) { session.store.write(key) }
        let state = await engine.state
        playback = state
        player.stateChanged(state)
        session.stateChanged(state)
        player.restoreVolume()
    }
}

extension LiveModel {
    private func finish(_ source: SourceDescriptor, with result: Result<Playlist, any Error>) async {
        switch result {
        case .success(let playlist):
            let tagged = Channel.tagged(playlist.channels, sourceID: source.id)
            channelsBySource[source.id] = tagged
            setState(.loaded(channels: tagged.count), for: source.id)
            rebuild()
            replay()
            if let guide = dependencies.guide {
                await guide.register(epgURLs: playlist.epgURLs, for: source.id)
                await guide.update(channels: tagged)
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
