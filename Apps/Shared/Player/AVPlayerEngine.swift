import AVFoundation
import AVKit
import AntennaCore
import Foundation
import os

/// Apple's player behind `PlaybackEngine`. It plays HLS and the files the
/// system can read. Until the demuxing engine exists it also stands behind
/// the demuxer route, so a raw MPEG-TS stream fails here as unreadable.
///
/// Before each open it probes the address once through the ephemeral
/// playback session, so refusals map to the same reasons the demuxer will
/// give, and HLS at a raw-looking address plays as HLS.
@MainActor
final class AVPlayerEngine: PlaybackEngine {
    /// What is open now.
    struct Stream: Sendable {
        var url: URL
        var options: PlaybackOptions
        var isLive: Bool
        /// False for a film whose server cannot skip.
        var canSeek: Bool
    }

    let player = AVPlayer()
    let session: URLSession
    let sleep: @Sendable (Duration) async throws -> Void
    let log: @Sendable (String) -> Void

    let stateCast = Broadcast(PlaybackState.idle)
    let presentationCast = Broadcast(PresentationInfo?.none)
    let tracksCast = Broadcast(TrackList.empty)
    let positionCast = Broadcast(PlaybackPosition.zero)
    let cuesCast = Broadcast([SubtitleCue]())

    /// The last address asked for, kept to start it again after a pause
    /// during loading or reconnecting, or after a film ended.
    var request: (url: URL, options: PlaybackOptions)?
    var stream: Stream?
    var generation = 0
    var wantsPlay = false
    var hasPlayed = false
    /// Play starts the stream again instead of resuming it.
    var reopensOnPlay = false
    var budget = ReconnectBudget()
    var reconnect: Task<Void, Never>?
    var opening: Task<Stream, any Error>?
    var stallWatch: Task<Void, Never>?
    var firstFrameWatch: Task<Void, Never>?
    var itemObservation: NSKeyValueObservation?
    var itemTokens: [any NSObjectProtocol] = []
    var playerObservation: NSKeyValueObservation?
    var timeObserver: Any?
    var pictureInPicture: AVPictureInPictureController?

    /// Data but no picture for this long fails the stream as unreadable.
    static let firstFrameTimeout = Duration.seconds(15)

    /// How long Apple's player takes to close the old connection after its
    /// item is removed. It closes it from another process, so the engine
    /// waits this long before it opens the next one. Measured at under 100 ms
    /// on a Mac.
    static let releaseGrace = Duration.milliseconds(200)

    /// A skip lands within this of its target.
    static let seekTolerance = CMTime(value: 1, timescale: 2)

    nonisolated static let logger = Logger(subsystem: "se.codecrave.antenna", category: "playback")

