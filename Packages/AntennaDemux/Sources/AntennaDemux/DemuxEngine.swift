@preconcurrency import AVFoundation
import AntennaCore

#if os(iOS) || os(tvOS)
    import AVKit
#endif
import CoreMedia
import Foundation
import os

/// The FFmpeg path behind `PlaybackEngine`: raw broadcast streams, Matroska
/// and AVI. FFmpeg demuxes; Apple's sample-buffer renderers decode in
/// hardware and play under one synchronizer clock.
///
/// The picture is drawn into `videoLayer`. Switching, reconnecting and
/// pausing live TV flush the renderers without removing the last image, so
/// the old picture stays until the next first frame. The layer is hidden
/// until the first stream starts and after `stop`, which also removes the
/// image, so it never covers Apple's player when `RoutedEngine` switches to it.
///
/// A stream that played and then drops (its bytes end, fail, or stop for
/// `RetryPolicy.stallBudget`) reconnects under `ReconnectBudget`. Pausing
/// live TV lets the provider's connection go; play opens the channel again
/// at what is on air now. An address that turns out to serve HLS throws
/// `EngineHandoff.toSystemPlayer` for `RoutedEngine` to hand over.
@MainActor
public final class DemuxEngine: PlaybackEngine {
    /// Draws the picture. Screens put it in their view hierarchy.
    public let videoLayer = AVSampleBufferDisplayLayer()
    let audioRenderer = AVSampleBufferAudioRenderer()
    let synchronizer = AVSampleBufferRenderSynchronizer()

    let session: URLSession
    private let sleep: @Sendable (Duration) async throws -> Void
    let log: @Sendable (String) -> Void
    private let firstFrameTimeout: Duration

    let stateCast = Broadcast(PlaybackState.idle)
    let presentationCast = Broadcast(PresentationInfo?.none)
    let tracksCast = Broadcast(TrackList.empty)
    private let positionCast = Broadcast(PlaybackPosition.zero)
    let cuesCast = Broadcast([SubtitleCue]())

    /// The TV's mode on Apple TV, shared with Apple's player engine.
    public let display: DisplayMatcher
    /// The last picture held over a switch to or from Apple's player,
    /// shared with that engine. Screens put its layer above both.
    public let hold: FrameHold

    /// Whether the audio renderer runs the clock; false after it stalled.
    var audioOnClock = true
    /// The clock's last reading and since when it has stood there.
    var clockCheck: (time: CMTime, since: ContinuousClock.Instant)?

    struct Current {
        let run: DemuxRun
        let videoFeed: SampleFeed
        let audioFeed: SampleFeed
        var start: DemuxStart?
        /// Set when the bytes ran out: nil for a normal end, or why they stopped.
        var bytesEnded: PlaybackFailure??
        /// When the renderers ran out of buffered media, if they have.
        var starvedSince: ContinuousClock.Instant?
        /// Subtitle lines of every text stream not yet over.
        var cues: [TimedCue] = []
        /// Picture changes demuxed ahead of the clock.
        var pictureChanges: [PictureChange] = []
    }

    var request: (url: URL, options: PlaybackOptions)?
    var current: Current?
    /// A frame rate the run found before `open` stored its start.
    var earlyFrameRate: Double?

    /// True while the user scans through channels; see `setScanning(_:)`.
    public internal(set) var isScanning = false
    /// The connection of a load still waiting for its response.
    private var connecting: Task<HTTPByteStream, any Error>?
    private var reconnect: Task<Void, Never>?
    /// Streams kept open ahead of a zap, by address.
    var standby: [URL: Task<HTTPByteStream, any Error>] = [:]
    var generation = 0
    var wantsPlay = false
    private var hasPlayed = false
    /// Play opens the stream again instead of resuming it.
    var reopensOnPlay = false
    var isLive = true
    var budget = ReconnectBudget()
    private var ticker: Task<Void, Never>?

    #if os(iOS) || os(tvOS)
        var pictureInPicture: AVPictureInPictureController?
        var pictureInPicturePlayback: PictureInPicturePlayback?
    #endif

