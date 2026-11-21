@preconcurrency import AVFoundation
import AntennaCore
import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox

@testable import AntennaDemux

/// Runs a file through `DemuxRun` the way the engine does and decodes the
/// video buffers it queues with VideoToolbox, as the video renderer would:
/// in the order queued, skipping buffers marked not to be shown. Each shown
/// picture is reduced to a small grid of luma and chroma averages, so two
/// runs over the same pictures can be compared by presentation time.
enum PictureCheck {
    struct Picture {
        let time: CMTime
        /// Averages of Y, Cb and Cr over a 16 x 9 grid, 0 to 255.
        let grid: [Double]
        /// The decoder's status for the frame.
        let status: OSStatus
    }

    struct Outcome {
        var pictures: [Picture] = []
        /// Buffers queued with no picture (marked not to be shown).
        var hidden = 0
        /// Buffers VideoToolbox refused outright.
        var refused = 0
        /// Times of every buffer queued to the video renderer, in order.
        var queued: [CMTime] = []
        /// Sound buffers queued, with their times and lengths.
        var sound: [(time: CMTime, duration: CMTime)] = []
        /// The video buffers as queued.
        var buffers: [CMSampleBuffer] = []
    }

    /// Plays `file` through a run into recording renderers and decodes what
    /// reached the video one.
    /// With `startAt`, the file is read as a film that can skip and starts
    /// there, as when it resumes.
    static func run(_ file: URL, startAt: CMTime? = nil) async throws -> Outcome {
        let data = try Data(contentsOf: file)
        let bytes = MemoryBytes(data, canSeek: startAt != nil)
        var timebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: nil, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
        guard let clock = timebase else { throw CheckFailed() }
        let video = KeepingRenderer(timebase: clock)
        let audio = KeepingRenderer(timebase: clock)
        let run = DemuxRun(
            bytes: bytes, videoFeed: SampleFeed(renderer: video, label: "check.video", limit: 100_000),
            audioFeed: SampleFeed(renderer: audio, label: "check.audio", limit: 100_000))
        let ended = Flag()
        run.start(
            ready: { _ in }, startAt: startAt, options: PlaybackOptions(isLive: startAt == nil ? nil : false),
            ended: { _ in ended.set() })
        let deadline = ContinuousClock.now + .seconds(30)
        while !ended.value, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        // The feeds hand buffers over on their own queues.
        try await Task.sleep(for: .milliseconds(300))
        run.cancel()
        var outcome = decode(video.buffers)
        outcome.buffers = video.buffers
        outcome.sound = audio.buffers.map { (CMSampleBufferGetPresentationTimeStamp($0), CMSampleBufferGetDuration($0)) }
        return outcome
    }

    /// Decodes `buffers` in order with one VideoToolbox session, made again
    /// when the format changes to one it cannot take.
    static func decode(_ buffers: [CMSampleBuffer]) -> Outcome {
        var outcome = Outcome()
        var session: (VTDecompressionSession, CMFormatDescription)?
        defer { session.map { VTDecompressionSessionInvalidate($0.0) } }
        for buffer in buffers {
            outcome.queued.append(CMSampleBufferGetPresentationTimeStamp(buffer))
            if let image = CMSampleBufferGetImageBuffer(buffer) {
                outcome.pictures.append(Picture(time: CMSampleBufferGetPresentationTimeStamp(buffer), grid: grid(image), status: noErr))
                continue
            }
            guard let format = CMSampleBufferGetFormatDescription(buffer) else { continue }
            if session.map({ !VTDecompressionSessionCanAcceptFormatDescription($0.0, formatDescription: format) }) ?? true {
                session.map { VTDecompressionSessionInvalidate($0.0) }
                session = makeSession(format).map { ($0, format) }
            }
            guard let (decoder, _) = session else {
                outcome.refused += 1
                continue
            }
            let hidden = isHidden(buffer)
            nonisolated(unsafe) var decoded: [Picture] = []
            let handler: VTDecompressionOutputHandler = { status, _, image, time, _ in
                guard let image else {
                    if status != noErr { decoded.append(Picture(time: time, grid: [], status: status)) }
                    return
                }
                decoded.append(Picture(time: time, grid: grid(image), status: status))
            }
            let status = VTDecompressionSessionDecodeFrame(
                decoder, sampleBuffer: buffer, flags: [], infoFlagsOut: nil, outputHandler: handler)
            VTDecompressionSessionWaitForAsynchronousFrames(decoder)
            if status != noErr { outcome.refused += 1 }
            if hidden {
                outcome.hidden += 1
            } else {
                outcome.pictures += decoded
            }
        }
        outcome.pictures.sort { $0.time < $1.time }
        return outcome
    }

