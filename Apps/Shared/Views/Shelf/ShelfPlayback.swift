import AntennaCore
import Foundation
import Observation
import os

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
        /// The device's languages in the user's order.
        var languages: @MainActor () -> [String] = { Locale.preferredLanguages }
        /// How long the movie controls stay after an input while playing.
        var controlsHold = TitleTransport.hold
    }

    /// What plays: a movie, one episode of a series, or a title's trailer.
    enum Target: Equatable, Sendable {
        case movie(ShelfTitle)
        case episode(Episode, series: ShelfTitle)
        /// A trailer that plays in the app, which saves no place
        /// (title-detail-and-episode-picker/trailer).
        case trailer(URL, of: ShelfTitle)

        /// The movie, the series the episode belongs to, or the trailer's title.
        var title: ShelfTitle {
            switch self {
            case .movie(let movie): movie
            case .episode(_, let series): series
            case .trailer(_, let title): title
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
    /// The audio and subtitle lists of the title on screen, nil while nothing plays.
    private(set) var tracks: TitleTracks?
    /// The time, skips and scrubbing of the title on screen, nil while nothing plays.
    private(set) var transport: TitleTransport?
    /// Why the title on screen cannot play, shown in place of the picture
    /// (player-controls-and-playback-errors/a-movie-or-episode-that-cannot-play-says-why).
    private(set) var failure: FailureMessage?
    /// The series whose episode list is loading; its poster shows it is working.
    private(set) var working: String?
    /// The series that could not start, shown as an alert.
    var problem: Problem?
    /// The Subtitles preference, which the screen keeps current
    /// (playback-engine/subtitles-start-by-the-subtitle-setting).
    @ObservationIgnored var subtitles = SubtitleMode.auto

    @ObservationIgnored let engine: any PlaybackEngine
    @ObservationIgnored private let dependencies: Dependencies
    @ObservationIgnored private var saving = PositionSaving()
    @ObservationIgnored private var watching: Task<Void, Never>?
    @ObservationIgnored private var listeners: [Task<Void, Never>] = [] {
        willSet { listeners.forEach { $0.cancel() } }
    }
    @ObservationIgnored private var activity: ShelfActivity?
    /// The address and options the title on screen loaded with.
    @ObservationIgnored private var request: (url: URL, options: PlaybackOptions)?
    /// The source the title on screen plays from, for Try again and the error's wording.
    @ObservationIgnored private var source: SourceDescriptor?

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

    /// Plays `title`'s trailer from its start; closing it saves nothing.
    func playTrailer(_ url: URL, of title: ShelfTitle) {
        start(.trailer(url, of: title), from: 0, source: nil)
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
            TitleModel.logger.error("episodes failed: \(TitleModel.reason(error), privacy: .public)")
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
        let address: URL?
        if case .trailer(let url, _) = target {
            address = url
        } else {
            do {
                address = try source.map { try dependencies.address($0, target) }
            } catch {
                TitleModel.logger.error("no address to play: \(TitleModel.reason(error), privacy: .public)")
                address = nil
            }
        }
        guard let url = address else { return }
        watching?.cancel()
        listeners = []
        saving = PositionSaving()
        failure = nil
        self.source = source
        playing = target
        let tracks = TitleTracks(engine: engine, address: url)
        self.tracks = tracks
        let engine = engine
        let transport = TitleTransport(
            .init(engine: engine, seek: { [weak self] in await self?.seek(to: $0) ?? false }, hold: dependencies.controlsHold))
        self.transport = transport
        let willPlay = dependencies.willPlay
        let languages = dependencies.languages()
        let start: Duration? = position > 0 ? .milliseconds(Int64(position * 1000)) : nil
        let options = PlaybackOptions(
            startPosition: start, isLive: false, preferredAudioLanguages: languages, preferredSubtitleLanguages: languages,
            subtitleMode: subtitles)
        request = (url, options)
        watching = Task { [weak self] in
            await willPlay()
            do {
                try await engine.load(url, options: options)
            } catch let reason as PlaybackFailure {
                self?.failed(reason, target)
                return
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await engine.play()
            await self?.follow(target, tracks: tracks, transport: transport)
        }
    }

    // MARK: Saving

    /// Feeds the engine's states and positions to `PositionSaving` and saves
    /// what it returns, and keeps `tracks` current, until the title closes.
    private func follow(_ target: Target, tracks: TitleTracks, transport: TitleTransport) async {
        let states = await engine.states()
        let positions = await engine.position()
        listeners = [
            Task { await tracks.follow() },
            Task { await transport.follow() },
            Task { [weak self] in
                for await state in states {
                    guard let self, playing == target else { return }
                    if let saved = saving.state(state, at: dependencies.clock()) { save(saved, target) }
                    if case .failed(let reason) = state { failed(reason, target) }
                    // A trailer that ends goes back to its title page.
                    if case .trailer = target, case .ended = state { return await close() }
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
        tracks = nil
        transport = nil
        failure = nil
        request = nil
        source = nil
        watching?.cancel()
        watching = nil
        listeners = []
        await engine.stop()
    }

    /// Says why `target` cannot play, if it is still the title on screen.
    private func failed(_ reason: PlaybackFailure, _ target: Target) {
        guard playing == target else { return }
        failure = FailureMessage(reason, source: source?.name ?? PlayerModel.unnamedSource, device: .current)
    }

    /// Try again on the error: loads the title once more from where it was.
    func retry() {
        guard let playing else { return }
        let at = transport.map { Self.seconds($0.position.time) } ?? 0
        let from = at > 0 ? at : request?.options.startPosition.map(Self.seconds) ?? 0
        start(playing, from: from, source: source)
    }

    /// Pauses a playing title, plays a paused one; pausing saves.
    func playPause() async {
        if case .paused = await engine.state {
            await engine.play()
        } else {
            await engine.pause()
        }
    }

    /// Moves the title on screen to `time` and saves it as the place to
    /// resume. A title that already ended opens again from `time` and
    /// plays. Returns false when its server cannot skip
    /// (player-controls-and-playback-errors/move-around-in-a-movie-or-episode).
    func seek(to time: Duration) async -> Bool {
        guard let playing, let request else { return false }
        if case .ended = await engine.state {
            var options = request.options
            options.startPosition = time
            do {
                try await engine.load(request.url, options: options)
            } catch {
                return true
            }
            guard self.playing == playing else { return true }
            await engine.play()
        } else {
            do {
                try await engine.seek(to: time)
            } catch {
                return false
            }
        }
        guard self.playing == playing else { return true }
        if let saved = saving.moved(to: time, at: dependencies.clock()) { save(saved, playing) }
        return true
    }

    private func save(_ position: PlaybackPosition, _ target: Target) {
        let seconds = Self.seconds(position.time)
        let length = position.duration.map(Self.seconds)
        switch target {
        case .movie(let movie):
            activity?.saveProgress(titleID: movie.id, seriesID: nil, source: movie.sourceID, position: seconds, duration: length)
        case .episode(let episode, let series):
            activity?.saveProgress(titleID: episode.id, seriesID: series.id, source: series.sourceID, position: seconds, duration: length)
        case .trailer:
            break
        }
    }

    static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}
