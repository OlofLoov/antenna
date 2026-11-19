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
        /// True when this device plays the next episode on its own
        /// (up-next/turn-autoplay-off), read as each episode starts.
        var autoplays: @MainActor () -> Bool = {
            AutoplaySetting.decode(UserDefaults.standard.data(forKey: AutoplaySetting.key)).plays
        }
        /// Waits between the Up next card's counts.
        var sleep: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    }

    /// The Next episode button or the Up next card on screen
    /// (up-next/next-episode-near-the-end, up-next/up-next-counts-down).
    struct UpNextShown: Equatable {
        var episode: Episode
        var offer: UpNextTimer.Offer
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
        var message: LocalizedStringResource {
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
    /// The episode after the one on screen, once the series' list is known
    /// and autoplay is on; nil otherwise (up-next/which-episode-is-next).
    private(set) var nextEpisode: Episode?
    /// What the end of the episode on screen shows.
    private(set) var timer = UpNextTimer()
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
    @ObservationIgnored private var library: ShelfLibrary?
    /// Episodes started by the countdown since the viewer's last input.
    @ObservationIgnored private(set) var run = UpNextRun()
    @ObservationIgnored private var finding: Task<Void, Never>?
    @ObservationIgnored private var counting: Task<Void, Never>?
    /// The engine's last state and length, for the countdown and the save before the next episode.
    @ObservationIgnored private var engineState = PlaybackState.idle
    @ObservationIgnored private var length: Duration?

    init(_ dependencies: Dependencies) {
        self.dependencies = dependencies
        engine = dependencies.engine
    }

    // MARK: Starting

    /// Plays a movie from where the user stopped, or a series from the
    /// episode the title page's Play would start, once its episode list loads.
    func play(_ title: ShelfTitle, library: ShelfLibrary, activity: ShelfActivity) {
        self.activity = activity
        self.library = library
        run = UpNextRun()
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
        self.library = library
        run = UpNextRun()
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
            .init(
                engine: engine, seek: { [weak self] in await self?.seek(to: $0) ?? false }, hold: dependencies.controlsHold,
                input: { [weak self] in self?.noteInput() }))
        self.transport = transport
        resetUpNext()
        engineState = .loading
        length = nil
        findNext(after: target)
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
                    engineState = state
                    if let saved = saving.state(state, at: dependencies.clock()) { save(saved, target) }
                    if case .failed(let reason) = state { failed(reason, target) }
                    // A trailer that ends goes back to its title page.
                    if case .trailer = target, case .ended = state { return await close() }
                    if case .episode = target {
                        if case .playing = state { timer.playing() }
                        if case .ended = state { await episodeEnded(target) }
                    }
                }
            },
            Task { [weak self] in
                for await position in positions {
                    guard let self, playing == target else { return }
                    if let saved = saving.position(position, at: dependencies.clock()) { save(saved, target) }
                    if position.duration != nil { length = position.duration }
                    if case .episode = target, nextEpisode != nil {
                        timer.position(position.time, length: position.duration, asks: run.asks)
                        startCounting(target)
                    }
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
        resetUpNext()
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

extension ShelfPlayback {
    // MARK: Up next

    /// The button or card on screen, nil when neither shows.
    var upNext: UpNextShown? {
        guard let nextEpisode, timer.offer != .none else { return nil }
        return UpNextShown(episode: nextEpisode, offer: timer.offer)
    }

    /// Play now, Keep watching or the Next episode button: the viewer asked
    /// for the next episode.
    func playNext() {
        noteInput()
        advance()
    }

    /// Cancel, or Back on the card on Apple TV: the episode plays to its end
    /// (up-next/cancel-keeps-watching).
    func cancelUpNext() {
        noteInput()
        counting?.cancel()
        counting = nil
        if timer.cancel() == .close { Task { await close() } }
    }

    /// A press, tap, click or key on the player: the run of episodes
    /// without input starts again (up-next/still-watching).
    func noteInput() {
        run.input()
        timer.input()
        if let playing { startCounting(playing) }
    }

    private func resetUpNext() {
        finding?.cancel()
        finding = nil
        counting?.cancel()
        counting = nil
        nextEpisode = nil
        timer = UpNextTimer()
    }

    /// Looks up the episode after `target` in the series' list, from memory
    /// or asked once (up-next/which-episode-is-next).
    private func findNext(after target: Target) {
        guard case .episode(let episode, let series) = target, dependencies.autoplays(), let library else { return }
        finding = Task { [weak self] in
            let list: [Episode]
            do {
                list = try await library.series.loadEpisodes(series)
            } catch {
                TitleModel.logger.error("no next episode: \(TitleModel.reason(error), privacy: .public)")
                return
            }
            guard let self, !Task.isCancelled, playing == target else { return }
            nextEpisode = UpNext.next(after: episode, in: list)
        }
    }

    /// The episode ended: the next one plays, the card shows, or the page
    /// shows again when there is nothing to play next.
    private func episodeEnded(_ target: Target) async {
        guard nextEpisode != nil else { return await close() }
        switch timer.ended(asks: run.asks) {
        case .playNext: advance(auto: true)
        case .close: await close()
        case .stay: startCounting(target)
        }
    }

    /// Counts the card down once a second while the episode plays or has
    /// ended, and plays the next episode at zero.
    private func startCounting(_ target: Target) {
        guard counting == nil, case .countdown = timer.offer else { return }
        let sleep = dependencies.sleep
        counting = Task { [weak self] in
            while true {
                do { try await sleep(.seconds(1)) } catch { return }
                guard let self, !Task.isCancelled, playing == target else { return }
                guard case .countdown = timer.offer else {
                    counting = nil
                    return
                }
                switch engineState {
                case .playing, .ended: break
                default: continue
                }
                if timer.tick() == .playNext {
                    counting = nil
                    return advance(auto: true)
                }
            }
        }
    }

    /// Saves the episode on screen as watched and plays the next one in the
    /// same player, from where the viewer stopped in it
    /// (up-next/progress-follows-the-next-episode).
    private func advance(auto: Bool = false) {
        guard case .episode(let current, let series) = playing, let next = nextEpisode else { return }
        if let full = length ?? current.duration.map({ .milliseconds(Int64($0 * 1000)) }) {
            save(PlaybackPosition(time: full, duration: full, isLive: false), .episode(current, series: series))
        } else if let saved = saving.leaving(at: dependencies.clock()) {
            save(saved, .episode(current, series: series))
        }
        if auto { run.autoplayed() }
        let progress = activity.map { ContinueWatching.episodeProgress($0.progress, seriesID: series.id, sourceID: series.sourceID) }
        let from = progress?[next.id]?.resumePosition ?? 0
        start(.episode(next, series: series), from: from, source: source)
    }
}