    /// Frames waiting ahead of the video renderer.
    static let videoLimit = 120
    /// Sound buffers waiting ahead of the audio renderer.
    static let audioLimit = 240
    /// Bytes a stream opened ahead keeps: enough for a keyframe at
    /// broadcast bitrates.
    static let standbyWindow = 4 * 1024 * 1024

    public nonisolated static let logger = Logger(subsystem: "se.codecrave.antenna", category: "playback")

    /// A stream that sends data but no picture for this long fails as
    /// unreadable.
    public static let firstFrameTimeout = Duration.seconds(15)

    /// `sleep` waits between retries and reconnects and times the stall
    /// budget; tests pass a faster one, and a shorter `firstFrameTimeout`.
    /// `log` gets every line the engine logs, made only of the redacted
    /// address and a reason. `display` and `hold` are shared with Apple's
    /// player engine when both play into one screen.
    public init(
        session: URLSession = PlaybackNetwork.makeSession(),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        firstFrameTimeout: Duration = DemuxEngine.firstFrameTimeout,
        display: DisplayMatcher = DisplayMatcher(),
        hold: FrameHold = FrameHold(),
        log: @escaping @Sendable (String) -> Void = { DemuxEngine.logger.info("\($0, privacy: .public)") }
    ) {
        self.display = display
        self.hold = hold
        self.session = session
        self.sleep = sleep
        self.firstFrameTimeout = firstFrameTimeout
        self.log = log
        synchronizer.addRenderer(videoLayer.sampleBufferRenderer)
        synchronizer.addRenderer(audioRenderer)
        videoLayer.videoGravity = .resizeAspect
        videoLayer.isHidden = true
    }

    /// The demuxing engine behind `engine`: the engine itself, or the
    /// demuxer route of a `RoutedEngine`.
    public static func resolve(_ engine: any PlaybackEngine) -> DemuxEngine? {
        (engine as? DemuxEngine) ?? ((engine as? RoutedEngine)?.demuxer as? DemuxEngine)
    }

    public var state: PlaybackState { stateCast.value }

    public var capabilities: EngineCapabilities {
        #if os(iOS) || os(tvOS)
            EngineCapabilities(supportsPictureInPicture: AVPictureInPictureController.isPictureInPictureSupported())
        #else
            EngineCapabilities(supportsPictureInPicture: false)
        #endif
    }

    // MARK: Load and stop

    public func load(_ url: URL, options: PlaybackOptions) async throws {
        generation += 1
        let mine = generation
        close()
        request = (url, options)
        wantsPlay = false
        hasPlayed = false
        reopensOnPlay = false
        budget = ReconnectBudget()
        set(.loading)
        do {
            try StreamAddress.check(url)
            try await open(url, options: options, generation: mine)
            log("demux load \(redacted(url)) ready")
        } catch let failure as PlaybackFailure {
            log("demux load \(redacted(url)) failed: \(failure)")
            guard generation == mine else { throw CancellationError() }
            close()
            set(.failed(failure))
            throw failure
        } catch EngineHandoff.toSystemPlayer {
            guard generation == mine else { throw CancellationError() }
            close()
            set(.idle)
            throw EngineHandoff.toSystemPlayer
        } catch {
            guard generation == mine else { throw CancellationError() }
            throw error
        }
    }

