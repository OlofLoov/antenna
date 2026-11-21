import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import AntennaDemux

/// Zapping on a provider that allows one connection and frees it a moment
/// after the old channel closes
/// (playback-engine/a-channel-that-won-t-start-is-retried-briefly).
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct DemuxSwitchRetryTests {
    @Test(
        "playback-engine/a-channel-that-won-t-start-is-retried-briefly a refusal right after a switch is tried once more",
        arguments: [403, 458])
    func refusalAfterSwitchIsRetried(status: Int) async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        try await engine.load(base.appending(path: "channel.ts"))
        await server.script("/live/channel.ts", .status(status))
        try await engine.load(base.appending(path: "live/channel.ts"))
        #expect(await server.requests(for: "/live/channel.ts").count == 2)
        await engine.play()
        #expect(await eventually { engine.state == .playing })
        await engine.stop()
        await server.stop()
    }

    @Test("playback-engine/a-channel-that-won-t-start-is-retried-briefly a revoked password during zapping fails after one retry")
    func revokedDuringZapping() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        try await engine.load(base.appending(path: "channel.ts"))
        await server.always("/live/channel.ts", .status(403))
        await #expect(throws: PlaybackFailure.notAllowed) { try await engine.load(base.appending(path: "live/channel.ts")) }
        #expect(await server.requests(for: "/live/channel.ts").count == 2)
        await engine.stop()
        await server.stop()
    }

    @Test("playback-engine/a-channel-that-won-t-start-is-retried-briefly a refusal with no channel closed before fails at once")
    func firstStartFailsAtOnce() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        await server.always("/live/channel.ts", .status(403))
        await #expect(throws: PlaybackFailure.notAllowed) { try await engine.load(base.appending(path: "live/channel.ts")) }
        #expect(await server.requests(for: "/live/channel.ts").count == 1)
        await engine.stop()
        await server.stop()
    }
}
