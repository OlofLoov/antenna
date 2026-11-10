import CoreMedia
import CoreVideo
import Foundation

/// The pictures of a stream that can be interlaced, made progressive
/// before they reach the renderer
/// (playback-engine/interlaced-broadcasts-are-deinterlaced). Compressed
/// H.264 is decoded with VideoToolbox first; MPEG-2 arrives decoded. A
/// picture marked with two fields goes through the deinterlacer and comes
/// out as two; any other picture passes as it is. One thread at a time.
final class FieldPictures: @unchecked Sendable {
    private let decoder: VideoDecoder?
    private var deinterlacer: Deinterlacer?
    private var format: CMVideoFormatDescription?
    /// True once a picture with two fields has been seen.
    private(set) var sawFields = false
    /// True when the stream's parameter sets say it is interlaced.
    let isInterlacedBySPS: Bool

    /// `decoder` decodes compressed pictures; nil when they arrive decoded.
    init(decoder: VideoDecoder?, isInterlacedBySPS: Bool = false) {
        self.decoder = decoder
        self.isInterlacedBySPS = isInterlacedBySPS
    }

    /// The progressive sample buffers for `sample`, in presentation order.
    func buffers(from sample: CMSampleBuffer) throws -> [CMSampleBuffer] {
        let pictures: [DecodedPicture]
        if let image = CMSampleBufferGetImageBuffer(sample) {
            pictures = [DecodedPicture(pixels: image, time: sample.presentationTimeStamp, duration: sample.duration)]
        } else {
            pictures = decoder?.decode(sample) ?? []
        }
        return try pictures.flatMap(progressive).map(wrap)
    }

    private func progressive(_ picture: DecodedPicture) throws -> [DecodedPicture] {
        // VideoToolbox marks every picture of interlaced H.264 with one field,
        // so for it the SPS decides; MPEG-2 pictures carry their own marks.
        let marked = CVBufferCopyAttachment(picture.pixels, kCVImageBufferFieldCountKey, nil) as? Int
        guard isInterlacedBySPS || marked == 2 else { return [picture] }
        sawFields = true
        let detail = CVBufferCopyAttachment(picture.pixels, kCVImageBufferFieldDetailKey, nil) as? String
        let topFirst =
            detail != (kCVImageBufferFieldDetailTemporalBottomFirst as String)
            && detail != (kCVImageBufferFieldDetailSpatialFirstLineLate as String)
        let deinterlacer = try self.deinterlacer ?? Deinterlacer()
        self.deinterlacer = deinterlacer
        return try deinterlacer.pictures(of: picture.pixels, at: picture.time, duration: picture.duration, topFirst: topFirst)
    }

    private func wrap(_ picture: DecodedPicture) throws -> CMSampleBuffer {
        if format.map({ !CMVideoFormatDescriptionMatchesImageBuffer($0, imageBuffer: picture.pixels) }) ?? true {
            var made: CMVideoFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: picture.pixels, formatDescriptionOut: &made)
            format = made
        }
        guard let format else { throw SampleBuilder.BuildError.malformed }
        var timing = CMSampleTimingInfo(duration: picture.duration, presentationTimeStamp: picture.time, decodeTimeStamp: .invalid)
        var buffer: CMSampleBuffer?
        guard
            CMSampleBufferCreateReadyWithImageBuffer(
                allocator: nil, imageBuffer: picture.pixels, formatDescription: format, sampleTiming: &timing,
                sampleBufferOut: &buffer) == noErr, let buffer
        else { throw SampleBuilder.BuildError.malformed }
        return buffer
    }
}
