import Foundation
import Synchronization

/// The engine screens hold. It sends each address to the system or demuxer
/// engine by `EngineRouter`, stops the other engine before switching, and
/// forwards everything the active engine reports. When the demuxer throws
/// `EngineHandoff.toSystemPlayer` the same address loads on the system
/// engine with no failure in between, and when the system engine throws
/// `EngineHandoff.toDemuxer` it loads on the demuxer. A load whose options
/// carry a fallback opens the fallback when Apple's player fails before the
/// stream first plays.
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
    /// Closed while this device may open no stream; nil never closes.
    public nonisolated let gate: StreamGate?

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

    /// A fallback waiting on the address the current load opened.
    private struct Pending {
        var fallback: StreamFallback
        /// The load's options without the fallback.
        var options: PlaybackOptions
        var generation: Int
        /// True once `load` returned, so a failure from then on starts the fallback itself.
        var loaded = false
    }

    private var pending: Pending?
    /// The load whose fallback started. Until the next load, a failure the
    /// engine no longer reports as its state is the failed address's,
    /// arriving late, and is kept back.
    private var fellBackIn: Int?
    /// True between `play` and the next `pause`, `stop` or `load`.
    private var wantsPlay = false
    private let fallbackCast = Broadcast(StreamFallback?.none)

    /// `gate`, when given, turns every load away while it is closed.
    public init(system: any PlaybackEngine, demuxer: any PlaybackEngine, gate: StreamGate? = nil) {
        self.gate = gate
        pair = Mutex(Pair(system: system, demuxer: demuxer))
    }

    /// The fallback that loaded in place of the address the current load
    /// asked for, nil until one does. Each load starts it at nil again.
    public func fallbacks() async -> AsyncStream<StreamFallback?> { fallbackCast.stream() }

    /// The engine playing the current address, nil before the first load.
    public var activeEngine: (any PlaybackEngine)? { active }

    /// The file type of the address playing, lowercased, such as "ts" once
    /// an HLS channel fell back. Nil before the first load.
    public private(set) var loadedExtension: String?

    public var state: PlaybackState {
        get async { await active?.state ?? .idle }
    }

    public var capabilities: EngineCapabilities {
        get async { await (active ?? system).capabilities }
    }

    /// Loads `url`. When `options` has a fallback and Apple's player fails
    /// before the stream first plays, by throwing or by reporting a failure
    /// after `load` returned, the fallback loads in its place with no failure
    /// reported in between, and `fallbacks()` names it once the fallback
    /// has loaded (playback-engine/a-source-whose-hls-failed-cannot-airplay).
    /// Being offline, a login not on this device and no free decoder are
    /// reported as they are, since the fallback would fail the same way.
    public func load(_ url: URL, options: PlaybackOptions) async throws {
        // play-on-apple-tv/the-phone-opens-no-stream-while-connected
        if let gate, !gate.admits() { throw CancellationError() }
        generation += 1
        let mine = generation
        wantsPlay = false
        pending = nil
        fellBackIn = nil
        if fallbackCast.value != nil { fallbackCast.send(nil) }
        var primary = options
        primary.fallback = nil
        let target = EngineRouter.route(for: url) == .system ? system : demuxer
        if let fallback = options.fallback, target === system {
            pending = Pending(fallback: fallback, options: primary, generation: mine)
        }
        loadedExtension = url.pathExtension.lowercased()
        do {
            try await open(url, on: target, options: primary, generation: mine)
        } catch let failure as PlaybackFailure where Self.fallsBack(failure) && pending?.generation == mine {
            try await loadFallback(generation: mine)
            return
        }
        guard generation == mine else { throw CancellationError() }
        if pending?.generation == mine { pending?.loaded = true }
    }

    /// Loads `url` on `target`, moving to the other engine when `target`
    /// hands the stream over.
    private func open(_ url: URL, on target: any PlaybackEngine, options: PlaybackOptions, generation mine: Int) async throws {
        let system = self.system
        await activate(target)
        guard generation == mine else { throw CancellationError() }
        do {
            try await target.load(url, options: options)
        } catch EngineHandoff.toSystemPlayer where target !== system {
            guard generation == mine else { throw CancellationError() }
            await activate(system)
            guard generation == mine else { throw CancellationError() }
            try await system.load(url, options: options)
        } catch EngineHandoff.toDemuxer where target === system && demuxer !== system {
            guard generation == mine else { throw CancellationError() }
            // The demuxer reads the stream itself, so the fallback is not needed.
            pending = nil
            let demuxer = self.demuxer
            await activate(demuxer)
            guard generation == mine else { throw CancellationError() }
            try await demuxer.load(url, options: options)
        }
        guard generation == mine else { throw CancellationError() }
    }

    /// Opens the pending fallback in place of the address that failed.
    private func loadFallback(generation mine: Int) async throws {
        guard generation == mine, let fallback = pending, fallback.generation == mine else { throw CancellationError() }
        pending = nil
        fellBackIn = mine
        let url = fallback.fallback.url
        loadedExtension = url.pathExtension.lowercased()
        let target = EngineRouter.route(for: url) == .system ? system : demuxer
        try await open(url, on: target, options: fallback.options, generation: mine)
        fallbackCast.send(fallback.fallback)
    }

    /// A failure Apple's player reported after `load` returned, before the
    /// stream played: the fallback loads, and plays when play was asked for.
    private func fallBackAfterLoad(generation mine: Int) async {
        do {
            try await loadFallback(generation: mine)
        } catch {
            // The engine that failed reports its own failure in its states.
            return
        }
        guard generation == mine, wantsPlay else { return }
        await active?.play()
    }

    /// True for the failures an MPEG-TS link of the same channel may not share.
    static func fallsBack(_ failure: PlaybackFailure) -> Bool {
        switch failure {
        case .offline, .loginNotOnDevice, .noDecoderFree: false
        default: true
        }
    }

    /// Whether a state from `engine` is kept back from the screen: a failure
    /// while a fallback waits is, and so is a late failure of the address the
    /// fallback replaced. Playing ends the wait.
    private func holdsBack(_ state: PlaybackState, from engine: any PlaybackEngine) async -> Bool {
        if fellBackIn == generation, case .failed = state {
            let mine = generation
            let current = await engine.state
            if generation == mine, current != state { return true }
        }
        guard let waiting = pending, waiting.generation == generation else { return false }
        switch state {
        case .playing:
            pending = nil
            return false
        case .failed(let failure) where Self.fallsBack(failure):
            if waiting.loaded {
                pending?.loaded = false
                let mine = generation
                Task { await self.fallBackAfterLoad(generation: mine) }
            }
            return true
        default:
            return false
        }
    }

    public func play() async {
        wantsPlay = true
        await active?.play()
    }

    public func pause() async {
        wantsPlay = false
        await active?.pause()
    }

    public func stop() async {
        generation += 1
        wantsPlay = false
        pending = nil
        fellBackIn = nil
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

    /// What `exchange(with:)` moves from one routed engine to the other.
    private struct Taken: Sendable {
        var pair: Pair
        var active: (any PlaybackEngine)?
        var loadedExtension: String?
    }

    private func detach() -> Taken {
        pumps.forEach { $0.cancel() }
        pumps = []
        // A fallback still waiting stays behind; the stream plays on as it is.
        pending = nil
        fellBackIn = nil
        let taken = Taken(pair: pair.withLock { $0 }, active: active, loadedExtension: loadedExtension)
        active = nil
        return taken
    }

    private func attach(_ taken: Taken) async {
        generation += 1
        pair.withLock { $0 = taken.pair }
        active = taken.active
        loadedExtension = taken.loadedExtension
        if let engine = taken.active {
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
            pumpStates(await engine.states(), from: engine),
            Self.pump(await engine.presentation(), into: presentationCast),
            Self.pump(await engine.tracks(), into: tracksCast),
            Self.pump(await engine.position(), into: positionCast),
            Self.pump(await engine.subtitleCues(), into: cuesCast),
            Self.pump(await engine.timeshift(), into: timeshiftCast),
        ]
    }

    /// Forwards states like `pump`, except those `holdsBack` keeps from the screen.
    private func pumpStates(_ stream: AsyncStream<PlaybackState>, from engine: any PlaybackEngine) -> Task<Void, Never> {
        let cast = stateCast
        return Task { [weak self] in
            for await value in stream {
                guard !Task.isCancelled, let self else { return }
                if await self.holdsBack(value, from: engine) { continue }
                guard !Task.isCancelled else { return }
                cast.send(value)
            }
        }
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
