import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import Antenna

/// Apple's player engine against the in-test server.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(2))) struct AVPlayerEngineRoutingTests {
    @Test(
        "playback-engine/every-common-stream-type-plays HLS, films and radio play through Apple's player",
        arguments: ["hls/index.m3u8", "film.mp4", "radio.mp3", "radio.aac"])
    func plays(path: String) async throws {
        let harness = try await PlayerHarness()
        let states = Recorded(await harness.engine.states())
        try await harness.engine.load(harness.url(path))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        #expect(!states.values.contains { $0.isFailure })
        states.cancel()
        await harness.stop()
    }

    @Test("playback-engine/every-common-stream-type-plays a raw-looking address that serves HLS plays with no error")
    func hlsAtARawAddress() async throws {
        let harness = try await PlayerHarness()
        await harness.server.always("/live/u/p/42", .body(try harness.absolutePlaylist(), contentType: "application/octet-stream"))
        let routed = RoutedEngine(system: harness.engine, demuxer: harness.engine)
        try await routed.load(harness.url("live/u/p/42"))
        await routed.play()
        #expect(await eventually { harness.engine.state == .playing })
        await harness.stop()
    }
}

@MainActor
@Suite(.serialized, .timeLimit(.minutes(2))) struct AVPlayerEngineSwitchingTests {
    @Test("playback-engine/starting-a-channel-replaces-the-old-one-cleanly loading until playing, then idle after stop, nothing in between")
    func cleanTransitions() async throws {
        let harness = try await PlayerHarness()
        let states = Recorded(await harness.engine.states())
        try await harness.engine.load(harness.url("hls/index.m3u8"))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        try await harness.engine.load(harness.url("film.mp4"))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        await harness.engine.stop()
        #expect(await eventually { states.last == .idle })
        #expect(states.values == [.idle, .loading, .playing, .loading, .playing, .idle])
        states.cancel()
        await harness.stop()
    }

    @Test("playback-engine/starting-a-channel-replaces-the-old-one-cleanly the old connection closes before the new one opens")
    func oneConnectionAtATime() async throws {
        let harness = try await PlayerHarness()
        try await harness.engine.load(harness.url("live/hls/index.m3u8"))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        for index in 0..<3 { await harness.server.always("/live/hls/segment\(index).ts", .stall(afterBytes: 2000)) }
        #expect(await eventually { await harness.server.openPaths.contains { $0.hasPrefix("/live/") } })
        try await harness.engine.load(harness.url("radio.mp3"))
        let first = try #require(await harness.server.requests(for: "/radio.mp3").first)
        #expect(!first.openAtArrival.contains { $0.hasPrefix("/live/") })
        await harness.stop()
    }

    @Test("playback-engine/starting-a-channel-replaces-the-old-one-cleanly an abandoned load ends quietly")
    func abandonedLoadEndsQuietly() async throws {
        let harness = try await PlayerHarness()
        await harness.server.always("/channel.ts", .stall(afterBytes: 0))
        let states = Recorded(await harness.engine.states())
        let abandoned = Task { try await harness.engine.load(harness.url("channel.ts")) }
        #expect(await eventually { await !harness.server.requests(for: "/channel.ts").isEmpty })
        try await harness.engine.load(harness.url("film.mp4"))
        await #expect(throws: CancellationError.self) { try await abandoned.value }
        #expect(!states.values.contains { $0.isFailure })
        await harness.engine.stop()
        #expect(harness.engine.state == .idle)
        states.cancel()
        await harness.stop()
    }

    @Test("playback-engine/starting-a-channel-replaces-the-old-one-cleanly nothing from the previous channel is reported")
    func nothingLeftOver() async throws {
        let harness = try await PlayerHarness()
        try await harness.engine.load(harness.url("film.mp4"))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        let presentation = Recorded(await harness.engine.presentation())
        let position = Recorded(await harness.engine.position())
        let tracks = Recorded(await harness.engine.tracks())
        try await harness.engine.load(harness.url("radio.mp3"))
        #expect(await eventually { presentation.last == .some(nil) && position.last == .zero && tracks.last == .empty })
        presentation.cancel()
        position.cancel()
        tracks.cancel()
        await harness.stop()
    }
}

@MainActor
@Suite(.serialized, .timeLimit(.minutes(2))) struct AVPlayerEngineRetryTests {
    @Test("playback-engine/a-channel-that-won-t-start-is-retried-briefly a busy server is tried again while loading shows")
    func busyServerRetried() async throws {
        let harness = try await PlayerHarness()
        await harness.server.script("/hls/index.m3u8", .status(503), .status(500))
        let states = Recorded(await harness.engine.states())
        try await harness.engine.load(harness.url("hls/index.m3u8"))
        #expect(states.values == [.idle, .loading])
        #expect(await harness.server.requests(for: "/hls/index.m3u8").count >= 3)
        states.cancel()
        await harness.stop()
    }

    @Test("playback-engine/a-channel-that-won-t-start-is-retried-briefly a refused login fails at once")
    func refusedLoginNotRetried() async throws {
        let harness = try await PlayerHarness()
        await harness.server.always("/hls/index.m3u8", .status(401))
        await #expect(throws: PlaybackFailure.notAllowed) { try await harness.engine.load(harness.url("hls/index.m3u8")) }
        #expect(await harness.server.requests(for: "/hls/index.m3u8").count == 1)
        #expect(harness.engine.state == .failed(.notAllowed))
        await harness.stop()
    }

    @Test("playback-engine/a-dropped-channel-reconnects a live channel that drops reconnects with numbered attempts")
    func dropReconnects() async throws {
        let harness = try await PlayerHarness(fastWaits: true)
        let states = Recorded(await harness.engine.states())
        try await harness.engine.load(harness.url("live/hls/index.m3u8"))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        await harness.server.always("/live/hls/index.m3u8", .status(503))
        for index in 0..<3 { await harness.server.always("/live/hls/segment\(index).ts", .status(503)) }
        #expect(await eventually(timeout: .seconds(40)) { states.values.contains(.reconnecting(attempt: 1, of: 8)) })
        await harness.server.serveEverything()
        #expect(await eventually(timeout: .seconds(30)) { harness.engine.state == .playing })
        states.cancel()
        await harness.stop()
    }

    @Test("playback-engine/a-dropped-channel-reconnects when attempts run out it fails with the last reason")
    func attemptsRunOut() async throws {
        let harness = try await PlayerHarness(fastWaits: true)
        try await harness.engine.load(harness.url("live/hls/index.m3u8"))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        await harness.server.always("/live/hls/index.m3u8", .status(503))
        for index in 0..<3 { await harness.server.always("/live/hls/segment\(index).ts", .status(503)) }
        #expect(await eventually(timeout: .seconds(60)) { harness.engine.state == .failed(.serverError) })
        await harness.stop()
    }
}