    /// `sleep` waits between retries and times the stall budget; tests pass
    /// a faster one. `log` gets every line the engine logs, each made only of
    /// the redacted address and a reason.
    init(
        session: URLSession = PlaybackNetwork.makeSession(),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        log: @escaping @Sendable (String) -> Void = { AVPlayerEngine.logger.info("\($0, privacy: .public)") }
    ) {
        self.session = session
        self.sleep = sleep
        self.log = log
        // Apple's player stores a stream server's cookies in the shared
        // storage even when it sends none, and a cookie can carry the token.
        // Nothing else in the app uses the shared storage.
        HTTPCookieStorage.shared.cookieAcceptPolicy = .never
        playerObservation = player.observe(\.timeControlStatus) { [weak self] _, _ in
            Task { @MainActor in self?.timeControlChanged() }
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 2), queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.publishPosition(onlyWhilePlaying: true) }
        }
    }

    /// The Apple player engine behind `engine`: the engine itself, or the
    /// system route of a `RoutedEngine`.
    static func resolve(_ engine: any PlaybackEngine) -> AVPlayerEngine? {
        (engine as? AVPlayerEngine) ?? ((engine as? RoutedEngine)?.system as? AVPlayerEngine)
    }

    /// Draws this engine's picture into `layer`, and on iPhone, iPad and
    /// Apple TV lets it continue in Picture in Picture.
    func attach(to layer: AVPlayerLayer) {
        if layer.player !== player { layer.player = player }
        #if os(iOS) || os(tvOS)
            guard AVPictureInPictureController.isPictureInPictureSupported(), pictureInPicture?.playerLayer !== layer else { return }
            let controller = AVPictureInPictureController(playerLayer: layer)
            #if os(iOS)
                controller?.canStartPictureInPictureAutomaticallyFromInline = true
            #endif
            controller?.requiresLinearPlayback = stream?.isLive ?? true
            pictureInPicture = controller
        #endif
    }

    /// True while the picture plays, or can go on playing, in the Picture in
    /// Picture window once the app leaves the screen.
    var continuesInPictureInPicture: Bool {
        guard let pictureInPicture else { return false }
        return pictureInPicture.isPictureInPictureActive || pictureInPicture.isPictureInPicturePossible
    }

    var state: PlaybackState { stateCast.value }

    var capabilities: EngineCapabilities {
        #if os(iOS) || os(tvOS)
            EngineCapabilities(supportsPictureInPicture: AVPictureInPictureController.isPictureInPictureSupported())
        #else
            EngineCapabilities(supportsPictureInPicture: false)
        #endif
    }

    // MARK: Load and stop

    func load(_ url: URL, options: PlaybackOptions) async throws {
        generation += 1
        let mine = generation
        let hadItem = player.currentItem != nil
        closeStream()
        request = (url, options)
        stream = nil
        wantsPlay = false
        hasPlayed = false
        reopensOnPlay = false
        budget = ReconnectBudget()
        set(.loading)
        log("load \(redacted(url))")
        do {
            try StreamAddress.check(url)
        } catch {
            log("failed \(redacted(url)) \(PlaybackFailure.unreadable)")
            set(.failed(.unreadable))
            throw PlaybackFailure.unreadable
        }
        let task = Task { [weak self, sleep] in
            if hadItem { try await Task.sleep(for: Self.releaseGrace) }
            return try await RetryPolicy.tune.run(sleep: sleep) { [weak self] in
                guard let self else { throw CancellationError() }
                return try await self.open(url, options: options, startAt: options.startPosition, generation: mine)
            }
        }
        opening = task
        do {
            let opened = try await task.value
            guard generation == mine else { throw CancellationError() }
            opening = nil
            stream = opened
            if wantsPlay { startPlayback() }
        } catch let failure as PlaybackFailure {
            guard generation == mine else { throw CancellationError() }
            log("failed \(redacted(url)) \(failure)")
            closeStream()
            set(.failed(failure))
            throw failure
        } catch {
            guard generation == mine else { throw CancellationError() }
            throw error
        }
    }

    func stop() async {
        generation += 1
        closeStream()
        request = nil
        stream = nil
        wantsPlay = false
        hasPlayed = false
        reopensOnPlay = false
        set(.idle)
    }

    // MARK: Play and pause

    func play() async {
        switch state {
        case .loading:
            wantsPlay = true
            if stream != nil { startPlayback() }
        case .paused where reopensOnPlay, .ended:
            await startAgain()
        case .paused:
            wantsPlay = true
            if let stream, stream.isLive, let edge = player.currentItem?.seekableTimeRanges.last?.timeRangeValue.end {
                // Live TV continues from what is on air now.
                await player.currentItem?.seek(to: edge, toleranceBefore: .positiveInfinity, toleranceAfter: .zero)
            }
            player.play()
        case .idle, .playing, .buffering, .reconnecting, .failed:
            return
        }
    }

    func pause() async {
        switch state {
        case .loading, .reconnecting:
            // Stops the attempts; play starts the stream again.
            generation += 1
            closeStream()
            stream = nil
            wantsPlay = false
            reopensOnPlay = true
            set(.paused)
        case .playing, .buffering:
            wantsPlay = false
            stallWatch?.cancel()
            player.pause()
            reopensOnPlay = stream.map { !$0.isLive && !$0.canSeek } ?? false
            set(.paused)
            publishPosition(onlyWhilePlaying: false)
        case .idle, .paused, .ended, .failed:
            return
        }
    }

    /// Loads the last address again from its start and plays it.
    func startAgain() async {
        guard let request else { return }
        var options = request.options
        if state == .ended { options.startPosition = nil }
        do {
            try await load(request.url, options: options)
        } catch {
            return
        }
        await play()
    }

    // MARK: Seek

    func seek(to time: Duration) async throws {
        guard let stream, let item = player.currentItem else { throw SeekRefusal.notSeekable }
        guard !stream.isLive else { throw SeekRefusal.live }
        guard stream.canSeek, !item.seekableTimeRanges.isEmpty else { throw SeekRefusal.notSeekable }
        let target = CMTime(seconds: time.seconds, preferredTimescale: 600)
        if item.duration.isNumeric, target >= item.duration {
            finish()
            return
        }
        await item.seek(to: target, toleranceBefore: Self.seekTolerance, toleranceAfter: Self.seekTolerance)
        publishPosition(onlyWhilePlaying: false)
    }

    // MARK: Tracks

    func selectAudio(_ id: MediaTrack.ID) async {}
    func selectSubtitle(_ id: MediaTrack.ID?) async {}

    // MARK: Streams

    func states() async -> AsyncStream<PlaybackState> { stateCast.stream() }
    func presentation() async -> AsyncStream<PresentationInfo?> { presentationCast.stream() }
    func tracks() async -> AsyncStream<TrackList> { tracksCast.stream() }
    func position() async -> AsyncStream<PlaybackPosition> { positionCast.stream() }
    func subtitleCues() async -> AsyncStream<[SubtitleCue]> { cuesCast.stream() }
}

extension Duration {
    /// This duration in seconds, with its fraction.
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
