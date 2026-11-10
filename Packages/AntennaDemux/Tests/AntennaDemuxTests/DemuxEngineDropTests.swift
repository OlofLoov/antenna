import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import AntennaDemux

/// `DemuxEngine` handing HLS over, letting the connection go while live TV
/// is paused, and reconnecting after a drop.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct DemuxEngineDropTests {
    @Test("playback-engine/every-common-stream-type-plays an HLS playlist at a raw-looking address goes to Apple's player")
    func handsHLSOver() async throws {
        let harness = try await DropHarness()
        let playlist = try Data(contentsOf: FixtureServer.fixtures().appending(path: "hls/index.m3u8"))
        await harness.server.always("/live/u/p/42", .body(playlist, contentType: "application/octet-stream"))
        await #expect(throws: EngineHandoff.toSystemPlayer) { try await harness.engine.load(harness.url("live/u/p/42")) }
        #expect(harness.engine.state == .idle)
        await harness.stop()
    }

    @Test("playback-engine/pause-and-play-again on the FFmpeg path the provider's connection is let go while paused")
    func liveLetsGoWhilePaused() async throws {
        let harness = try await DropHarness()
        await harness.server.script("/channel.ts", .stall(afterBytes: 100_000))
        try await harness.engine.load(harness.url("channel.ts"))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        #expect(await harness.server.openPaths.contains("/channel.ts"))
        await harness.engine.pause()
        #expect(harness.engine.state == .paused)
        #expect(await eventually { await harness.server.openPaths.isEmpty })
        let before = await harness.server.requests(for: "/channel.ts").count
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        #expect(await harness.server.requests(for: "/channel.ts").count == before + 1)
        await harness.stop()
    }

    @Test("playback-engine/a-dropped-channel-reconnects a live channel that drops reconnects with numbered attempts")
    func dropReconnects() async throws {
        let harness = try await DropHarness()
        await harness.server.script("/channel.ts", .serve)
        let states = Recorded(await harness.engine.states())
        try await harness.engine.load(harness.url("channel.ts"))
        await harness.engine.play()
        #expect(await eventually(timeout: .seconds(30)) { states.values.contains(.reconnecting(attempt: 1, of: 8)) })
        #expect(await eventually { harness.engine.state == .playing })
        #expect(await harness.server.requests(for: "/channel.ts").count == 2)
        states.cancel()
        await harness.stop()
    }

    @Test("playback-engine/a-dropped-channel-reconnects when attempts run out it fails with the last reason")
    func attemptsRunOut() async throws {
        let harness = try await DropHarness()
        await harness.server.script("/channel.ts", .serve)
        await harness.server.always("/channel.ts", .status(503))
        try await harness.engine.load(harness.url("channel.ts"))
        await harness.engine.play()
        let states = Recorded(await harness.engine.states())
        #expect(await eventually(timeout: .seconds(30)) { harness.engine.state == .failed(.serverError) })
        #expect(states.values.contains(.reconnecting(attempt: 8, of: 8)))
        states.cancel()
        await harness.stop()
    }

    @Test("playback-engine/pause-and-play-again pause stops the reconnect attempts and play starts the channel again")
    func pauseWhileReconnecting() async throws {
        let harness = try await DropHarness(slowReconnects: true)
        await harness.server.script("/channel.ts", .serve)
        await harness.server.always("/channel.ts", .status(503))
        try await harness.engine.load(harness.url("channel.ts"))
        await harness.engine.play()
        #expect(await eventually(timeout: .seconds(30)) { harness.engine.state.isReconnecting })
        await harness.engine.pause()
        #expect(harness.engine.state == .paused)
        let asked = await harness.server.requests(for: "/channel.ts").count
        try await Task.sleep(for: .milliseconds(600))
        #expect(await harness.server.requests(for: "/channel.ts").count == asked)
        await harness.server.serveEverything()
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        await harness.stop()
    }
}

/// A fixture server and an engine whose waits are 10 ms, or 200 ms for
/// reconnects with `slowReconnects` so a test can catch the engine between
/// attempts.
@MainActor
private struct DropHarness {
    let server: FixtureServer
    let base: URL
    let engine: DemuxEngine

    init(slowReconnects: Bool = false) async throws {
        server = try FixtureServer()
        base = try await server.start()
        let wait = slowReconnects ? Duration.milliseconds(200) : .milliseconds(10)
        engine = DemuxEngine(sleep: { _ in try await Task.sleep(for: wait) }, log: { _ in })
    }

    func url(_ path: String) -> URL {
        base.appending(path: path)
    }

    func stop() async {
        await engine.stop()
        await server.stop()
    }
}

extension PlaybackState {
    fileprivate var isReconnecting: Bool {
        if case .reconnecting = self { return true }
        return false
    }
}
