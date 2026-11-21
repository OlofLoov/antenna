import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// The end of an episode: the Next episode button, the Up next card and its
/// countdown, Cancel, "Still watching?" and the progress saved on the way.
/// The countdown waits on a ticker the test fires by hand.
@MainActor
@Suite struct ShelfUpNextTests {
    let container: ModelContainer
    let source = UUID(uuidString: "00000000-0000-0000-0000-00000000AB02") ?? UUID()
    let engine = ScriptedEngine()
    let ticker = Ticker()
    let episodeLoads = Counter()

    init() throws {
        let schema = Schema(AntennaSchema.models)
        container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    var store: ActivityStore { ActivityStore(context: container.mainContext) }

    var series: ShelfTitle {
        ShelfTitle(id: "xtream#h#series#1", kind: .series, sourceID: source, name: "Northern Lights", category: "Drama")
    }

    /// Season 1 has episodes 1 to 3, season 2 episodes 1 to 3, and one special.
    func episode(_ season: Int, _ number: Int) -> Episode {
        Episode(
            id: "xtream#h#episode#\(season * 10 + number)", episodeID: season * 10 + number, season: season, number: number,
            title: "E\(number)")
    }

    var episodes: [Episode] {
        [episode(0, 1)] + (1...2).flatMap { season in (1...3).map { episode(season, $0) } }
    }

    func library() async -> ShelfLibrary {
        let list = episodes
        let loads = episodeLoads
        let dependencies = ShelfModel.Dependencies(
            load: { [series] _, kind in ShelfCatalogue(titles: kind == .series ? [series] : [], categories: ["Drama"]) },
            hasLogin: { _ in true },
            info: { _, _ in
                loads.value += 1
                return .series(SeriesInfo(episodes: list))
            })
        let library = ShelfLibrary(movies: ShelfModel(kind: .movie, dependencies), series: ShelfModel(kind: .series, dependencies))
        library.sourcesChanged([SourceDescriptor(id: source, name: "Cabin", kind: .xtream, url: URL(fileURLWithPath: "/cabin"))])
        library.open()
        await library.series.settled()
        return library
    }

    func activity(_ follow: inout Task<Void, Never>?) async -> ShelfActivity {
        let activity = ShelfActivity()
        let store = store
        follow = Task { [container] in
            await activity.follow(store)
            withExtendedLifetime(container) {}
        }
        await Task.yield()
        return activity
    }

    func playback(autoplays: Bool = true) -> ShelfPlayback {
        ShelfPlayback(
            .init(
                engine: engine,
                address: { _, target in
                    if case .episode(let episode, _) = target { return URL(fileURLWithPath: "/\(episode.id).mp4") }
                    return URL(fileURLWithPath: "/other.mp4")
                },
                willPlay: {},
                autoplays: { autoplays },
                sleep: { [ticker] _ in try await ticker.wait() }))
    }

    /// Plays `episode` and waits until its next episode is known.
    func start(_ playback: ShelfPlayback, _ episode: Episode, library: ShelfLibrary, activity: ShelfActivity) async {
        playback.play(episode, of: series, from: 0, library: library, activity: activity)
        #expect(await eventually { engine.state == .playing && playback.transport?.state == .playing })
    }

    /// Sends the position until the player shows `offer`.
    func reach(_ seconds: Int, _ offer: UpNextTimer.Offer, _ playback: ShelfPlayback) async -> Bool {
        await eventually {
            engine.send(position: seconds)
            return playback.upNext?.offer == offer
        }
    }

    func countDown() async {
        for _ in 0..<UpNext.countdown {
            await ticker.fire()
        }
    }

    @Test("up-next/next-episode-near-the-end the button from 60 seconds before the end plays the next episode")
    func button() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        await start(playback, episode(1, 1), library: library, activity: activity)
        engine.send(position: 5300)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(playback.upNext == nil, "nothing before the last 60 seconds")
        #expect(await reach(5350, .button, playback))
        #expect(playback.upNext?.episode == episode(1, 2))
        playback.playNext()
        #expect(await eventually { engine.loads.last?.url.lastPathComponent == "\(episode(1, 2).id).mp4" })
        #expect(playback.playing == .episode(episode(1, 2), series: series))
    }