    /// The pictures of `outcome` that differ from the picture `reference`
    /// shows at the same time by more than `tolerance` on average, or that
    /// the reference does not have.
    static func damaged(_ outcome: Outcome, against reference: Outcome, tolerance: Double = 6) -> [CMTime] {
        var known: [CMTime: [Double]] = [:]
        for picture in reference.pictures where picture.status == noErr { known[picture.time] = picture.grid }
        return outcome.pictures.compactMap { picture in
            guard picture.status == noErr, let clean = known[picture.time], clean.count == picture.grid.count else { return picture.time }
            let difference = zip(clean, picture.grid).map { abs($0 - $1) }.reduce(0, +) / Double(clean.count)
            return difference > tolerance ? picture.time : nil
        }
    }

    private static func isHidden(_ buffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[CFString: Any]],
            let first = attachments.first
        else { return false }
        return (first[kCMSampleAttachmentKey_DoNotDisplay] as? Bool) == true
    }

    private static func makeSession(_ format: CMFormatDescription) -> VTDecompressionSession? {
        let attributes: [CFString: Any] = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
        var session: VTDecompressionSession?
        let status = VTDecompressionSessionCreate(
            allocator: nil, formatDescription: format, decoderSpecification: nil, imageBufferAttributes: attributes as CFDictionary,
            outputCallback: nil, decompressionSessionOut: &session)
        return status == noErr ? session : nil
    }

    /// Y, Cb and Cr averaged over a 16 x 9 grid of an NV12 picture.
    static func grid(_ image: CVPixelBuffer) -> [Double] {
        CVPixelBufferLockBaseAddress(image, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(image, .readOnly) }
        guard CVPixelBufferGetPlaneCount(image) == 2,
            let luma = CVPixelBufferGetBaseAddressOfPlane(image, 0)?.assumingMemoryBound(to: UInt8.self),
            let chroma = CVPixelBufferGetBaseAddressOfPlane(image, 1)?.assumingMemoryBound(to: UInt8.self)
        else { return [] }
        let width = CVPixelBufferGetWidthOfPlane(image, 0)
        let height = CVPixelBufferGetHeightOfPlane(image, 0)
        let lumaRow = CVPixelBufferGetBytesPerRowOfPlane(image, 0)
        let chromaRow = CVPixelBufferGetBytesPerRowOfPlane(image, 1)
        var cells = [Double](repeating: 0, count: 16 * 9 * 3)
        var counts = [Double](repeating: 0, count: 16 * 9)
        for row in stride(from: 0, to: height, by: 2) {
            for column in stride(from: 0, to: width, by: 2) {
                let cell = (row * 9 / height) * 16 + column * 16 / width
                cells[cell * 3] += Double(luma[row * lumaRow + column])
                cells[cell * 3 + 1] += Double(chroma[(row / 2) * chromaRow + column])
                cells[cell * 3 + 2] += Double(chroma[(row / 2) * chromaRow + column + 1])
                counts[cell] += 1
            }
        }
        return cells.indices.map { cells[$0] / max(1, counts[$0 / 3]) }
    }

    struct CheckFailed: Error {}
}

/// Bytes from memory, read once from the start, as a live stream arrives.
final class MemoryBytes: DemuxBytes, @unchecked Sendable {
    private let data: Data
    private let lock = NSLock()
    private var offset = 0
    private var cancelled = false

    let canSeek: Bool

    init(_ data: Data, canSeek: Bool = false) {
        self.data = data
        self.canSeek = canSeek
    }

    func read(into destination: UnsafeMutablePointer<UInt8>, count: Int) -> Int {
        lock.withLock {
            let taken = min(count, data.count - offset)
            guard taken > 0, !cancelled else { return 0 }
            data.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return }
                destination.update(from: base.advanced(by: offset).assumingMemoryBound(to: UInt8.self), count: taken)
            }
            offset += taken
            return taken
        }
    }

    func peek(_ count: Int) -> Data { data.prefix(count) }
    var failureReason: PlaybackFailure? { nil }
    var length: Int? { canSeek ? data.count : nil }
    var position: Int { lock.withLock { offset } }

    func seek(to target: Int) -> Bool {
        guard canSeek, (0...data.count).contains(target) else { return false }
        lock.withLock { offset = target }
        return true
    }
    func cancel() { lock.withLock { cancelled = true } }
}

/// A renderer that takes every buffer and keeps it.
final class KeepingRenderer: NSObject, AVQueuedSampleBufferRendering, @unchecked Sendable {
    private let lock = NSLock()
    private var kept: [CMSampleBuffer] = []
    let timebase: CMTimebase

    init(timebase: CMTimebase) {
        self.timebase = timebase
    }

    var buffers: [CMSampleBuffer] { lock.withLock { kept } }

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        lock.withLock { kept.append(sampleBuffer) }
    }

    func flush() {}
    var isReadyForMoreMediaData: Bool { true }
    // swiftlint:disable:next identifier_name
    var hasSufficientMediaDataForReliablePlaybackStart: Bool { true }
    func requestMediaDataWhenReady(on queue: DispatchQueue, using block: @escaping @Sendable () -> Void) {}
    func stopRequestingMediaData() {}
}

/// Set once from any thread.
final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var isSet = false
    var value: Bool { lock.withLock { isSet } }
    func set() { lock.withLock { isSet = true } }
}
