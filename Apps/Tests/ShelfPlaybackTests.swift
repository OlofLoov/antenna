import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// Playing movies and episodes from the sections: where they start, which
/// episode a series starts on, and when the place is saved. A scripted
/// engine, library and in-memory store stand in for the real ones.
@MainActor
@Suite struct ShelfPlaybackTests {
    let container: ModelContainer
    let source = UUID(uuidString: "00000000-0000-0000-0000-00000000AB01") ?? UUID()
    let engine = ScriptedEngine()
    let clock = ManualClock()
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        let schema = Schema(AntennaSchema.models)
        container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    private var store: ActivityStore { ActivityStore(context: container.mainContext) }

    private var movie: ShelfTitle {
        ShelfTitle(id: "xtream#h#vod#7", kind: .movie, sourceID: source, name: "Salt Road", category: "Drama")
    }

    private func series(_ number: Int) -> ShelfTitle {
        ShelfTitle(id: "xtream#h#series#\(number)", kind: .series, sourceID: source, name: "Series \(number)", category: "Drama")
    }

    private func episode(_ series: Int, _ number: Int) -> Episode {
        Episode(
            id: "xtream#h#episode#\(series * 10 + number)", episodeID: series * 10 + number, season: 1, number: number, title: "E\(number)")
    }

    /// Series 1 has three episodes, series 2 none, and series 3's list fails
    /// once, then has one.
    private func library() async -> ShelfLibrary {
        let failures = Counter()
        let titles = (movies: [movie], series: (1...3).map(series))
        let episodes: @MainActor (Int) throws -> [Episode] = { number in
            switch number {
            case 1: return (1...3).map { episode(1, $0) }
            case 2: return []
            default:
                failures.value += 1
                if failures.value == 1 { throw URLError(.timedOut) }
                return [episode(3, 1)]
            }
        }
        let dependencies = ShelfModel.Dependencies(
            load: { _, kind in ShelfCatalogue(titles: kind == .movie ? titles.movies : titles.series, categories: ["Drama"]) },
            hasLogin: { _ in true },
            details: { _, _ in ShelfDetails() },
            episodes: { _, series in try episodes(XtreamTitleID(parsing: series.id)?.rawID ?? 0) })
        let library = ShelfLibrary(movies: ShelfModel(kind: .movie, dependencies), series: ShelfModel(kind: .series, dependencies))
        library.sourcesChanged([SourceDescriptor(id: source, name: "Cabin", kind: .xtream, url: URL(fileURLWithPath: "/cabin"))])
        library.open()
        await library.movies.settled()
        await library.series.settled()
        return library
    }

    /// Follows the store until `follow` is cancelled; the test cancels it
    /// before the store goes away.
    private func activity(_ follow: inout Task<Void, Never>?) async -> ShelfActivity {
        let activity = ShelfActivity()
        let store = store
        follow = Task { [container] in
            // The container outlives the follow loop.
            await activity.follow(store)
            withExtendedLifetime(container) {}
        }
        await Task.yield()
        return activity
    }

    private func playback(liveStopped: Counter = Counter()) -> ShelfPlayback {
        ShelfPlayback(
            .init(
                engine: engine,
                address: { _, target in
                    switch target {
                    case .movie(let movie): URL(fileURLWithPath: "/\(movie.id).mp4")
                    case .episode(let episode, _): URL(fileURLWithPath: "/\(episode.id).mp4")
                    }
                },
                willPlay: { liveStopped.value += 1 },
                clock: { [clock] in clock.now },
                languages: { ["en", "sv"] }))
    }

