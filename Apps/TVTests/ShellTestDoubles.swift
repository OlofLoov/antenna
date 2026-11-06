import AntennaCore
import Foundation

@testable import AntennaTV

/// A `PlaybackEngine` that records calls. `load` fails when `failLoads` is set.
@MainActor
final class RecordingEngine: PlaybackEngine {
    private(set) var loaded: [URL] = []
    private(set) var plays = 0
    private(set) var pauses = 0
    private(set) var stops = 0
    var failLoads = false
    private var current: PlaybackState = .idle

    var state: PlaybackState { current }

    func load(_ url: URL) async throws {
        loaded.append(url)
        if failLoads {
            current = .failed("failed")
            throw SystemPlaybackEngine.LoadError.failed
        }
        current = .loading
    }

    func play() async {
        plays += 1
        if case .failed = current { return }
        current = .playing
    }

    func pause() async {
        pauses += 1
        current = .paused
    }

    func stop() async {
        stops += 1
        current = .idle
    }
}

/// Loads that finish when the test says so.
@MainActor
final class ScriptedLoader {
    private var waiting: [UUID: [CheckedContinuation<Playlist, any Error>]] = [:]
    private(set) var calls: [UUID] = []

    func load(_ source: SourceDescriptor) async throws -> Playlist {
        calls.append(source.id)
        return try await withCheckedThrowingContinuation { waiting[source.id, default: []].append($0) }
    }

    func isWaiting(_ id: UUID) -> Bool { !(waiting[id] ?? []).isEmpty }

    func finish(_ id: UUID, with channels: [Channel]) {
        resume(id) { $0.resume(returning: Playlist(channels: channels)) }
    }

    func fail(_ id: UUID, with error: any Error) {
        resume(id) { $0.resume(throwing: error) }
    }

    private func resume(_ id: UUID, _ body: (CheckedContinuation<Playlist, any Error>) -> Void) {
        guard var list = waiting[id], !list.isEmpty else { return }
        body(list.removeFirst())
        waiting[id] = list
    }
}

/// A clock the test advances by hand.
@MainActor
final class ManualClock {
    private var now = Duration.zero
    private var sleepers: [(until: Duration, continuation: CheckedContinuation<Void, Never>)] = []

    /// Every duration asked for, in order.
    private(set) var requested: [Duration] = []

    var pending: Int { sleepers.count }

    func sleep(_ duration: Duration) async throws {
        requested.append(duration)
        let until = now + duration
        await withCheckedContinuation { sleepers.append((until, $0)) }
        try Task.checkCancellation()
    }

    func advance(by duration: Duration) {
        now += duration
        let due = sleepers.filter { $0.until <= now }
        sleepers.removeAll { $0.until <= now }
        due.forEach { $0.continuation.resume() }
    }
}

extension Channel {
    /// A channel with an Xtream-style id and a link without credentials.
    static func fixture(_ id: String) -> Channel {
        Channel(id: "fixture.test/live/\(id)", name: "Channel \(id)", streamURL: URL(fileURLWithPath: "/fixture/\(id).ts"))
    }
}
