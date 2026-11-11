import AntennaCore
import Foundation

@testable import Antenna

/// An engine whose state, picture format and tracks the test sends. A load
/// fails with `failNextLoad` once when it is set.
@MainActor
final class PlayerTestEngine: PlaybackEngine {
    private(set) var loaded: [URL] = []
    private(set) var plays = 0
    private(set) var pauses = 0
    private(set) var audioPicks: [MediaTrack.ID] = []
    private(set) var subtitlePicks: [MediaTrack.ID?] = []
    var failNextLoad: PlaybackFailure?
    var supportsPictureInPicture = false
    private let stateCast = Broadcast(PlaybackState.idle)
    private let presentationCast = Broadcast(PresentationInfo?.none)
    private let tracksCast = Broadcast(TrackList.empty)

    var state: PlaybackState { stateCast.value }

    var capabilities: EngineCapabilities { EngineCapabilities(supportsPictureInPicture: supportsPictureInPicture) }

    func load(_ url: URL, options: PlaybackOptions) async throws {
        loaded.append(url)
        if let failure = failNextLoad {
            failNextLoad = nil
            stateCast.send(.failed(failure))
            throw failure
        }
        stateCast.send(.loading)
    }

    func play() async {
        plays += 1
        if case .failed = state { return }
        stateCast.send(.playing)
    }

    func pause() async {
        pauses += 1
        stateCast.send(.paused)
    }

    func stop() async { stateCast.send(.idle) }
    func seek(to time: Duration) async throws { throw SeekRefusal.live }

    func selectAudio(_ id: MediaTrack.ID) async {
        audioPicks.append(id)
        var list = tracksCast.value
        list.selectedAudio = id
        tracksCast.send(list)
    }

    func selectSubtitle(_ id: MediaTrack.ID?) async {
        subtitlePicks.append(id)
        var list = tracksCast.value
        list.selectedSubtitle = id
        tracksCast.send(list)
    }

    func send(_ state: PlaybackState) { stateCast.send(state) }
    func send(_ presentation: PresentationInfo?) { presentationCast.send(presentation) }
    func send(_ tracks: TrackList) { tracksCast.send(tracks) }

    func states() async -> AsyncStream<PlaybackState> { stateCast.stream() }
    func presentation() async -> AsyncStream<PresentationInfo?> { presentationCast.stream() }
    func tracks() async -> AsyncStream<TrackList> { tracksCast.stream() }
    func position() async -> AsyncStream<PlaybackPosition> { Broadcast(PlaybackPosition.zero).stream() }
    func subtitleCues() async -> AsyncStream<[SubtitleCue]> { Broadcast([SubtitleCue]()).stream() }
}

/// A clock the test moves by hand. `sleep` returns once `advance` has moved
/// past its deadline, and throws when its task is cancelled.
@MainActor
final class SleepClock {
    private struct Sleeper {
        var id: UUID
        var deadline: Duration
        var continuation: CheckedContinuation<Void, any Error>
    }

    private(set) var elapsed = Duration.zero
    private var sleepers: [Sleeper] = []

    var pending: Int { sleepers.count }

    func sleep(_ duration: Duration) async throws {
        let id = UUID()
        let deadline = elapsed + duration
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    sleepers.append(Sleeper(id: id, deadline: deadline, continuation: continuation))
                }
            }
        } onCancel: {
            Task { @MainActor in self.cancel(id) }
        }
    }

    /// Moves time on by `duration` and wakes every sleeper whose deadline passed.
    func advance(by duration: Duration) async {
        await settle()
        elapsed += duration
        let due = sleepers.filter { $0.deadline <= elapsed }
        sleepers.removeAll { $0.deadline <= elapsed }
        due.forEach { $0.continuation.resume() }
        await settle()
    }

    /// Lets tasks waiting on the main actor run.
    func settle() async {
        for _ in 0..<20 { await Task.yield() }
    }

    private func cancel(_ id: UUID) {
        guard let index = sleepers.firstIndex(where: { $0.id == id }) else { return }
        sleepers.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}

/// A connection the test switches on and off.
final class ScriptedNetwork: Sendable {
    private let cast = Broadcast(true)

    var watch: NetworkWatch {
        NetworkWatch { [cast] in cast.stream() }
    }

    func set(online: Bool) { cast.send(online) }
}

extension LogLines {
    /// A player log that keeps every line here.
    var playerLog: PlayerLog {
        PlayerLog { [self] line in add(line) }
    }
}
