import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import Antenna

@MainActor
@Suite(.serialized, .timeLimit(.minutes(2))) struct AVPlayerEnginePauseTests {
    @Test("playback-engine/pause-and-play-again live TV continues from what is on air now")
    func liveResumesAtTheEdge() async throws {
        let harness = try await PlayerHarness()
        let position = Recorded(await harness.engine.position())
        try await harness.engine.load(harness.url("live/hls/index.m3u8"))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        try await Task.sleep(for: .seconds(1))
        await harness.engine.pause()
        let pausedAt = try #require(position.last).time
        try await Task.sleep(for: .seconds(5))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        #expect(await eventually { (position.last?.time ?? .zero) - pausedAt >= .seconds(3) })
        #expect(position.last?.isLive == true)
        position.cancel()
        await harness.stop()
    }

    @Test("playback-engine/pause-and-play-again a film continues within a second of where it stopped")
    func filmResumesInPlace() async throws {
        let harness = try await PlayerHarness()
        let position = Recorded(await harness.engine.position())
        try await harness.engine.load(harness.url("film.mp4"))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        try await Task.sleep(for: .seconds(1.5))
        await harness.engine.pause()
        let pausedAt = try #require(position.last).time
        try await Task.sleep(for: .seconds(2))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        try await Task.sleep(for: .milliseconds(100))
        let resumedAt = try #require(position.last).time
        #expect(resumedAt >= pausedAt - .milliseconds(100))
        #expect(resumedAt - pausedAt < .seconds(1))
        position.cancel()
        await harness.stop()
    }

    @Test("playback-engine/pause-and-play-again pause stops the reconnect attempts and play starts the channel again")
    func pauseWhileReconnecting() async throws {
        let harness = try await PlayerHarness(fastWaits: true)
        try await harness.engine.load(harness.url("live/hls/index.m3u8"))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        await harness.server.always("/live/hls/index.m3u8", .status(503))
        for index in 0..<3 { await harness.server.always("/live/hls/segment\(index).ts", .status(503)) }
        #expect(await eventually(timeout: .seconds(40)) { harness.engine.state.isReconnecting })
        await harness.engine.pause()
        #expect(harness.engine.state == .paused)
        try await Task.sleep(for: .milliseconds(300))
        let asked = await harness.server.requests.count
        try await Task.sleep(for: .seconds(1))
        #expect(await harness.server.requests.count == asked)
        await harness.server.serveEverything()
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        await harness.stop()
    }

    @Test("playback-engine/pause-and-play-again nothing happens with nothing to pause or play")
    func nothingToPause() async throws {
        let harness = try await PlayerHarness()
        let states = Recorded(await harness.engine.states())
        await harness.engine.pause()
        await harness.engine.play()
        try await Task.sleep(for: .milliseconds(100))
        #expect(states.values == [.idle])
        try await harness.engine.load(harness.url("film.mp4"))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        await harness.engine.pause()
        await harness.engine.pause()
        await harness.engine.play()
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        #expect(states.values == [.idle, .loading, .playing, .paused, .playing])
        states.cancel()
        await harness.stop()
    }
}

