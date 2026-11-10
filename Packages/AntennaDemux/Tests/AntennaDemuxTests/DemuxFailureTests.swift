import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import AntennaDemux

/// AVI on the FFmpeg path, and failures mapped to the reasons Apple's
/// player gives for the same cause.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct DemuxFailureTests {
    @Test("playback-engine/every-common-stream-type-plays AVI with MPEG-4 video and MP3 sound opens on the FFmpeg path")
    func aviOpens() async throws {
        let harness = try await FailureHarness()
        try await harness.engine.load(harness.url("channel.avi"))
        let presented = await current(harness.engine.presentation())
        let format = try #require(presented.flatMap { $0 })
        #expect(format.video?.codec == "mpeg4")
        #expect(format.video?.width == 320 && format.video?.height == 180)
        #expect(format.audio?.codec == "mp3")
        await harness.stop()
    }

    @Test(
        "playback-engine/streams-that-cannot-play-fail-with-a-clear-reason server answers map to the shared reasons",
        arguments: [
            (401, PlaybackFailure.notAllowed), (403, .notAllowed), (404, .notFound), (429, .serverBusy),
            (500, .serverError), (503, .serverError), (418, .refused(status: 418)),
        ])
    func serverAnswers(status: Int, reason: PlaybackFailure) async throws {
        let harness = try await FailureHarness()
        await harness.server.always("/channel.ts", .status(status))
        await #expect(throws: reason) { try await harness.engine.load(harness.url("channel.ts")) }
        #expect(harness.engine.state == .failed(reason))
        await harness.stop()
    }

    @Test("playback-engine/streams-that-cannot-play-fail-with-a-clear-reason data but no picture fails as unreadable")
    func noPictureInTime() async throws {
        let harness = try await FailureHarness()
        await harness.server.always("/channel.ts", .stall(afterBytes: 188 * 5))
        await #expect(throws: PlaybackFailure.unreadable) { try await harness.engine.load(harness.url("channel.ts")) }
        #expect(harness.engine.state == .failed(.unreadable))
        await harness.stop()
    }
}

/// A fixture server and an engine with no retry waits and a half-second
/// first-frame timeout.
@MainActor
private struct FailureHarness {
    let server: FixtureServer
    let base: URL
    let engine: DemuxEngine

    init() async throws {
        server = try FixtureServer()
        base = try await server.start()
        engine = DemuxEngine(sleep: { _ in }, firstFrameTimeout: .milliseconds(500), log: { _ in })
    }

    func url(_ path: String) -> URL {
        base.appending(path: path)
    }

    func stop() async {
        await engine.stop()
        await server.stop()
    }
}