    @Test("up-next/up-next-counts-down the countdown plays the next episode in the same player")
    func countdown() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        await start(playback, episode(1, 3), library: library, activity: activity)
        #expect(await reach(5390, .countdown(10), playback))
        #expect(playback.upNext?.episode == episode(2, 1), "from the end of a season to the next one")
        await ticker.fire()
        #expect(await eventually { playback.upNext?.offer == .countdown(9) })
        await countDown()
        #expect(await eventually { playback.playing == .episode(episode(2, 1), series: series) })
        #expect(engine.loads.last?.options.startPosition == nil)
        #expect(playback.run.inRow == 1)
    }

    @Test("up-next/progress-follows-the-next-episode the finished episode counts as watched")
    func watched() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        await start(playback, episode(1, 1), library: library, activity: activity)
        #expect(await reach(5350, .button, playback))
        playback.playNext()
        #expect(await eventually { store.progress(of: episode(1, 1).id, source: source)?.state == .watched })
        #expect(await eventually { playback.playing == .episode(episode(1, 2), series: series) })
    }

    @Test("up-next/cancel-keeps-watching Cancel plays to the end and then closes")
    func cancel() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        await start(playback, episode(1, 1), library: library, activity: activity)
        #expect(await reach(5390, .countdown(10), playback))
        playback.cancelUpNext()
        #expect(playback.upNext == nil)
        await countDown()
        engine.send(position: 5395)
        #expect(playback.upNext == nil)
        #expect(engine.loads.count == 1, "nothing else plays")
        engine.finish()
        #expect(await eventually { playback.playing == nil }, "the end goes back to the page")
    }

    @Test("up-next/which-episode-is-next the last episode ends on the page")
    func lastEpisode() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        await start(playback, episode(2, 3), library: library, activity: activity)
        engine.send(position: 5390)
        #expect(playback.upNext == nil)
        engine.finish()
        #expect(await eventually { playback.playing == nil })
        #expect(episodeLoads.value == 1)
    }

    @Test("up-next/which-episode-is-next the list loads once for a run of episodes")
    func oneLoad() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        await start(playback, episode(1, 1), library: library, activity: activity)
        for next in [episode(1, 2), episode(1, 3)] {
            #expect(await reach(5350, .button, playback))
            playback.playNext()
            #expect(await eventually { playback.playing == .episode(next, series: series) && playback.transport?.state == .playing })
        }
        #expect(episodeLoads.value == 1)
    }

    @Test("up-next/turn-autoplay-off with autoplay off nothing shows and the end closes")
    func autoplayOff() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback(autoplays: false)
        await start(playback, episode(1, 1), library: library, activity: activity)
        engine.send(position: 5390)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(playback.upNext == nil)
        engine.finish()
        #expect(await eventually { playback.playing == nil })
        #expect(engine.loads.count == 1)
    }

    @Test("up-next/still-watching three episodes from the countdown, then the card asks")
    func stillWatching() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        await start(playback, episode(1, 1), library: library, activity: activity)
        for next in [episode(1, 2), episode(1, 3), episode(2, 1)] {
            #expect(await reach(5390, .countdown(10), playback))
            await countDown()
            #expect(await eventually { playback.playing == .episode(next, series: series) && playback.transport?.state == .playing })
        }
        #expect(await reach(5390, .asking, playback))
        await countDown()
        #expect(playback.playing == .episode(episode(2, 1), series: series), "the question does not count down")
        engine.finish()
        try? await Task.sleep(for: .milliseconds(100))
        #expect(playback.playing == .episode(episode(2, 1), series: series), "the question stays at the end")
        playback.playNext()
        #expect(await eventually { playback.playing == .episode(episode(2, 2), series: series) })
        #expect(playback.run.inRow == 0)
    }

    @Test("title-detail-and-episode-picker/play-an-episode-and-come-back the page shows the episode that played last")
    func pageFollows() async throws {
        let library = await library()
        let model = TitleModel(title: series, shelf: library.series)
        await model.load()
        _ = model.willPlay(episode(1, 3), progress: [:])
        model.played(episode(2, 1))
        #expect(model.pickedSeason == "season-2")
        #expect(model.lastPlayed == episode(2, 1).id)
        #expect(try await library.series.loadEpisodes(series).count == episodes.count, "the page's list is kept")
        #expect(episodeLoads.value == 1, "the page's info call is the only one; the list comes from its answer")
    }

    @Test("up-next/still-watching an input starts the run again")
    func inputResets() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        await start(playback, episode(1, 1), library: library, activity: activity)
        #expect(await reach(5390, .countdown(10), playback))
        await countDown()
        #expect(await eventually { playback.run.inRow == 1 && playback.transport?.state == .playing })
        playback.transport?.skip(forward: false)
        #expect(playback.run.inRow == 0)
    }
}

/// A sleep that returns when the test fires it, one waiter at a time.
@MainActor
final class Ticker {
    private var waiting: [CheckedContinuation<Void, any Error>] = []

    func wait() async throws {
        try await withCheckedThrowingContinuation { waiting.append($0) }
        try Task.checkCancellation()
    }

    /// Lets every waiting sleep return, after giving the count a moment to wait.
    func fire() async {
        for _ in 0..<20 where waiting.isEmpty {
            try? await Task.sleep(for: .milliseconds(10))
        }
        let now = waiting
        waiting = []
        now.forEach { $0.resume() }
        await Task.yield()
        await Task.yield()
    }
}