@MainActor
@Suite(.serialized, .timeLimit(.minutes(2))) struct AVPlayerEngineFilmTests {
    @Test("playback-engine/films-start-where-you-left-off-skip-and-end a film opens at its saved time")
    func opensAtTheSavedTime() async throws {
        let harness = try await PlayerHarness()
        let position = Recorded(await harness.engine.position())
        try await harness.engine.load(harness.url("film.mp4"), options: PlaybackOptions(startPosition: .seconds(3)))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        #expect(await eventually { (position.last?.time ?? .zero) >= .seconds(2.5) })
        #expect(position.last?.duration.map { $0 > .seconds(5) } == true)
        position.cancel()
        await harness.stop()
    }

    @Test("playback-engine/films-start-where-you-left-off-skip-and-end a saved time past the end starts at the beginning")
    func savedTimePastTheEnd() async throws {
        let harness = try await PlayerHarness()
        let position = Recorded(await harness.engine.position())
        try await harness.engine.load(harness.url("film.mp4"), options: PlaybackOptions(startPosition: .seconds(60)))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        try await Task.sleep(for: .milliseconds(600))
        #expect((position.last?.time ?? .seconds(99)) < .seconds(2))
        position.cancel()
        await harness.stop()
    }

    @Test("playback-engine/films-start-where-you-left-off-skip-and-end a skip lands within a second, past the end it finishes")
    func skipAndFinish() async throws {
        let harness = try await PlayerHarness()
        let position = Recorded(await harness.engine.position())
        try await harness.engine.load(harness.url("film.mp4"))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        try await harness.engine.seek(to: .seconds(4))
        let landed = try #require(position.last).time
        #expect(landed > .seconds(3) && landed < .seconds(5))
        try await harness.engine.seek(to: .seconds(30))
        #expect(harness.engine.state == .ended)
        try await Task.sleep(for: .milliseconds(300))
        let asked = await harness.server.requests.count
        try await Task.sleep(for: .seconds(1))
        #expect(await harness.server.requests.count == asked)
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        #expect((position.last?.time ?? .seconds(99)) < .seconds(2))
        position.cancel()
        await harness.stop()
    }

    @Test("playback-engine/films-start-where-you-left-off-skip-and-end a film that plays to its end finishes")
    func playsToTheEnd() async throws {
        let harness = try await PlayerHarness()
        try await harness.engine.load(harness.url("film.mp4"), options: PlaybackOptions(startPosition: .seconds(4)))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .ended })
        await harness.stop()
    }

    @Test("playback-engine/films-start-where-you-left-off-skip-and-end live TV ignores a saved time and refuses to skip")
    func liveRefusesSkips() async throws {
        let harness = try await PlayerHarness()
        try await harness.engine.load(harness.url("live/hls/index.m3u8"), options: PlaybackOptions(startPosition: .seconds(1)))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        await #expect(throws: SeekRefusal.live) { try await harness.engine.seek(to: .seconds(1)) }
        await harness.stop()
    }

    @Test("playback-engine/films-start-where-you-left-off-skip-and-end a film whose server cannot skip fails as unreadable")
    func noRangesFails() async throws {
        let harness = try await PlayerHarness()
        await harness.server.always("/film.mp4", .ignoreRanges)
        await #expect(throws: PlaybackFailure.unreadable) {
            try await harness.engine.load(harness.url("film.mp4"), options: PlaybackOptions(startPosition: .seconds(3)))
        }
        await harness.stop()
    }

    @Test("playback-engine/a-dropped-channel-reconnects a film that drops resumes at the time it dropped")
    func filmResumesAfterADrop() async throws {
        let harness = try await PlayerHarness()
        let position = Recorded(await harness.engine.position())
        let states = Recorded(await harness.engine.states())
        let film = try harness.longPlaylist(segments: 12)
        await harness.server.always("/long.m3u8", .body(film, contentType: "application/vnd.apple.mpegurl"))
        try await harness.engine.load(harness.url("long.m3u8"), options: PlaybackOptions(startPosition: .seconds(2)))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        for index in 0..<3 { await harness.server.always("/hls/segment\(index).ts", .status(503)) }
        #expect(await eventually(timeout: .seconds(30)) { states.values.contains { $0.isReconnecting } })
        let dropped = position.last?.time ?? .zero
        for index in 0..<3 { await harness.server.always("/hls/segment\(index).ts", .serve) }
        #expect(await eventually(timeout: .seconds(30)) { harness.engine.state == .playing || harness.engine.state == .ended })
        #expect((position.last?.time ?? .zero) >= dropped - .seconds(1))
        position.cancel()
        states.cancel()
        await harness.stop()
    }
}
