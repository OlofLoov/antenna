import Foundation

/// The engine screens hold. It sends each address to the system or demuxer
/// engine by `EngineRouter`, stops the other engine before switching, and
/// forwards everything the active engine reports. When the demuxer throws
/// `EngineHandoff.toSystemPlayer` the same address loads on the system
/// engine with no failure in between.
///
/// Passing the same instance for both routes is allowed; that engine then
/// handles every address and replaces its own streams.
public actor RoutedEngine: PlaybackEngine {
    public nonisolated let system: any PlaybackEngine
    public nonisolated let demuxer: any PlaybackEngine

    private var active: (any PlaybackEngine)?
    private var generation = 0
    private var pumps: [Task<Void, Never>] = []
    private let stateCast = Broadcast(PlaybackState.idle)
    private let presentationCast = Broadcast(PresentationInfo?.none)
    private let tracksCast = Broadcast(TrackList.empty)
    private let positionCast = Broadcast(PlaybackPosition.zero)
    private let cuesCast = Broadcast([SubtitleCue]())

    public init(system: any PlaybackEngine, demuxer: any PlaybackEngine) {
        self.system = system
        self.demuxer = demuxer
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

    public func selectAudio(_ id: MediaTrack.ID) async { await active?.selectAudio(id) }
    public func selectSubtitle(_ id: MediaTrack.ID?) async { await active?.selectSubtitle(id) }

    public func states() async -> AsyncStream<PlaybackState> { stateCast.stream() }
    public func presentation() async -> AsyncStream<PresentationInfo?> { presentationCast.stream() }
    public func tracks() async -> AsyncStream<TrackList> { tracksCast.stream() }
    public func position() async -> AsyncStream<PlaybackPosition> { positionCast.stream() }
    public func subtitleCues() async -> AsyncStream<[SubtitleCue]> { cuesCast.stream() }

    /// Hands the screen over from the engine that played before when it is
    /// not `engine`, then forwards `engine`'s streams.
    private func activate(_ engine: any PlaybackEngine) async {
        guard active !== engine else { return }
        let previous = active
        pumps.forEach { $0.cancel() }
        pumps = []
        active = engine
        if let previous { await previous.handOver() }
        pumps = [
            Self.pump(await engine.states(), into: stateCast),
            Self.pump(await engine.presentation(), into: presentationCast),
            Self.pump(await engine.tracks(), into: tracksCast),
            Self.pump(await engine.position(), into: positionCast),
            Self.pump(await engine.subtitleCues(), into: cuesCast),
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
