import AntennaCore
import CoreMedia
import Foundation

/// What a run found once its first picture (or, for radio, its first
/// sound) is queued for the renderers.
struct DemuxStart: Sendable {
    let format: String
    let streams: [DemuxedStream]
    let video: DemuxedStream?
    let audio: DemuxedStream?
    /// The presentation time playback starts at: the first video keyframe,
    /// or the first sound for radio.
    let startTime: CMTime
    /// Nil for live streams.
    let duration: CMTime?
    /// The picture size from the first keyframe, nil without a picture.
    let pictureSize: CMVideoDimensions?
    /// Channel count from the first sound, 0 without sound.
    let soundChannels: Int
}

/// One stream from open to end on its own thread: FFmpeg demuxes the bytes,
/// `SampleBuilder` makes sample buffers and the feeds take them. Video
/// before the first keyframe and sound before the first picture are
/// dropped, so playback starts on a whole frame.
final class DemuxRun: @unchecked Sendable {
    private let bytes: HTTPByteStream
    private let videoFeed: SampleFeed
    private let audioFeed: SampleFeed
    private let lock = NSLock()
    private var cancelled = false
    private var answer: Once<Result<DemuxStart, any Error>>?

    init(bytes: HTTPByteStream, videoFeed: SampleFeed, audioFeed: SampleFeed) {
        self.bytes = bytes
        self.videoFeed = videoFeed
        self.audioFeed = audioFeed
    }

    private var isCancelled: Bool {
        lock.withLock { cancelled }
    }

    /// Fails the start with `failure` if it has not happened yet, and stops
    /// reading. Used when no picture arrives in time.
    func giveUp(_ failure: PlaybackFailure) {
        let answer = lock.withLock { self.answer }
        answer?.call(.failure(failure))
        cancel()
    }

    /// Stops reading. The connection closes and the thread ends quietly.
    func cancel() {
        lock.withLock { cancelled = true }
        bytes.cancel()
        videoFeed.close()
        audioFeed.close()
    }

    /// Starts the thread. `ready` is called exactly once: with the start,
    /// the `PlaybackFailure` that stops the stream from playing, or
    /// `CancellationError` when `cancel` came first. `ended` is called when a
    /// stream that started stops, with nil when the bytes ran out normally.
    func start(
        ready: @escaping @Sendable (Result<DemuxStart, any Error>) -> Void,
        ended: @escaping @Sendable (PlaybackFailure?) -> Void
    ) {
        let answer = Once(ready)
        lock.withLock { self.answer = answer }
        let thread = Thread { [self] in
            run(ready: answer.call, ended: ended)
            answer.call(.failure(CancellationError()))
        }
        thread.name = "se.codecrave.antenna.demux"
        thread.qualityOfService = .userInitiated
        thread.start()
    }

    /// FFmpeg open on the stream, with a builder for the first video and
    /// the first audio stream it can build buffers for.
    private struct Prepared {
        let demuxer: Demuxer
        let video: SampleBuilder?
        let audio: SampleBuilder?
    }

    private func run(
        ready: @escaping @Sendable (Result<DemuxStart, any Error>) -> Void,
        ended: @escaping @Sendable (PlaybackFailure?) -> Void
    ) {
        let prepared: Prepared
        switch prepare() {
        case .success(let value):
            prepared = value
        case .failure(let error):
            if !isCancelled { ready(.failure(error)) }
            return
        }
        defer { prepared.demuxer.close() }
        let announced = pump(prepared, ready: ready)
        guard !isCancelled else { return }
        if announced {
            ended(bytes.failureReason)
        } else {
            ready(.failure(bytes.failureReason ?? PlaybackFailure.unreadable))
        }
    }

