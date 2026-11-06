import AntennaCore
import AntennaTestSupport
import Foundation

@testable import Antenna

/// Every value an engine stream yielded, in order.
@MainActor
final class Recorded<Value: Sendable> {
    private(set) var values: [Value] = []
    private var task: Task<Void, Never>?

    init(_ stream: AsyncStream<Value>) {
        task = Task { @MainActor [weak self] in
            for await value in stream { self?.values.append(value) }
        }
    }

    var last: Value? { values.last }

    func cancel() {
        task?.cancel()
    }
}

extension PlaybackState {
    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }

    var isReconnecting: Bool {
        if case .reconnecting = self { return true }
        return false
    }
}

/// Polls `condition` on the main actor until it holds or `timeout` passes.
@MainActor
func eventually(timeout: Duration = .seconds(15), _ condition: @MainActor () async -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(50))
    }
    return await condition()
}

/// A started fixture server and an engine to point at it.
@MainActor
struct PlayerHarness {
    let server: FixtureServer
    let base: URL
    let engine: AVPlayerEngine

    /// `fastWaits` shortens every retry and stall wait to 50 ms.
    init(fastWaits: Bool = false) async throws {
        server = try FixtureServer()
        base = try await server.start()
        engine =
            fastWaits
            ? AVPlayerEngine(sleep: { _ in try await Task.sleep(for: .milliseconds(50)) })
            : AVPlayerEngine()
    }

    func url(_ path: String) -> URL {
        base.appending(path: path)
    }

    /// An HLS playlist naming the fixture segments by full address, for
    /// serving at an address that does not end in .m3u8.
    func absolutePlaylist() throws -> Data {
        let text = try String(contentsOf: server.root.appending(path: "hls/index.m3u8"), encoding: .utf8)
        let lines = text.split(separator: "\n").map { line in
            line.hasSuffix(".ts") ? url("hls/\(line)").absoluteString : String(line)
        }
        return Data(lines.joined(separator: "\n").utf8)
    }

    func stop() async {
        await engine.stop()
        await server.stop()
    }
}
