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

    init(bytes: HTTPByteStream, videoFeed: SampleFeed, audioFeed: SampleFeed) {
        self.bytes = bytes
        self.videoFeed = videoFeed
        self.audioFeed = audioFeed
    }

    private var isCancelled: Bool {
        lock.withLock { cancelled }
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
        let thread = Thread { [self] in
            let answer = Once(ready)
            run(ready: answer.call, ended: ended)
            answer.call(.failure(CancellationError()))
        }
        thread.name = "se.codecrave.antenna.demux"
        thread.qualityOfService = .userInitiated
        thread.start()
    }

    private func run(
        ready: @escaping @Sendable (Result<DemuxStart, any Error>) -> Void,
        ended: @escaping @Sendable (PlaybackFailure?) -> Void
    ) {
        let bytes = self.bytes
        let demuxer: Demuxer
        do {
            demuxer = try Demuxer(read: { bytes.read(into: $0, count: $1) })
        } catch {
            if !isCancelled { ready(.failure(bytes.failureReason ?? PlaybackFailure.unreadable)) }
            return
        }
        defer { demuxer.close() }
        let video = demuxer.streams.first { $0.kind == .video }
        let audio = demuxer.streams.first { $0.kind == .audio }
        let videoBuilder: SampleBuilder?
        let audioBuilder: SampleBuilder?
        do {
            videoBuilder = try video.map(SampleBuilder.init)
        } catch {
            ready(.failure(PlaybackFailure.cannotDecode(codec: video?.codec ?? "video")))
            return
        }
        audioBuilder = audio.flatMap { try? SampleBuilder(stream: $0) }
        guard videoBuilder != nil || audioBuilder != nil else {
            ready(.failure(audio.map { PlaybackFailure.cannotDecode(codec: $0.codec) } ?? PlaybackFailure.unreadable))
            return
        }

        var startTime: CMTime?
        var heldSound: [CMSampleBuffer] = []
        var announced = false
        while !isCancelled, let packet = demuxer.nextPacket() {
            if packet.streamIndex == video?.index, let videoBuilder {
                if startTime == nil, !packet.isKeyframe { continue }
                guard let buffer = try? videoBuilder.sampleBuffer(for: packet) else { continue }
                if startTime == nil {
                    startTime = CMSampleBufferGetPresentationTimeStamp(buffer)
                    for sound in heldSound where startTime.map({ sampleTime(sound) >= $0 }) ?? false {
                        audioFeed.push(sound)
                    }
                    heldSound = []
                }
                guard videoFeed.push(buffer) else { break }
            } else if packet.streamIndex == audio?.index, let audioBuilder {
                guard let buffer = try? audioBuilder.sampleBuffer(for: packet) else { continue }
                if videoBuilder != nil, startTime == nil {
                    heldSound.append(buffer)
                    if heldSound.count > 200 { heldSound.removeFirst() }
                    continue
                }
                if startTime == nil { startTime = CMSampleBufferGetPresentationTimeStamp(buffer) }
                guard audioFeed.push(buffer) else { break }
            }
            // Wait for the first sound too (in MPEG-TS it can follow the
            // first keyframe), so the format reported includes it, but no
            // more than half a second of stream.
            let waited = startTime.map { CMTimeSubtract(packet.decodeTime, $0).seconds > 0.5 } ?? false
            let soundKnown = audioBuilder == nil || audioBuilder?.formatDescription != nil || waited
            if !announced, let startTime, soundKnown {
                announced = true
                let picture = videoBuilder?.formatDescription.map(CMVideoFormatDescriptionGetDimensions)
                let sound = audioBuilder?.formatDescription
                    .flatMap(CMAudioFormatDescriptionGetStreamBasicDescription)
                    .map { Int($0.pointee.mChannelsPerFrame) }
                ready(
                    .success(
                        DemuxStart(
                            format: demuxer.format, streams: demuxer.streams, video: videoBuilder.map(\.stream),
                            audio: audioBuilder.map(\.stream), startTime: startTime, duration: demuxer.duration,
                            pictureSize: picture, soundChannels: sound ?? audioBuilder?.stream.channels ?? 0)))
            }
        }
        guard !isCancelled else { return }
        if !announced {
            ready(.failure(bytes.failureReason ?? PlaybackFailure.unreadable))
        } else {
            ended(bytes.failureReason)
        }
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