    /// Looks at the first bytes, opens FFmpeg and picks the streams. HLS at
    /// a raw-looking address goes to Apple's player; a web page is not a
    /// stream.
    private func prepare() -> Result<Prepared, any Error> {
        let bytes = self.bytes
        switch StreamSniff(bytes.peek(512)) {
        case .hls: return .failure(EngineHandoff.toSystemPlayer)
        case .html: return .failure(PlaybackFailure.unreadable)
        case .mpegTS, .other: break
        }
        let demuxer: Demuxer
        do {
            demuxer = try Demuxer(read: { bytes.read(into: $0, count: $1) })
        } catch {
            return .failure(bytes.failureReason ?? PlaybackFailure.unreadable)
        }
        let video = demuxer.streams.first { $0.kind == .video }
        let audio = demuxer.streams.first { $0.kind == .audio }
        guard let videoBuilder = Result(catching: { try video.map(SampleBuilder.init) }).success else {
            demuxer.close()
            return .failure(PlaybackFailure.cannotDecode(codec: video?.codec ?? "video"))
        }
        let audioBuilder = audio.flatMap { try? SampleBuilder(stream: $0) }
        guard videoBuilder != nil || audioBuilder != nil else {
            demuxer.close()
            return .failure(audio.map { PlaybackFailure.cannotDecode(codec: $0.codec) } ?? PlaybackFailure.unreadable)
        }
        return .success(Prepared(demuxer: demuxer, video: videoBuilder, audio: audioBuilder))
    }

    /// Reads packets into the feeds until the end or `cancel`, calling
    /// `ready` once the first picture (and, within half a second of stream,
    /// the first sound) is queued. Returns whether it did.
    private func pump(_ prepared: Prepared, ready: @Sendable (Result<DemuxStart, any Error>) -> Void) -> Bool {
        var startTime: CMTime?
        var heldSound: [CMSampleBuffer] = []
        var announced = false
        while !isCancelled, let packet = prepared.demuxer.nextPacket() {
            if packet.streamIndex == prepared.video?.stream.index, let builder = prepared.video {
                if startTime == nil, !packet.isKeyframe { continue }
                guard let buffer = try? builder.sampleBuffer(for: packet) else { continue }
                if startTime == nil {
                    let first = CMSampleBufferGetPresentationTimeStamp(buffer)
                    startTime = first
                    heldSound.filter { sampleTime($0) >= first }.forEach { audioFeed.push($0) }
                    heldSound = []
                }
                guard videoFeed.push(buffer) else { break }
            } else if packet.streamIndex == prepared.audio?.stream.index, let builder = prepared.audio {
                guard let buffer = try? builder.sampleBuffer(for: packet) else { continue }
                if prepared.video != nil, startTime == nil {
                    heldSound.append(buffer)
                    if heldSound.count > 200 { heldSound.removeFirst() }
                    continue
                }
                if startTime == nil { startTime = sampleTime(buffer) }
                guard audioFeed.push(buffer) else { break }
            }
            // In MPEG-TS the first sound can follow the first keyframe.
            let waited = startTime.map { CMTimeSubtract(packet.decodeTime, $0).seconds > 0.5 } ?? false
            let soundKnown = prepared.audio == nil || prepared.audio?.formatDescription != nil || waited
            if !announced, let startTime, soundKnown {
                announced = true
                ready(.success(describe(prepared, startTime: startTime)))
            }
        }
        return announced
    }

    private func describe(_ prepared: Prepared, startTime: CMTime) -> DemuxStart {
        let picture = prepared.video?.formatDescription.map(CMVideoFormatDescriptionGetDimensions)
        let sound = prepared.audio?.formatDescription
            .flatMap(CMAudioFormatDescriptionGetStreamBasicDescription)
            .map { Int($0.pointee.mChannelsPerFrame) }
        return DemuxStart(
            format: prepared.demuxer.format, streams: prepared.demuxer.streams, video: prepared.video?.stream,
            audio: prepared.audio?.stream, startTime: startTime, duration: prepared.demuxer.duration,
            pictureSize: picture, soundChannels: sound ?? prepared.audio?.stream.channels ?? 0)
    }

    private func sampleTime(_ buffer: CMSampleBuffer) -> CMTime {
        CMSampleBufferGetPresentationTimeStamp(buffer)
    }
}

/// Calls a result handler at most once, from any thread.
private final class Once<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (@Sendable (Value) -> Void)?

    init(_ handler: @escaping @Sendable (Value) -> Void) {
        self.handler = handler
    }

    @Sendable func call(_ value: Value) {
        let handler = lock.withLock {
            defer { self.handler = nil }
            return self.handler
        }
        handler?(value)
    }
}

extension Result {
    /// The success value, nil for a failure.
    fileprivate var success: Success? {
        if case .success(let value) = self { return value }
        return nil
    }
}
