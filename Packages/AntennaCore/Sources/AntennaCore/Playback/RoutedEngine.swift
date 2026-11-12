import Foundation
import Synchronization

/// The engine screens hold. It sends each address to the system or demuxer
/// engine by `EngineRouter`, stops the other engine before switching, and
/// forwards everything the active engine reports. When the demuxer throws
/// `EngineHandoff.toSystemPlayer` the same address loads on the system
/// engine with no failure in between.
///
/// Passing the same instance for both routes is allowed; that engine then
/// handles every address and replaces its own streams.
///
/// Two routed engines can trade their engines with `exchange(with:)`, so a
/// stream playing in one carries on in the other with no reload.
public actor RoutedEngine: PlaybackEngine {
    private struct Pair: Sendable {
        var system: any PlaybackEngine
        var demuxer: any PlaybackEngine
    }

    private nonisolated let pair: Mutex<Pair>

    /// The engine for HLS and the files the system reads.
    public nonisolated var system: any PlaybackEngine { pair.withLock { $0.system } }
    /// The engine for raw broadcast streams.
    public nonisolated var demuxer: any PlaybackEngine { pair.withLock { $0.demuxer } }

    private var active: (any PlaybackEngine)?
    private var generation = 0
    private var pumps: [Task<Void, Never>] = []
    private let stateCast = Broadcast(PlaybackState.idle)
    private let presentationCast = Broadcast(PresentationInfo?.none)
    private let tracksCast = Broadcast(TrackList.empty)
    private let positionCast = Broadcast(PlaybackPosition.zero)
    private let cuesCast = Broadcast([SubtitleCue]())
    private let timeshiftCast = Broadcast(TimeshiftStatus.off)

    public init(system: any PlaybackEngine, demuxer: any PlaybackEngine) {
        pair = Mutex(Pair(system: system, demuxer: demuxer))
    }

    /// The engine playing the current address, nil before the first load.
    public var activeEngine: (any PlaybackEngine)? { active }

    public var state: PlaybackState {
        get async { await active?.state ?? .idle }
    }

    public var capabilities: EngineCapabilities {
        get async { await (active ?? system).capabilities }
    }

    public func load(_ url: URL, options: PlaybackOptions) async throws {
        generation += 1
        let mine = generation
        let system = self.system
        let target = EngineRouter.route(for: url) == .system ? system : demuxer
        await activate(target)
        guard generation == mine else { throw CancellationError() }
        do {
            try await target.load(url, options: options)
        } catch EngineHandoff.toSystemPlayer where target !== system {
            guard generation == mine else { throw CancellationError() }
            await activate(system)
            guard generation == mine else { throw CancellationError() }
            try await system.load(url, options: options)
        }
        guard generation == mine else { throw CancellationError() }
    }

    public func play() async { await active?.play() }
    public func pause() async { await active?.pause() }

    public func stop() async {
        generation += 1
        await active?.stop()
    }

    public func seek(to time: Duration) async throws {
        guard let active else { throw SeekRefusal.notSeekable }
        try await active.seek(to: time)
    }

    public func seek(to date: Date) async throws {
        guard let active else { throw SeekRefusal.live }
        try await active.seek(to: date)
    }

    public func seekToLive() async { await active?.seekToLive() }

    /// Only the demuxer records, so the buffer is parked there whichever
    /// engine plays the catch-up programme.
    public func parkTimeshift() async { await demuxer.parkTimeshift() }

    public func resumeParkedTimeshift(at date: Date?) async throws {
        generation += 1
        let mine = generation
        let demuxer = self.demuxer
        await activate(demuxer)
        guard generation == mine else { throw CancellationError() }
        try await demuxer.resumeParkedTimeshift(at: date)
    }

    public func dropParkedTimeshift() async { await demuxer.dropParkedTimeshift() }

    public func selectAudio(_ id: MediaTrack.ID) async { await active?.selectAudio(id) }
    public func selectSubtitle(_ id: MediaTrack.ID?) async { await active?.selectSubtitle(id) }

    public func states() async -> AsyncStream<PlaybackState> { stateCast.stream() }
    public func presentation() async -> AsyncStream<PresentationInfo?> { presentationCast.stream() }
    public func tracks() async -> AsyncStream<TrackList> { tracksCast.stream() }
    public func position() async -> AsyncStream<PlaybackPosition> { positionCast.stream() }
    public func subtitleCues() async -> AsyncStream<[SubtitleCue]> { cuesCast.stream() }
    public func timeshift() async -> AsyncStream<TimeshiftStatus> { timeshiftCast.stream() }

    /// Trades engines with `other`: whatever plays in one carries on in the
    /// other, with no reload, and each forwards its new engines' reports
    /// from then on (multi-view/leave-multi-view). A load still running in
    /// either carries on in the engine it started on, and the call that
    /// asked for it throws `CancellationError`.
    public func exchange(with other: RoutedEngine) async {
        guard other !== self else { return }
        let mine = detach()
        let theirs = await other.detach()
        await attach(theirs)
        await other.attach(mine)
    }

    private func detach() -> (Pair, (any PlaybackEngine)?) {
        pumps.forEach { $0.cancel() }
        pumps = []
        let taken = (pair.withLock { $0 }, active)
        active = nil
        return taken
    }

    private func attach(_ taken: (Pair, (any PlaybackEngine)?)) async {
        generation += 1
        pair.withLock { $0 = taken.0 }
        active = taken.1
        if let engine = taken.1 {
            await forward(engine)
        } else {
            stateCast.send(.idle)
            presentationCast.send(nil)
            tracksCast.send(.empty)
            positionCast.send(.zero)
            cuesCast.send([])
            timeshiftCast.send(.off)
        }
    }

    /// Hands the screen over from the engine that played before when it is
    /// not `engine`, then forwards `engine`'s streams.
    private func activate(_ engine: any PlaybackEngine) async {
        guard active !== engine else { return }
        let previous = active
        pumps.forEach { $0.cancel() }
        pumps = []
        active = engine
        if let previous { await previous.handOver() }
        await forward(engine)
    }

    private func forward(_ engine: any PlaybackEngine) async {
        pumps = [
            Self.pump(await engine.states(), into: stateCast),
            Self.pump(await engine.presentation(), into: presentationCast),
            Self.pump(await engine.tracks(), into: tracksCast),
            Self.pump(await engine.position(), into: positionCast),
            Self.pump(await engine.subtitleCues(), into: cuesCast),
            Self.pump(await engine.timeshift(), into: timeshiftCast),
        ]
    }

    private static func pump<Value: Sendable>(_ stream: AsyncStream<Value>, into cast: Broadcast<Value>) -> Task<Void, Never> {
        Task {
            for await value in stream {
                guard !Task.isCancelled else { return }
                cast.send(value)
            }
        }
    }
}
