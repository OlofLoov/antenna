import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import AntennaDemux

/// The demuxing engine as a multi-view tile: a provider's stream limit
/// fails at once while another tile shares the source, and mute holds
/// across streams.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct DemuxTileTests {
    @Test("multi-view/a-tile-that-fails-says-why a reconnect refused with 503 fails at once while another tile shares the source")
    func refusedReconnectFails() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in try await Task.sleep(for: .milliseconds(10)) }, log: { _ in })
        engine.refusalsAreFinal = true
        await server.script("/channel.ts", .serve)
        await server.always("/channel.ts", .status(503))
        let states = Recorded(await engine.states())
        try await engine.load(base.appending(path: "channel.ts"))
        await engine.play()
        #expect(await eventually(timeout: .seconds(30)) { engine.state == .failed(.serverError) })
        // The stream ending is a drop and reconnects once; the 503 on that reconnect ends it.
        #expect(!states.values.contains(.reconnecting(attempt: 2, of: 8)))
        #expect(await server.requests(for: "/channel.ts").count == 2)
        states.cancel()
        await engine.stop()
        await server.stop()
    }

    @Test(
        "multi-view/a-tile-that-fails-says-why a first connection refused with 503 is not tried again while another tile shares the source")
    func refusedTuneFails() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in try await Task.sleep(for: .milliseconds(10)) }, log: { _ in })
        engine.refusalsAreFinal = true
        await server.always("/channel.ts", .status(503))
        await #expect(throws: PlaybackFailure.serverError) { try await engine.load(base.appending(path: "channel.ts")) }
        #expect(await server.requests(for: "/channel.ts").count == 1)
        await engine.stop()
        await server.stop()
    }

    @Test("multi-view/sound-follows-the-highlighted-tile mute holds across streams and leaves the level alone")
    func muteHolds() {
        let engine = DemuxEngine(log: { _ in })
        engine.setVolume(0.4, muted: false)
        engine.setMuted(true)
        #expect(engine.isMuted)
        #expect(engine.audioRenderer.volume == 0.4)
        engine.setMuted(false)
        #expect(!engine.isMuted)
    }
}
