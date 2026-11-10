import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import AntennaDemux

/// Zapping on the FFmpeg path: channels opened ahead, and starting a live
/// stream joined between keyframes.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct DemuxZapTests {
    @Test("playback-engine/channel-switching-is-fast a channel opened ahead starts with no new connection")
    func openedAheadNeedsNoNewConnection() async throws {
        let harness = try await ZapHarness()
        await harness.server.always("/channel.mkv", .stall(afterBytes: 100_000))
        let next = harness.url("channel.mkv")
        try await harness.engine.load(harness.url("channel.ts"))
        harness.engine.openAhead([next])
        #expect(await eventually { await harness.server.openPaths.contains("/channel.mkv") })
        try await harness.engine.load(next)
        #expect(await harness.server.requests(for: "/channel.mkv").count == 1)
        #expect(harness.engine.openAheadAddresses.isEmpty)
        await harness.stop()
    }

    @Test("playback-engine/starting-a-channel-replaces-the-old-one-cleanly stopping lets the channels opened ahead go")
    func stopClosesWhatWasOpenedAhead() async throws {
        let harness = try await ZapHarness()
        await harness.server.always("/channel.ts", .stall(afterBytes: 100_000))
        harness.engine.openAhead([harness.url("channel.ts")])
        #expect(await eventually { await harness.server.openPaths.contains("/channel.ts") })
        await harness.engine.stop()
        #expect(await eventually { await harness.server.openPaths.isEmpty })
        #expect(harness.engine.openAheadAddresses.isEmpty)
        await harness.stop()
    }

    @Test("playback-engine/channel-switching-is-fast a channel dropped from the list is closed")
    func droppedFromTheListCloses() async throws {
        let harness = try await ZapHarness()
        await harness.server.always("/channel.ts", .stall(afterBytes: 100_000))
        harness.engine.openAhead([harness.url("channel.ts")])
        #expect(await eventually { await harness.server.openPaths.contains("/channel.ts") })
        harness.engine.openAhead([])
        #expect(await eventually { await harness.server.openPaths.isEmpty })
        await harness.stop()
    }

    @Test("playback-engine/channel-switching-is-fast a stream kept open ahead holds only its newest bytes, aligned")
    func standbyKeepsTheNewestBytes() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let bytes = HTTPByteStream(url: base.appending(path: "channel.ts"))
        bytes.standbyWindow = 50_000
        try await bytes.open()
        let size = try Data(contentsOf: FixtureServer.fixtures().appending(path: "channel.ts")).count
        let held = await Task.detached { bytes.peek(size) }.value
        #expect(held.count <= 50_000)
        #expect(held.count > 50_000 - 188)
        #expect(held.first == 0x47)
        bytes.cancel()
        await server.stop()
    }

    @Test("playback-engine/channel-switching-is-fast a live stream joined between keyframes starts at the next one")
    func joinedBetweenKeyframes() async throws {
        let harness = try await ZapHarness()
        let whole = try Data(contentsOf: FixtureServer.fixtures().appending(path: "channel.ts"))
        let joined = whole.suffix(from: whole.startIndex + 188 * 100)
        await harness.server.always("/joined.ts", .body(Data(joined), contentType: "video/mp2t"))
        try await harness.engine.load(harness.url("joined.ts"))
        let presented = await current(harness.engine.presentation())
        let video = try #require(presented.flatMap { $0 }?.video)
        #expect(video.width == 320 && video.height == 180)
        await harness.stop()
    }
}

/// A fixture server and an engine with no waits.
@MainActor
private struct ZapHarness {
    let server: FixtureServer
    let base: URL
    let engine: DemuxEngine

    init() async throws {
        server = try FixtureServer()
        base = try await server.start()
        engine = DemuxEngine(sleep: { _ in }, log: { _ in })
    }

    func url(_ path: String) -> URL {
        base.appending(path: path)
    }

    func stop() async {
        await engine.stop()
        await server.stop()
    }
}