    /// Connects with the tune retry policy, or takes the stream kept open
    /// ahead for `url`, and starts a run, returning once its first frame is
    /// queued. Throws `CancellationError` when a newer load, stop or pause
    /// replaced it.
    func open(_ url: URL, options: PlaybackOptions, generation mine: Int) async throws {
        let session = self.session
        let sleep = self.sleep
        let ahead = standby.removeValue(forKey: url)
        let connect = Task {
            if let ahead, let bytes = try? await ahead.value {
                bytes.standbyWindow = nil
                return bytes
            }
            return try await RetryPolicy.tune.run(sleep: sleep) {
                let bytes = HTTPByteStream(url: url, session: session)
                try await bytes.open()
                return bytes
            }
        }
        connecting = connect
        let bytes = try await withTaskCancellationHandler {
            try await connect.value
        } onCancel: {
            connect.cancel()
        }
        if generation == mine { connecting = nil }
        guard generation == mine else {
            bytes.cancel()
            throw CancellationError()
        }
        let videoFeed = SampleFeed(renderer: videoLayer.sampleBufferRenderer, label: "video", limit: Self.videoLimit)
        let audioFeed = SampleFeed(renderer: audioRenderer, label: "audio", limit: Self.audioLimit)
        let source = SeekableSource(bytes, url: url, session: session)
        let run = DemuxRun(bytes: source, videoFeed: videoFeed, audioFeed: audioFeed)
        listen(to: run, url: url, generation: mine)
        current = Current(run: run, videoFeed: videoFeed, audioFeed: audioFeed)
        videoFeed.start()
        audioFeed.start()
        let startAt = options.startPosition.map { CMTime(seconds: $0.inSeconds, preferredTimescale: 90000) }
        let timeout = firstFrameTimeout
        let watchdog = Task {
            try await Task.sleep(for: timeout)
            run.giveUp(.unreadable)
        }
        defer { watchdog.cancel() }
        var start: DemuxStart = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                run.start(
                    ready: { result in continuation.resume(with: result) },
                    rateFound: { [weak self] rate in
                        Task { @MainActor in self?.frameRateFound(rate, generation: mine) }
                    },
                    waitsForSound: !isScanning,
                    startAt: startAt,
                    options: options,
                    ended: { [weak self] failure in
                        Task { @MainActor in self?.bytesEnded(failure, generation: mine) }
                    })
            }
        } onCancel: {
            run.cancel()
        }
        guard generation == mine else { throw CancellationError() }
        if start.frameRate == nil, let rate = earlyFrameRate { start.frameRate = rate }
        earlyFrameRate = nil
        current?.start = start
        isLive = options.isLive ?? (start.duration == nil)
        videoLayer.isHidden = start.video == nil
        restoreAudioClock()
        synchronizer.setRate(wantsPlay ? 1 : 0, time: start.startTime)
        if !isScanning {
            publishFormat(start)
            matchDisplay(start)
        }
        startTicker()
        // The synchronizer reports the new time a moment after setRate, so
        // the first position comes from the start itself.
        publishPosition(at: start.startTime)
    }

    /// Lets the stream that plays now go: its connection closes and the
    /// renderers are flushed, keeping the last picture and the format.
    func release() {
        connecting?.cancel()
        connecting = nil
        reconnect?.cancel()
        reconnect = nil
        ticker?.cancel()
        ticker = nil
        // Stop feeding and flush before stopping the clock: setting the rate
        // while the renderers still take buffers blocked for seconds.
        current?.run.cancel()
        current = nil
        earlyFrameRate = nil
        synchronizer.rate = 0
    }

    /// Releases the stream and clears what was reported about it.
    func close() {
        release()
        presentationCast.send(nil)
        tracksCast.send(.empty)
        positionCast.send(.zero)
        cuesCast.send([])
    }

    // MARK: Play and pause

    public func play() async {
        switch state {
        case .paused where reopensOnPlay:
            await startAgain()
        case .ended:
            await startAgain(fromStart: true)
        case .loading, .paused, .buffering:
            guard current?.start != nil else { return }
            wantsPlay = true
            synchronizer.rate = 1
        case .idle, .playing, .reconnecting, .failed:
            return
        }
    }

    public func pause() async {
        switch state {
        case .loading, .reconnecting:
            // Stops the attempts; play starts the stream again.
            generation += 1
            wantsPlay = false
            release()
            reopensOnPlay = true
            set(.paused)
        case .playing, .buffering:
            wantsPlay = false
            synchronizer.rate = 0
            publishPosition()
            if isLive || current?.start?.canSeek == false {
                // Live TV lets the provider's connections go; play opens
                // what is on air then. A film that cannot skip starts again.
                generation += 1
                openAhead([])
                release()
                reopensOnPlay = true
            }
            set(.paused)
        case .idle, .paused, .ended, .failed:
            return
        }
    }

    /// Opens the last address again and plays it, as after pausing live TV
    /// or a load or reconnect.
    func startAgain(fromStart: Bool = false) async {
        guard let request else { return }
        generation += 1
        let mine = generation
        reopensOnPlay = false
        wantsPlay = true
        budget = ReconnectBudget()
        set(.loading)
        do {
            var options = request.options
            if fromStart { options.startPosition = nil }
            try await open(request.url, options: options, generation: mine)
        } catch let failure as PlaybackFailure {
            guard generation == mine else { return }
            close()
            set(.failed(failure))
        } catch {
            return
        }
    }

    // MARK: Streams

    public func states() async -> AsyncStream<PlaybackState> { stateCast.stream() }
    public func presentation() async -> AsyncStream<PresentationInfo?> { presentationCast.stream() }
    public func tracks() async -> AsyncStream<TrackList> { tracksCast.stream() }
    public func position() async -> AsyncStream<PlaybackPosition> { positionCast.stream() }
    public func subtitleCues() async -> AsyncStream<[SubtitleCue]> { cuesCast.stream() }

}