    @Test("playback-engine/subtitles-start-by-the-subtitle-setting a movie starts by the device's languages and the setting")
    func movieSubtitles() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        playback.subtitles = .always
        playback.play(movie, library: library, activity: activity)
        #expect(await eventually { engine.loads.count == 1 })
        let options = engine.loads.first?.options
        #expect(options?.preferredAudioLanguages == ["en", "sv"])
        #expect(options?.preferredSubtitleLanguages == ["en", "sv"])
        #expect(options?.subtitleMode == .always)
    }

    // MARK: Resume

    @Test("movies-and-series-browsing/resume-where-you-left-off a movie stopped part-way starts where it stopped, before the first frame")
    func resume() async {
        let library = await library()
        store.saveProgress(titleID: movie.id, source: source, position: 2400, duration: 5400, now: now)
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let live = Counter()
        let playback = playback(liveStopped: live)
        playback.play(movie, library: library, activity: activity)
        #expect(await eventually { engine.loads.count == 1 })
        #expect(engine.loads.first?.options.startPosition == .seconds(2400))
        #expect(engine.loads.first?.url.lastPathComponent == "\(movie.id).mp4")
        #expect(live.value == 1, "live TV stops first")
        #expect(playback.playing == .movie(movie))
    }

    @Test("movies-and-series-browsing/resume-where-you-left-off barely started or finished starts from the beginning")
    func fromTheStart() async {
        let library = await library()
        for (position, expected) in [(30.0, 1), (5300, 2)] {
            store.saveProgress(titleID: movie.id, source: source, position: position, duration: 5400, now: now)
            var follow: Task<Void, Never>?
            defer { follow?.cancel() }
            let activity = await activity(&follow)
            playback().play(movie, library: library, activity: activity)
            #expect(await eventually { engine.loads.count == expected })
            #expect(engine.loads.last?.options.startPosition == nil)
        }
    }

    // MARK: Series

    @Test("movies-and-series-browsing/play-a-series-from-the-next-episode the first unfinished episode starts at its place")
    func nextEpisode() async {
        let library = await library()
        store.saveProgress(titleID: episode(1, 1).id, seriesID: series(1).id, source: source, position: 99, duration: 100, now: now)
        store.saveProgress(titleID: episode(1, 2).id, seriesID: series(1).id, source: source, position: 40, duration: 100, now: now)
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        playback.play(series(1), library: library, activity: activity)
        #expect(await eventually { engine.loads.count == 1 })
        #expect(engine.loads.first?.url.lastPathComponent == "\(episode(1, 2).id).mp4")
        #expect(engine.loads.first?.options.startPosition == .seconds(40))
        #expect(playback.playing == .episode(episode(1, 2), series: series(1)))
        #expect(playback.working == nil)
    }

    @Test("movies-and-series-browsing/play-a-series-from-the-next-episode no episodes, or a list that fails with Retry")
    func noEpisodes() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        playback.play(series(2), library: library, activity: activity)
        #expect(await eventually { playback.problem == .noEpisodes(series(2)) })
        #expect(playback.problem?.message == "No episodes available")

        playback.problem = nil
        playback.play(series(3), library: library, activity: activity)
        #expect(await eventually { playback.problem == .episodesFailed(series(3)) })
        #expect(playback.problem?.message == "Could not load episodes")
        #expect(playback.problem?.retries == true)
        playback.retry(series(3), library: library, activity: activity)
        #expect(await eventually { engine.loads.count == 1 })
        #expect(playback.problem == nil)
    }

    // MARK: Saving

    @Test("movies-and-series-browsing/your-place-is-saved-as-you-watch every 30 seconds, on pause, background, end and close")
    func saving() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        playback.play(movie, library: library, activity: activity)
        #expect(await eventually { engine.state == .playing })
        let saved = { store.progress(of: movie.id, source: source)?.position }

        engine.send(position: 100)
        clock.advance(.seconds(10))
        engine.send(position: 110)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(saved() == nil, "nothing before 30 seconds")
        clock.advance(.seconds(25))
        engine.send(position: 135)
        #expect(await eventually { saved() == 135 })

        engine.send(position: 140)
        await engine.pause()
        #expect(await eventually { saved() == 140 }, "pausing saves")

        await engine.play()
        engine.send(position: 150)
        try? await Task.sleep(for: .milliseconds(50))
        playback.background()
        #expect(saved() == 150, "going to the background saves")

        engine.send(position: 160)
        engine.finish()
        #expect(await eventually { saved() == 5400 }, "the end saves the full length")
        #expect(store.progress(of: movie.id, source: source)?.state == .watched)

        await engine.play()
        engine.send(position: 200)
        try? await Task.sleep(for: .milliseconds(50))
        await playback.close()
        #expect(saved() == 200, "closing saves")
        #expect(playback.playing == nil)
        #expect(engine.state == .idle)
    }

    @Test("movies-and-series-browsing/your-place-is-saved-as-you-watch an episode saves under its series, for Continue watching")
    func episodeSaving() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        playback.play(series(1), library: library, activity: activity)
        #expect(await eventually { engine.state == .playing })
        engine.send(position: 600)
        try? await Task.sleep(for: .milliseconds(50))
        await playback.close()
        let saved = store.progress(of: episode(1, 1).id, source: source)
        #expect(saved?.seriesID == series(1).id)
        #expect(activity.continueWatching(library).map(\.id) == [series(1).id])
    }
}

/// A clock the test moves by hand.
@MainActor
final class ManualClock {
    var now = ContinuousClock.now

    func advance(_ by: Duration) {
        now = now.advanced(by: by)
    }
}

@MainActor
final class Counter {
    var value = 0
}

/// An engine whose states and positions the test sends.
@MainActor
final class ScriptedEngine: PlaybackEngine {
    struct Load {
        var url: URL
        var options: PlaybackOptions
    }

    private(set) var loads: [Load] = []
    private(set) var state: PlaybackState = .idle {
        didSet { stateCast.send(state) }
    }
    private let stateCast = Broadcast(PlaybackState.idle)
    private let positionCast = Broadcast(PlaybackPosition.zero)

    var capabilities: EngineCapabilities { EngineCapabilities(supportsPictureInPicture: false) }

    func load(_ url: URL, options: PlaybackOptions) async throws {
        loads.append(Load(url: url, options: options))
        state = .loading
    }

    func play() async { state = .playing }
    func pause() async { state = .paused }
    func stop() async { state = .idle }
    func finish() { state = .ended }

    func send(position seconds: Int) {
        positionCast.send(PlaybackPosition(time: .seconds(seconds), duration: .seconds(5400), isLive: false))
    }

    func seek(to time: Duration) async throws {}
    func selectAudio(_ id: MediaTrack.ID) async {}
    func selectSubtitle(_ id: MediaTrack.ID?) async {}
    func states() async -> AsyncStream<PlaybackState> { stateCast.stream() }
    func presentation() async -> AsyncStream<PresentationInfo?> { Broadcast(PresentationInfo?.none).stream() }
    func tracks() async -> AsyncStream<TrackList> { Broadcast(TrackList.empty).stream() }
    func position() async -> AsyncStream<PlaybackPosition> { positionCast.stream() }
    func subtitleCues() async -> AsyncStream<[SubtitleCue]> { Broadcast([SubtitleCue]()).stream() }
}
