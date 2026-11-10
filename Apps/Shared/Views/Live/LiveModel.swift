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
    }

    /// Thrown by a loader for a source whose login is not on this device.
    enum LoadFailure: Error { case waitingForLogin }

    private(set) var sources: [LiveSource] = []
    private(set) var channels: [Channel] = []
    private(set) var catalogue = Catalogue<PersistentIdentifier>(channels: [], groupOrder: [:], favorites: [])
    /// The group whose channels the list shows.
    private(set) var group: CatalogueGroup = .all
    /// The channel playing in place, nil until the user picks one.
    private(set) var playing: Channel?
    /// The engine's state, as last reported.
    private(set) var playback: PlaybackState = .idle
    /// False until the first `sourcesChanged`, so no empty state flashes at launch.
    private(set) var launched = false
    /// The description of the last failed source in source order
    /// (source-management/load-failure-is-recorded). Never shown on screen.
    private(set) var error: String?

    @ObservationIgnored let engine: any PlaybackEngine
    @ObservationIgnored let programmes: OverlayGuide
    @ObservationIgnored private let dependencies: Dependencies
    @ObservationIgnored private let languages: ChannelLanguages
    @ObservationIgnored private var descriptors: [UUID: SourceDescriptor] = [:]
    @ObservationIgnored private var loads: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var channelsBySource: [UUID: [Channel]] = [:]
    @ObservationIgnored private var failures: [UUID: String] = [:]
    @ObservationIgnored private var favorites: [FavoriteSnapshot<PersistentIdentifier>] = []
    @ObservationIgnored private var tuning: Task<Void, Never>?

    init(_ dependencies: Dependencies) {
        self.dependencies = dependencies
        engine = dependencies.engine
        programmes = dependencies.programmes
        languages = ChannelLanguages(store: dependencies.languages, watching: dependencies.engine)
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
        if !catalogue.groups.contains(group) { group = .all }
    }

    // MARK: Favorites and groups

    /// The stored favorites changed, on this device or through sync.
    func favoritesChanged(_ snapshots: [FavoriteSnapshot<PersistentIdentifier>]) {
        guard snapshots != favorites else { return }
        favorites = snapshots
        catalogue = catalogue.replacingFavorites(snapshots)
    }

    /// Shows `group`'s channels. The playing channel plays on.
    func show(_ group: CatalogueGroup) {
        self.group = group
    }

    // MARK: Playback

    /// Follows the engine's state until the calling task ends.
    func observeEngine() async {
        for await state in await engine.states() {
            playback = state
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
        tuning?.cancel()
        tuning = Task { [weak self] in
            guard let self else { return }
            do {
                try await engine.load(channel.streamURL, options: languages.options(for: channel))
            } catch {
                return
            }
            guard !Task.isCancelled, playing == channel else { return }
            await engine.play()
        }
    }

    private func stop() {
        playing = nil
        tuning?.cancel()
        Task { await engine.stop() }
    }
}

extension LiveModel.Dependencies {
    /// The engine, loader, Keychain check and guide the app runs on.
    @MainActor static func live(loader: SourceLoader, guide: AppGuideStore?) -> Self {
        .init(
            engine: RoutedEngine.app(),
            load: { try await loader.load($0) },
            hasLogin: { loader.hasLogin($0) },
            guide: guide,
            programmes: .store(guide))
    }
}
