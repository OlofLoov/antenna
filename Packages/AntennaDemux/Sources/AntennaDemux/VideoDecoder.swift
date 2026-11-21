import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox

/// A decoded picture and when it is shown.
struct DecodedPicture: @unchecked Sendable {
    let pixels: CVPixelBuffer
    let time: CMTime
    let duration: CMTime
}

/// VideoToolbox decoding to NV12 pixel buffers the GPU can read, for
/// pictures the engine works on before showing them: interlaced H.264 on
/// its way to the deinterlacer. Pictures come out in presentation order.
/// One thread at a time.
final class VideoDecoder: @unchecked Sendable {
    private let session: VTDecompressionSession
    private var pending: [DecodedPicture] = []
    /// Pictures held back to put B-frames in order before one is released.
    private let reorderDepth = 4
    /// False when the stream names no colors. VideoToolbox then tags its
    /// pictures BT.709 whatever their size, and the tags are left off so
    /// SD gets SD colors (playback-engine/pictures-show-at-their-shape-and-in-their-colors).
    private let namesColors: Bool

    enum DecodeError: Error, Equatable {
        case cannotCreate(OSStatus)
    }

    init(format: CMVideoFormatDescription) throws {
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [String: Any](),
        ]
        var session: VTDecompressionSession?
        let status = VTDecompressionSessionCreate(
            allocator: nil, formatDescription: format, decoderSpecification: nil,
            imageBufferAttributes: attributes as CFDictionary, outputCallback: nil, decompressionSessionOut: &session)
        guard status == noErr, let session else { throw DecodeError.cannotCreate(status) }
        self.session = session
        namesColors = CMFormatDescriptionGetExtension(format, extensionKey: kCMFormatDescriptionExtension_YCbCrMatrix) != nil
    }

    deinit {
        VTDecompressionSessionInvalidate(session)
    }

    /// Decodes `sample` and returns the pictures now due, in presentation
    /// order. A failed frame is skipped.
    func decode(_ sample: CMSampleBuffer) -> [DecodedPicture] {
        let duration = CMSampleBufferGetDuration(sample)
        let namesColors = self.namesColors
        nonisolated(unsafe) var decoded: [DecodedPicture] = []
        let handler: VTDecompressionOutputHandler = { status, _, image, time, frameDuration in
            guard status == noErr, let image else { return }
            if !namesColors {
                for key in [kCVImageBufferYCbCrMatrixKey, kCVImageBufferColorPrimariesKey, kCVImageBufferTransferFunctionKey] {
                    CVBufferRemoveAttachment(image, key)
                }
            }
            decoded.append(DecodedPicture(pixels: image, time: time, duration: frameDuration.isValid ? frameDuration : duration))
        }
        VTDecompressionSessionDecodeFrame(session, sampleBuffer: sample, flags: [], infoFlagsOut: nil, outputHandler: handler)
        VTDecompressionSessionWaitForAsynchronousFrames(session)
        pending.append(contentsOf: decoded)
        pending.sort { $0.time < $1.time }
        var due: [DecodedPicture] = []
        while pending.count > reorderDepth {
            due.append(pending.removeFirst())
        }
        return due
    }

    /// The pictures still held back, in presentation order, as at the end
    /// of a stream.
    func flush() -> [DecodedPicture] {
        defer { pending = [] }
        return pending
    }
}
