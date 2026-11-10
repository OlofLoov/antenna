@preconcurrency import AVFoundation
import AntennaCore
import CoreMedia
import Foundation
import os

/// The FFmpeg path behind `PlaybackEngine`: raw broadcast streams, Matroska
/// and AVI. FFmpeg demuxes; Apple's sample-buffer renderers decode in
/// hardware and play under one synchronizer clock.
///
/// The picture is drawn into `videoLayer`. Switching flushes the renderers
/// without removing the last image, so the old picture stays until the next
/// channel's first frame. The layer is hidden until the first stream starts
/// and after `stop`, which also removes the image, so it never covers Apple's
/// player when `RoutedEngine` switches to it.
@MainActor
public final class DemuxEngine: PlaybackEngine {
    /// Draws the picture. Screens put it in their view hierarchy.
    public let videoLayer = AVSampleBufferDisplayLayer()
    let audioRenderer = AVSampleBufferAudioRenderer()
    let synchronizer = AVSampleBufferRenderSynchronizer()

    private let session: URLSession
    private let sleep: @Sendable (Duration) async throws -> Void
    private let log: @Sendable (String) -> Void

    private let stateCast = Broadcast(PlaybackState.idle)
    private let presentationCast = Broadcast(PresentationInfo?.none)
    private let tracksCast = Broadcast(TrackList.empty)
    private let positionCast = Broadcast(PlaybackPosition.zero)
    private let cuesCast = Broadcast([SubtitleCue]())

    private struct Current {
        let run: DemuxRun
        let videoFeed: SampleFeed
        var start: DemuxStart?
        var isLive: Bool { start?.duration == nil }
        /// Set when the bytes ran out: nil for a normal end, or why they stopped.
        var bytesEnded: PlaybackFailure??
    }

    private var current: Current?
    /// The connection of a load still waiting for its response.
    private var connecting: Task<HTTPByteStream, any Error>?
    private var generation = 0
    private var wantsPlay = false
    private var ticker: Task<Void, Never>?

    /// Frames waiting ahead of the video renderer.
    static let videoLimit = 120
    /// Sound buffers waiting ahead of the audio renderer.
    static let audioLimit = 240

    public nonisolated static let logger = Logger(subsystem: "se.codecrave.antenna", category: "playback")

