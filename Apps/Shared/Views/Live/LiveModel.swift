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
    }

    /// Thrown by a loader for a source whose login is not on this device.
    enum LoadFailure: Error { case waitingForLogin }

    private(set) var sources: [LiveSource] = []
    private(set) var channels: [Channel] = []
    private(set) var catalogue = Catalogue<PersistentIdentifier>(channels: [], groupOrder: [:], favorites: [])
    /// The group whose channels the list shows.
    private(set) var group: CatalogueGroup = .all
    /// What the user typed into the filter field on iPad and Mac.
    var filter = ""
    /// The channel playing in place, nil until the user picks one.
    private(set) var playing: Channel?
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

    @ObservationIgnored let engine: any PlaybackEngine
    @ObservationIgnored let programmes: OverlayGuide
    /// The spinner, the reconnect count and the error for the playing channel.
    @ObservationIgnored let player: PlayerModel
    @ObservationIgnored private let dependencies: Dependencies
    @ObservationIgnored private let languages: ChannelLanguages
    @ObservationIgnored private var descriptors: [UUID: SourceDescriptor] = [:]
    @ObservationIgnored private var loads: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var channelsBySource: [UUID: [Channel]] = [:]
    @ObservationIgnored private var failures: [UUID: String] = [:]
    @ObservationIgnored private var favorites: [FavoriteSnapshot<PersistentIdentifier>] = []
    @ObservationIgnored private var tuning: Task<Void, Never>?
    @ObservationIgnored private var loginWatch: Task<Void, Never>?
    @ObservationIgnored private var names = ChannelNameIndex(Catalogue<PersistentIdentifier>(channels: [], groupOrder: [:], favorites: []))
    @ObservationIgnored private var hiding: Task<Void, Never>?
    @ObservationIgnored private var lastInput = ControlsTimer.Input.touch
    @ObservationIgnored private var suspended = false

    init(_ dependencies: Dependencies) {
        self.dependencies = dependencies
        engine = dependencies.engine
        programmes = dependencies.programmes
        languages = ChannelLanguages(store: dependencies.languages, watching: dependencies.engine)
        player = PlayerModel(
            .init(engine: dependencies.engine, network: dependencies.network, slowDelay: dependencies.slowDelay))
        player.reload = { [weak self] channel in self?.load(channel) }
        player.hasLogin = { [weak self] id in
            guard let self, let source = descriptors[id] else { return false }
            return self.dependencies.hasLogin(source)
        }
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
        for source in list where descriptors[source.id] != source {
            descriptors[source.id] = source
            changed.append(source)
        }
        let previous = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
        sources = list.map { source in
            var row = previous[source.id] ?? LiveSource(id: source.id, name: source.name, state: .loading)
            row.name = source.name
            return row
        }
        if list.isEmpty, playing != nil { stop() }
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

    private func startLoad(_ source: SourceDescriptor) {
        loads[source.id]?.cancel()
        channelsBySource[source.id] = nil
        failures[source.id] = nil
        dismissed.remove(source.id)
        setState(.loading, for: source.id)
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

    private func finish(_ source: SourceDescriptor, with result: Result<Playlist, any Error>) async {
        switch result {
        case .success(let playlist):
            let tagged = Channel.tagged(playlist.channels, sourceID: source.id)
            channelsBySource[source.id] = tagged
            setState(.loaded(channels: tagged.count), for: source.id)
            rebuild()
            if let guide = dependencies.guide {
                await guide.register(epgURLs: playlist.epgURLs, for: source.id)
                await guide.update(channels: tagged)
                await guide.refreshIfStale(now: .now)
            }
        case .failure(let failure):
            let state = Self.state(for: failure)
            if state != .waitingForLogin { failures[source.id] = failure.localizedDescription }
            setState(state, for: source.id)
            rebuild()
            if state == .waitingForLogin { watchLogins() }
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
        channels = all
        catalogue = Catalogue(channels: all, groupOrder: [:], favorites: favorites)
        names = ChannelNameIndex(catalogue)
        if !catalogue.groups.contains(group) { group = .all }
    }

    // MARK: Favorites and groups

    /// The stored favorites changed, on this device or through sync.
    func favoritesChanged(_ snapshots: [FavoriteSnapshot<PersistentIdentifier>]) {
        guard snapshots != favorites else { return }
        favorites = snapshots
        catalogue = catalogue.replacingFavorites(snapshots)
    }

    /// Shows `group`'s channels and clears the filter. The playing channel plays on.
    func show(_ group: CatalogueGroup) {
        self.group = group
        filter = ""
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
            // Paused, the controls stay; playing again, they go after a while.
            if controlsShown, wasPaused != isPaused { showControls(after: lastInput) }
        }
    }

    /// Plays `channel` in place (live-tv-on-iphone-ipad-mac/watch-without-leaving-the-list).
    /// The channel already playing carries on; when paused it resumes, and
    /// when it failed or never started it loads again.
    func pick(_ channel: Channel) {
        guard channel == playing else { return tune(channel) }
        switch playback {
        case .paused: Task { await engine.play() }
        case .failed, .idle: tune(channel)
        case .loading, .playing, .buffering, .reconnecting, .ended: break
        }
    }

    private func tune(_ channel: Channel) {
        playing = channel
        player.tuned(subject(for: channel))
        load(channel)
    }

    /// Loads `channel` without telling the player it changed, so Try
    /// again keeps its spinner.
    private func load(_ channel: Channel) {
        tuning?.cancel()
        tuning = Task { [weak self] in
            guard let self else { return }
            do {
                try await engine.load(channel.streamURL, options: languages.options(for: channel))
            } catch {
                if let failure = error as? PlaybackFailure, playing == channel { player.loadFailed(failure) }
                return
            }
            guard !Task.isCancelled, playing == channel else { return }
            canPictureInPicture = await engine.capabilities.supportsPictureInPicture
            await engine.play()
        }
    }

    /// The names the player's messages use for `channel`.
    func subject(for channel: Channel) -> PlayerSubject {
        PlayerSubject(
            channel: channel, source: sources.first { $0.id == channel.sourceID }?.name ?? PlayerModel.unnamedSource,
            number: RowKey(channel).flatMap(catalogue.number(for:)))
    }

    /// A movie or episode is about to play: the channel stops and starts
    /// again the next time Live opens
    /// (movies-and-series-browsing/resume-where-you-left-off).
    func suspend() async {
        guard playing != nil else { return }
        suspended = true
        tuning?.cancel()
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

    var isPaused: Bool {
        if case .paused = playback { return true }
        return false
    }

    /// Pauses a playing channel, plays a paused one.
    func playPause() {
        guard playing != nil else { return }
        if isPaused {
            Task { await engine.play() }
        } else {
            Task { await engine.pause() }
        }
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
            guard !Task.isCancelled else { return }
            self?.controlsShown = false
        }
    }

    func hideControls() {
        hiding?.cancel()
        controlsShown = false
    }

    /// Fills the window, or the iPhone screen, with the picture, or goes
    /// back to the list (live-tv-on-iphone-ipad-mac/full-screen). The channel plays on.
    func setFullScreen(_ on: Bool) {
        fullScreen = on && playing != nil
    }

    /// What the now-playing line and the details say about `channel` at `date`.
    func nowText(for channel: Channel, at date: Date) -> LiveNowText {
        let panel = programmes.panel(for: channel, at: date)
        return LiveNowText(
            channel: channel.name, number: RowKey(channel).flatMap(catalogue.number(for:)), state: programmes.state(channel),
            current: panel.now, next: panel.next, now: date, time: Self.time)
    }

    /// A programme's start or end in the user's locale.
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func stop() {
        playing = nil
        player.tuned(nil)
        fullScreen = false
        hideControls()
        tuning?.cancel()
        Task { await engine.stop() }
    }
}

extension LiveModel.Dependencies {
    /// The engine, loader, Keychain check and guide the app runs on.
    /// The language picks are `profile`'s on this device.
    @MainActor static func live(loader: SourceLoader, guide: AppGuideStore?, profile: UUID = Profile.mainID) -> Self {
        .init(
            engine: RoutedEngine.app(),
            load: { try await loader.load($0) },
            hasLogin: { loader.hasLogin($0) },
            guide: guide,
            programmes: .store(guide),
            languages: ChannelLanguageStore(profile: profile))
    }
}

/// When the player controls go away
/// (live-tv-on-iphone-ipad-mac/player-controls-when-you-want-them).
enum ControlsTimer {
    /// What last kept the controls up.
    enum Input: Equatable {
        /// A tap, a click or a press on one of the controls.
        case touch
        /// The pointer moved over the picture.
        case pointerInside
        /// The pointer left the picture.
        case pointerLeft
    }

    /// How long a tap keeps the controls up while playing.
    static let touchHold = Duration.seconds(3)

    /// How long after `input` the controls hide, or nil while they stay:
    /// paused, or with the pointer over the picture.
    static func delay(after input: Input, isPaused: Bool, touchHold: Duration = touchHold) -> Duration? {
        guard !isPaused else { return nil }
        switch input {
        case .touch: return touchHold
        case .pointerInside: return nil
        case .pointerLeft: return .seconds(1)
        }
    }
}
