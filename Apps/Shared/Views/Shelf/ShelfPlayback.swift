import AntennaCore
import Foundation
import Observation

/// Plays movies and episodes from the Movies and Series sections on their
/// own engine (movies-and-series-browsing/resume-where-you-left-off,
/// movies-and-series-browsing/play-a-series-from-the-next-episode,
/// movies-and-series-browsing/your-place-is-saved-as-you-watch). Live TV
/// stops while a title plays and starts again the next time Live opens.
@MainActor @Observable
final class ShelfPlayback {
    struct Dependencies {
        var engine: any PlaybackEngine
        /// Where a movie or episode plays from, built from the source's login.
        var address: @MainActor (SourceDescriptor, Target) throws -> URL
        /// Stops live TV before a title plays.
        var willPlay: @MainActor () async -> Void
        var clock: @MainActor () -> ContinuousClock.Instant = { .now }
    }

    /// What plays: a movie, or one episode of a series.
    enum Target: Equatable, Sendable {
        case movie(ShelfTitle)
        case episode(Episode, series: ShelfTitle)

        /// The movie, or the series the episode belongs to.
        var title: ShelfTitle {
            switch self {
            case .movie(let movie): movie
            case .episode(_, let series): series
            }
        }
    }

    /// Why a series could not start.
    enum Problem: Equatable, Identifiable {
        case noEpisodes(ShelfTitle)
        case episodesFailed(ShelfTitle)

        var id: String {
            switch self {
            case .noEpisodes(let series): "none-\(series.id)"
            case .episodesFailed(let series): "failed-\(series.id)"
            }
        }

        var series: ShelfTitle {
            switch self {
            case .noEpisodes(let series), .episodesFailed(let series): series
            }
        }

        /// True when Retry can help.
        var retries: Bool {
            if case .episodesFailed = self { return true }
            return false
        }

        /// "No episodes available", or "Could not load episodes" with Retry.
        var message: String {
            switch self {
            case .noEpisodes: "No episodes available"
            case .episodesFailed: "Could not load episodes"
            }
        }
    }

    /// The title on screen, nil while nothing plays.
    private(set) var playing: Target?
    /// The series whose episode list is loading; its poster shows it is working.
    private(set) var working: String?
    /// The series that could not start, shown as an alert.
    var problem: Problem?

    @ObservationIgnored let engine: any PlaybackEngine
    @ObservationIgnored private let dependencies: Dependencies
    @ObservationIgnored private var saving = PositionSaving()
    @ObservationIgnored private var watching: Task<Void, Never>?
    @ObservationIgnored private var listeners: [Task<Void, Never>] = [] {
        willSet { listeners.forEach { $0.cancel() } }
    }
    @ObservationIgnored private var activity: ShelfActivity?

    init(_ dependencies: Dependencies) {
        self.dependencies = dependencies
        engine = dependencies.engine
    }

    // MARK: Starting

    /// Plays a movie from where the user stopped, or a series from the
    /// episode the title page's Play would start, once its episode list loads.
    func play(_ title: ShelfTitle, library: ShelfLibrary, activity: ShelfActivity) {
        self.activity = activity
        switch title.kind {
        case .movie:
            let from = activity.progress(of: title)?.resumePosition ?? 0
            start(.movie(title), from: from, source: library.movies.source(of: title))
        case .series:
            Task { await startSeries(title, library: library, activity: activity) }
        }
    }

    /// Plays one episode of a series from `position` seconds, as the title
    /// page asks (title-detail-and-episode-picker/play-an-episode-and-come-back).
    func play(_ episode: Episode, of series: ShelfTitle, from position: Double, library: ShelfLibrary, activity: ShelfActivity) {
        self.activity = activity
        start(.episode(episode, series: series), from: position, source: library.series.source(of: series))
    }

    /// Asks again for the episode list of `series` that failed.
    func retry(_ series: ShelfTitle, library: ShelfLibrary, activity: ShelfActivity) {
        problem = nil
        Task { await startSeries(series, library: library, activity: activity) }
    }

    private func startSeries(_ series: ShelfTitle, library: ShelfLibrary, activity: ShelfActivity) async {
        guard working == nil else { return }
        working = series.id
        defer { working = nil }
        let episodes: [Episode]
        do {
            episodes = try await library.series.loadEpisodes(series)
        } catch {
            problem = .episodesFailed(series)
            return
        }
        let progress = ContinueWatching.episodeProgress(activity.progress, seriesID: series.id, sourceID: series.sourceID)
        // The page's rule, so Continue watching and Play agree
        // (title-detail-and-episode-picker/open-a-series-page).
        guard let pick = SeriesPlayTarget.resolve(episodes: episodes, progress: progress) else {
            problem = .noEpisodes(series)
            return
        }
        start(.episode(pick.episode, series: series), from: pick.position, source: library.series.source(of: series))
    }

    /// Loads the title with the start position set before the first frame.
    private func start(_ target: Target, from position: Double, source: SourceDescriptor?) {
        guard let source, let url = try? dependencies.address(source, target) else { return }
        watching?.cancel()
        listeners = []
        saving = PositionSaving()
        playing = target
        let engine = engine
        let willPlay = dependencies.willPlay
        watching = Task { [weak self] in
            await willPlay()
            let start: Duration? = position > 0 ? .milliseconds(Int64(position * 1000)) : nil
            do {
                try await engine.load(url, options: PlaybackOptions(startPosition: start, isLive: false))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await engine.play()
            await self?.follow(target)
        }
    }

    // MARK: Saving

    /// Feeds the engine's states and positions to `PositionSaving` and saves
    /// what it returns, until the title closes.
    private func follow(_ target: Target) async {
        let states = await engine.states()
        let positions = await engine.position()
        listeners = [
            Task { [weak self] in
                for await state in states {
                    guard let self, playing == target else { return }
                    if let saved = saving.state(state, at: dependencies.clock()) { save(saved, target) }
                }
            },
            Task { [weak self] in
                for await position in positions {
                    guard let self, playing == target else { return }
                    if let saved = saving.position(position, at: dependencies.clock()) { save(saved, target) }
                }
            },
        ]
    }

    /// The app went to the background: saves where the title is.
    func background() {
        guard let playing, let saved = saving.leaving(at: dependencies.clock()) else { return }
        save(saved, playing)
    }

    /// The user left the title: saves where it is and stops it. The poster
    /// that started it is still on screen underneath.
    func close() async {
        guard let playing else { return }
        if let saved = saving.leaving(at: dependencies.clock()) { save(saved, playing) }
        self.playing = nil
        watching?.cancel()
        watching = nil
        listeners = []
        await engine.stop()
    }

    /// Pauses a playing title, plays a paused one; pausing saves.
    func playPause() async {
        if case .paused = await engine.state {
            await engine.play()
        } else {
            await engine.pause()
        }
    }

    private func save(_ position: PlaybackPosition, _ target: Target) {
        let seconds = Self.seconds(position.time)
        let length = position.duration.map(Self.seconds)
        switch target {
        case .movie(let movie):
            activity?.saveProgress(titleID: movie.id, seriesID: nil, source: movie.sourceID, position: seconds, duration: length)
        case .episode(let episode, let series):
            activity?.saveProgress(titleID: episode.id, seriesID: series.id, source: series.sourceID, position: seconds, duration: length)
        }
    }

    static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}
