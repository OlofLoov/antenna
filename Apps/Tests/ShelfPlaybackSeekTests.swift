import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// Skips, the end of a title and failures while a movie plays, on the
/// scripted engine of `ShelfPlaybackTests`.
extension ShelfPlaybackTests {
    @Test("movies-and-series-browsing/your-place-is-saved-as-you-watch a skip saves the new point before the picture gets there")
    func skipSaves() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        playback.play(movie, library: library, activity: activity)
        #expect(await eventually { engine.state == .playing })
        let saved = { store.progress(of: movie.id, source: source)?.position }
        engine.send(position: 100)
        #expect(await eventually { playback.transport?.position.time == .seconds(100) })

        playback.transport?.skip(forward: true)
        playback.transport?.skip(forward: true)
        #expect(await eventually { engine.seeks == [.seconds(110), .seconds(120)] }, "skips in a row count from the last one")
        #expect(await eventually { saved() == 120 })
        await playback.close()
        #expect(saved() == 120, "closing before the engine reports the new point keeps it")
    }

    @Test("player-controls-and-playback-errors/move-around-in-a-movie-or-episode back from the end plays from there, a refusal says so")
    func seekAfterTheEndAndRefusals() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        playback.play(movie, library: library, activity: activity)
        #expect(await eventually { engine.state == .playing })
        engine.send(position: 5390)
        engine.finish()
        #expect(await eventually { playback.transport?.isPaused == true })

        #expect(await playback.seek(to: .seconds(4000)))
        #expect(engine.loads.count == 2, "an ended title opens again")
        #expect(engine.loads.last?.options.startPosition == .seconds(4000))
        #expect(engine.state == .playing)
        #expect(engine.seeks.isEmpty)

        engine.refusesSeeks = true
        playback.transport?.skip(forward: false)
        #expect(await eventually { playback.transport?.notice == TitleTransport.cannotSkip })
        #expect(await eventually { playback.transport?.pending == nil })
    }

    @Test("player-controls-and-playback-errors/a-movie-or-episode-that-cannot-play-says-why a failed load says so, Try again loads")
    func failedLoad() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        engine.failsLoads = .notFound
        playback.play(movie, library: library, activity: activity)
        #expect(await eventually { playback.failure != nil })
        #expect(playback.failure?.title == "Stream not found")
        #expect(playback.failure?.explanation.contains("Cabin") == true, "named after the source")

        engine.failsLoads = nil
        playback.retry()
        #expect(playback.failure == nil)
        #expect(await eventually { engine.state == .playing })
        #expect(engine.loads.count == 2)

        engine.failsLoads = .stoppedSendingData
        engine.send(position: 300)
        #expect(await eventually { playback.transport?.position.time == .seconds(300) })
        try? await engine.load(URL(fileURLWithPath: "/again.mp4"), options: PlaybackOptions())
        #expect(await eventually { playback.failure != nil }, "a failure while playing shows too")
        engine.failsLoads = nil
        playback.retry()
        #expect(await eventually { engine.state == .playing })
        #expect(engine.loads.last?.options.startPosition == .seconds(300), "Try again picks up from the last time shown")
    }
}