    /// `sleep` waits between tune retries; tests pass a faster one. `log`
    /// gets every line the engine logs, made only of the redacted address
    /// and a reason.
    public init(
        session: URLSession = PlaybackNetwork.makeSession(),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        log: @escaping @Sendable (String) -> Void = { DemuxEngine.logger.info("\($0, privacy: .public)") }
    ) {
        self.session = session
        self.sleep = sleep
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

    public var capabilities: EngineCapabilities { EngineCapabilities(supportsPictureInPicture: false) }

    // MARK: Load and stop

    public func load(_ url: URL, options: PlaybackOptions) async throws {
        generation += 1
        let mine = generation
        close()
        wantsPlay = false
        set(.loading)
        do {
            try StreamAddress.check(url)
            let session = self.session
            let sleep = self.sleep
            let connect = Task {
                try await RetryPolicy.tune.run(sleep: sleep) {
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
            try await begin(bytes, generation: mine)
            log("demux load \(redacted(url)) ready")
        } catch let failure as PlaybackFailure {
            log("demux load \(redacted(url)) failed: \(failure)")
            guard generation == mine else { throw CancellationError() }
            close()
            set(.failed(failure))
            throw failure
        } catch {
            guard generation == mine else { throw CancellationError() }
            throw error
        }
    }

    public func stop() async {
        generation += 1
        wantsPlay = false
        close()
        videoLayer.isHidden = true
        set(.idle)
        await videoLayer.sampleBufferRenderer.flush(removingDisplayedImage: true)
    }

    /// Starts a run on `bytes` and returns once its first frame is queued.
    private func begin(_ bytes: HTTPByteStream, generation mine: Int) async throws {
        let videoFeed = SampleFeed(renderer: videoLayer.sampleBufferRenderer, label: "video", limit: Self.videoLimit)
        let audioFeed = SampleFeed(renderer: audioRenderer, label: "audio", limit: Self.audioLimit)
        let run = DemuxRun(bytes: bytes, videoFeed: videoFeed, audioFeed: audioFeed)
        current = Current(run: run, videoFeed: videoFeed)
        videoFeed.start()
        audioFeed.start()
        let start: DemuxStart = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                run.start(
                    ready: { result in continuation.resume(with: result) },
                    ended: { [weak self] failure in
                        Task { @MainActor in self?.bytesEnded(failure, generation: mine) }
                    })
            }
        } onCancel: {
            run.cancel()
        }
        guard generation == mine else { throw CancellationError() }
        current?.start = start
        videoLayer.isHidden = start.video == nil
        synchronizer.setRate(0, time: start.startTime)
        publishFormat(start)
        startTicker()
    }

    /// Closes the stream that plays now. The renderers are flushed but keep
    /// the last picture.
    private func close() {
        connecting?.cancel()
        connecting = nil
        ticker?.cancel()
        ticker = nil
        synchronizer.rate = 0
        current?.run.cancel()
        current = nil
        presentationCast.send(nil)
        tracksCast.send(.empty)
        positionCast.send(.zero)
        cuesCast.send([])
    }

    // MARK: Play and pause

    public func play() async {
        guard let current, current.start != nil else { return }
        switch state {
        case .loading, .paused, .buffering:
            wantsPlay = true
            synchronizer.rate = 1
        case .idle, .playing, .reconnecting, .ended, .failed:
            return
        }
    }

    public func pause() async {
        switch state {
        case .loading, .playing, .buffering:
            wantsPlay = false
            synchronizer.rate = 0
            set(.paused)
            publishPosition()
        case .idle, .paused, .reconnecting, .ended, .failed:
            return
        }
    }

    public func seek(to time: Duration) async throws {
        throw (current?.isLive ?? true) ? SeekRefusal.live : SeekRefusal.notSeekable
    }

    public func selectAudio(_ id: MediaTrack.ID) async {}
    public func selectSubtitle(_ id: MediaTrack.ID?) async {}

    // MARK: Streams

    public func states() async -> AsyncStream<PlaybackState> { stateCast.stream() }
    public func presentation() async -> AsyncStream<PresentationInfo?> { presentationCast.stream() }
    public func tracks() async -> AsyncStream<TrackList> { tracksCast.stream() }
    public func position() async -> AsyncStream<PlaybackPosition> { positionCast.stream() }
    public func subtitleCues() async -> AsyncStream<[SubtitleCue]> { cuesCast.stream() }

    // MARK: Reporting

    private func set(_ new: PlaybackState) {
        stateCast.sendIfChanged(new)
    }

    private func publishFormat(_ start: DemuxStart) {
        let size = start.pictureSize
        let video = start.video.map {
            PresentationInfo.Video(
                width: size.map { Int($0.width) } ?? $0.width, height: size.map { Int($0.height) } ?? $0.height,
                frameRate: $0.frameRate, dynamicRange: .sdr, codec: $0.codec)
        }
        let audio = start.audio.map { PresentationInfo.Audio(codec: $0.codec, channels: start.soundChannels, isDecodable: true) }
        presentationCast.send(PresentationInfo(video: video, audio: audio))
        let audioStreams = start.streams.filter { $0.kind == .audio }
        let sounds = zip(audioStreams.indices, audioStreams).map { number, stream in
            MediaTrack(id: "audio-\(number)", kind: .audio, languageCode: stream.language, name: nil, isDefault: stream.isDefault)
        }
        let chosen = start.audio.flatMap { audio in audioStreams.firstIndex(of: audio) }
        tracksCast.send(TrackList(audio: sounds, subtitles: [], selectedAudio: chosen.map { sounds[$0].id }, selectedSubtitle: nil))
    }

    private func publishPosition() {
        guard let current, let start = current.start else { return }
        let elapsed = CMTimeSubtract(synchronizer.currentTime(), start.startTime)
        guard elapsed.isNumeric else { return }
        let duration = start.duration.map { Duration.seconds($0.seconds) }
        positionCast.send(PlaybackPosition(time: .seconds(max(0, elapsed.seconds)), duration: duration, isLive: current.isLive))
    }

    /// Four times a second: marks playing once the first frame's time is
    /// reached, reports the position, and ends a film whose last frame
    /// has played.
    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func tick() {
        guard let current, let start = current.start else { return }
        let now = synchronizer.currentTime()
        if wantsPlay, state == .loading || state == .paused || state == .buffering, synchronizer.rate > 0, now >= start.startTime {
            set(.playing)
        }
        if state == .playing {
            publishPosition()
            // The bytes ran out and what was queued has played: a film has
            // ended, and a live stream has stopped sending.
            let last = current.videoFeed.lastEnqueued
            if let ending = current.bytesEnded, !last.isValid || now >= last {
                if !current.isLive, ending == nil {
                    synchronizer.rate = 0
                    set(.ended)
                } else {
                    close()
                    set(.failed(ending ?? .stoppedSendingData))
                }
            }
        }
    }

    /// The bytes ran out. What was queued plays out first; `tick` then ends
    /// the film or fails the live stream.
    private func bytesEnded(_ failure: PlaybackFailure?, generation mine: Int) {
        guard generation == mine, current != nil else { return }
        current?.bytesEnded = .some(failure)
    }
}