extension DemuxEngine {
    // MARK: Drops and reconnects

    /// The bytes ran out. What was queued plays out first; `tick` then ends
    /// the film or treats the live stream as dropped.
    private func bytesEnded(_ failure: PlaybackFailure?, generation mine: Int) {
        guard generation == mine, current != nil else { return }
        current?.bytesEnded = .some(failure)
    }

    /// A stream that played lost its data: reconnect after the budget's
    /// wait, or fail with `failure` once the budget says so.
    private func dropped(_ failure: PlaybackFailure) {
        guard hasPlayed, let request, let next = budget.dropped(failure, at: .now) else {
            close()
            set(.failed(failure))
            return
        }
        log("demux reconnect \(next.attempt)/\(budget.maxAttempts) \(redacted(request.url)) \(failure)")
        generation += 1
        let mine = generation
        release()
        set(.reconnecting(attempt: next.attempt, of: budget.maxAttempts))
        let sleep = self.sleep
        reconnect = Task { [weak self] in
            do {
                try await sleep(next.delay)
            } catch {
                return
            }
            await self?.reopen(generation: mine)
        }
    }

    private func reopen(generation mine: Int) async {
        guard generation == mine, let request else { return }
        do {
            try await open(request.url, options: request.options, generation: mine)
        } catch let failure as PlaybackFailure {
            guard generation == mine else { return }
            dropped(failure)
        } catch {
            return
        }
    }

    // MARK: Reporting

    /// Reports where playback is: at `time` on the stream's clock, or now.
    func publishPosition(at time: CMTime? = nil) {
        guard let current, let start = current.start else { return }
        let elapsed = CMTimeSubtract(time ?? synchronizer.currentTime(), start.origin)
        guard elapsed.isNumeric else { return }
        let duration = start.duration.map { Duration.seconds($0.seconds) }
        positionCast.send(PlaybackPosition(time: .seconds(max(0, elapsed.seconds)), duration: duration, isLive: isLive))
    }

    /// Four times a second while a stream is open.
    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    /// Marks playing once the first frame's time is reached, reports the
    /// position, waits out a short stall as buffering, and handles the end:
    /// a film ends once its last frame has played, and a live stream whose
    /// data stopped counts as dropped.
    private func tick() {
        guard var current, let start = current.start else { return }
        watchClock(synchronizer.currentTime())
        let now = synchronizer.currentTime()
        publishCues(at: now)
        let last = current.videoFeed.lastEnqueued.isValid ? current.videoFeed.lastEnqueued : current.audioFeed.lastEnqueued
        let starved = last.isValid && now >= last
        switch state {
        case .loading, .reconnecting, .buffering:
            // The clock moved past the first frame: it is on screen and
            // time runs, which a stalled audio output would not let happen.
            if wantsPlay, synchronizer.rate > 0, now > start.startTime, !starved {
                current.starvedSince = nil
                self.current = current
                hasPlayed = true
                budget.playing(at: .now)
                set(.playing)
            }
        case .playing:
            publishPosition()
            applyPictureChanges(at: now)
            guard starved else { break }
            if let ending = current.bytesEnded {
                if !isLive, ending == nil {
                    synchronizer.rate = 0
                    set(.ended)
                } else {
                    dropped(ending ?? .stoppedSendingData)
                }
                return
            }
            current.starvedSince = .now
            self.current = current
            set(.buffering)
        default:
            break
        }
        if state == .buffering, let since = current.starvedSince, ContinuousClock.now - since >= RetryPolicy.stallBudget {
            dropped(current.bytesEnded.flatMap { $0 } ?? .stoppedSendingData)
        }
    }
}
