import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import AntennaDemux

/// `DemuxEngine` against the fixture server, the FFmpeg path's half of the
/// contract suite that `AVPlayerEngine` runs in the app tests.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct DemuxEngineTests {
    @Test(
        "playback-engine/every-common-stream-type-plays raw broadcast streams and Matroska play through the FFmpeg path",
        arguments: ["channel.ts", "channel.mkv"])
    func plays(file: String) async throws {
        let harness = try await Harness()
        let states = Recorded(await harness.engine.states())
        try await harness.engine.load(harness.url(file))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        #expect(await eventually { states.values == [.idle, .loading, .playing] })
        let presented = await current(harness.engine.presentation())
        let format = try #require(presented.flatMap { $0 })
        #expect(format.video?.width == 320 && format.video?.height == 180)
        #expect(format.video?.codec == "h264")
        #expect(format.audio == PresentationInfo.Audio(codec: "aac", channels: 2, isDecodable: true))
        let tracks = try #require(await current(harness.engine.tracks()))
        #expect(tracks.audio.map(\.id) == ["audio-0"])
        #expect(tracks.selectedAudio == "audio-0")
        states.cancel()
        await harness.stop()
    }

    @Test("playback-engine/starting-a-channel-replaces-the-old-one-cleanly the old connection closes before the new one opens")
    func oneConnectionAtATime() async throws {
        let harness = try await Harness()
        await harness.server.always("/channel.ts", .stall(afterBytes: 100_000))
        try await harness.engine.load(harness.url("channel.ts"))
        await harness.engine.play()
        #expect(await eventually { await harness.server.openPaths.contains("/channel.ts") })
        try await harness.engine.load(harness.url("channel.mkv"))
        let next = try #require(await harness.server.requests(for: "/channel.mkv").first)
        #expect(!next.openAtArrival.contains("/channel.ts"))
        await harness.stop()
    }

    @Test("playback-engine/starting-a-channel-replaces-the-old-one-cleanly an abandoned load ends quietly")
    func abandonedLoadEndsQuietly() async throws {
        let harness = try await Harness()
        await harness.server.always("/channel.ts", .stall(afterBytes: 0))
        let states = Recorded(await harness.engine.states())
        let abandoned = Task { try await harness.engine.load(harness.url("channel.ts")) }
        #expect(await eventually { await !harness.server.requests(for: "/channel.ts").isEmpty })
        try await harness.engine.load(harness.url("channel.mkv"))
        await #expect(throws: CancellationError.self) { try await abandoned.value }
        #expect(!states.values.contains { if case .failed = $0 { true } else { false } })
        await harness.engine.stop()
        #expect(harness.engine.state == .idle)
        states.cancel()
        await harness.stop()
    }

    @Test(
        "playback-engine/streams-that-cannot-play-fail-with-a-clear-reason refusals and non-video fail on the FFmpeg path",
        arguments: [
            ("missing.ts", PlaybackFailure.notFound),
            ("page.html", PlaybackFailure.unreadable),
            ("garbage.bin", PlaybackFailure.unreadable),
        ])
    func failsWithAReason(file: String, reason: PlaybackFailure) async throws {
        let harness = try await Harness()
        await #expect(throws: reason) { try await harness.engine.load(harness.url(file)) }
        #expect(harness.engine.state == .failed(reason))
        await harness.stop()
    }

    @Test("playback-engine/streams-that-cannot-play-fail-with-a-clear-reason a broken address fails without contacting a server")
    func brokenAddress() async throws {
        let harness = try await Harness()
        let broken = try #require(URL(string: "rtsp://example.invalid/stream"))
        await #expect(throws: PlaybackFailure.unreadable) { try await harness.engine.load(broken) }
        await harness.stop()
    }

    @Test("playback-engine/starting-a-channel-replaces-the-old-one-cleanly stop reports idle and clears the format")
    func stopClears() async throws {
        let harness = try await Harness()
        try await harness.engine.load(harness.url("channel.ts"))
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        let presentation = Recorded(await harness.engine.presentation())
        await harness.engine.stop()
        #expect(harness.engine.state == .idle)
        #expect(await eventually { presentation.values.last == .some(nil) })
        presentation.cancel()
        await harness.stop()
    }
}

/// A started fixture server and a `DemuxEngine` with fast retries.
@MainActor
private struct Harness {
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

/// Every value a stream yielded, in order.
@MainActor
final class Recorded<Value: Sendable> {
    private(set) var values: [Value] = []
    private var task: Task<Void, Never>?

    init(_ stream: AsyncStream<Value>) {
        task = Task { @MainActor [weak self] in
            for await value in stream { self?.values.append(value) }
        }
    }

    func cancel() {
        task?.cancel()
    }
}

@MainActor
func eventually(timeout: Duration = .seconds(10), _ condition: @MainActor () async -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(50))
    }
    return await condition()
}

/// The value a broadcast stream yields first, its current one.
func current<Value: Sendable>(_ stream: AsyncStream<Value>) async -> Value? {
    var iterator = stream.makeAsyncIterator()
    return await iterator.next()
}
