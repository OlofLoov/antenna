import AntennaCore
import Foundation

/// A shared, ordered record of what fake engines were asked to do.
actor EngineLog {
    private(set) var entries: [String] = []

    func add(_ entry: String) {
        entries.append(entry)
    }
}

/// A `PlaybackEngine` whose loads succeed, fail or hand off as scripted,
/// and that records every call in an `EngineLog`.
actor FakeEngine: PlaybackEngine {
    let name: String
    let log: EngineLog
    private var results: [Result<Void, any Error>] = []
    private var gate: CheckedContinuation<Void, Never>?
    private var holdsLoads = false
    private let stateCast = Broadcast(PlaybackState.idle)
    private let presentationCast = Broadcast(PresentationInfo?.none)
    private let tracksCast = Broadcast(TrackList.empty)
    private let positionCast = Broadcast(PlaybackPosition.zero)
    private let cuesCast = Broadcast([SubtitleCue]())

    init(_ name: String, log: EngineLog) {
        self.name = name
        self.log = log
    }

    /// The next loads end with these results, in order, then succeed.
    func script(_ next: Result<Void, any Error>...) {
        results.append(contentsOf: next)
    }

    /// Loads wait for `release()` before they finish.
    func holdLoads() {
        holdsLoads = true
    }

    func release() {
        holdsLoads = false
        gate?.resume()
        gate = nil
    }

    var isHolding: Bool { gate != nil }

    func send(_ state: PlaybackState) {
        stateCast.send(state)
    }

    func send(_ info: PresentationInfo?) {
        presentationCast.send(info)
    }

    var state: PlaybackState { stateCast.value }
    var capabilities: EngineCapabilities { EngineCapabilities(supportsPictureInPicture: name == "system") }

    func load(_ url: URL, options: PlaybackOptions) async throws {
        await log.add("\(name).load \(url.lastPathComponent)")
        stateCast.send(.loading)
        if holdsLoads { await withCheckedContinuation { gate = $0 } }
        let result = results.isEmpty ? .success(()) : results.removeFirst()
        if case .failure(let error) = result {
            if let failure = error as? PlaybackFailure { stateCast.send(.failed(failure)) }
            throw error
        }
    }

    func play() async {
        await log.add("\(name).play")
        stateCast.send(.playing)
    }

    func pause() async {
        await log.add("\(name).pause")
        stateCast.send(.paused)
    }

    func stop() async {
        await log.add("\(name).stop")
        stateCast.send(.idle)
    }

    func seek(to time: Duration) async throws {
        await log.add("\(name).seek")
    }

    func selectAudio(_ id: MediaTrack.ID) async { await log.add("\(name).audio \(id)") }
    func selectSubtitle(_ id: MediaTrack.ID?) async { await log.add("\(name).subtitle \(id ?? "off")") }
    func states() async -> AsyncStream<PlaybackState> { stateCast.stream() }
    func presentation() async -> AsyncStream<PresentationInfo?> { presentationCast.stream() }
    func tracks() async -> AsyncStream<TrackList> { tracksCast.stream() }
    func position() async -> AsyncStream<PlaybackPosition> { positionCast.stream() }
    func subtitleCues() async -> AsyncStream<[SubtitleCue]> { cuesCast.stream() }
}

/// Values a stream yielded, in order.
actor Collected<Value: Sendable> {
    private(set) var values: [Value] = []

    var last: Value? { values.last }

    func add(_ value: Value) {
        values.append(value)
    }
}

/// A sleep that returns at once and records every wait, for a simulated clock.
actor RecordedSleeps {
    private(set) var waits: [Duration] = []

    func sleep(_ duration: Duration) {
        waits.append(duration)
    }
}

/// Waits until `condition` holds, polling, or gives up after `timeout`.
func eventually(timeout: Duration = .seconds(2), _ condition: @Sendable () async -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return await condition()
}

extension URL {
    /// A URL from a string literal the test controls.
    static func test(_ string: String) -> URL {
        URL(string: string) ?? URL(filePath: "/invalid")
    }
}
