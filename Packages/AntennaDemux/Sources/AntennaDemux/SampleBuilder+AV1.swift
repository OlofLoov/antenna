import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox

// MARK: AV1 and VP9

extension SampleBuilder {
    /// The codecs VideoToolbox decodes only where the device has the
    /// hardware for them (playback-engine/av1-and-vp9-play-where-the-device-decodes-them).
    static let hardwareOnlyCodecs: Set<String> = ["av1", "vp9"]

    /// True when the device decodes `codec`, "av1" or "vp9", in hardware.
    /// VP9 needs VideoToolbox's supplemental decoder, which is asked for
    /// first. No software decoder is ever used for either.
    static func hardwareDecodes(_ codec: String) -> Bool {
        switch codec {
        case "av1":
            return VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)
        case "vp9":
            #if os(macOS)
                VTRegisterSupplementalVideoDecoderIfAvailable(kCMVideoCodecType_VP9)
            #endif
            return VTIsHardwareDecodeSupported(kCMVideoCodecType_VP9)
        default:
            return false
        }
    }

    /// An AV1 format from the av1C the container carries.
    static func av1Format(_ stream: DemuxedStream) throws -> CMFormatDescription {
        guard stream.extradata.count >= 4 else { throw BuildError.malformed }
        return try compressedVideoFormat(kCMVideoCodecType_AV1, atom: "av1C", stream.extradata, stream)
    }

    /// A VP9 format with a vpcC written from the stream's parameters, since
    /// Matroska carries none and FFmpeg reads MP4's into its parameters.
    static func vp9Format(_ stream: DemuxedStream) throws -> CMFormatDescription {
        try compressedVideoFormat(kCMVideoCodecType_VP9, atom: "vpcC", vpcC(stream.video), stream)
    }

    /// A version 1 VP Codec Configuration box body, with no codec
    /// initialization data.
    static func vpcC(_ video: DemuxedStream.VideoParameters) -> Data {
        let depth = UInt8(clamping: video.bitDepth > 0 ? video.bitDepth : 8)
        let packed = depth << 4 | UInt8(clamping: video.chromaSubsampling) << 1 | (video.fullRange ? 1 : 0)
        return Data([
            1, 0, 0, 0, UInt8(clamping: max(0, video.profile)), UInt8(clamping: max(0, video.level)), packed,
            UInt8(clamping: video.primaries), UInt8(clamping: video.transfer), UInt8(clamping: video.matrix), 0, 0,
        ])
    }

    private static func compressedVideoFormat(
        _ type: CMVideoCodecType, atom: String, _ body: Data, _ stream: DemuxedStream
    ) throws -> CMFormatDescription {
        guard stream.width > 0, stream.height > 0 else { throw BuildError.malformed }
        var extensions: [CFString: Any] = [kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms: [atom: body]]
        let video = stream.video
        let named: [(CFString, Unmanaged<CFString>?)] = [
            (kCMFormatDescriptionExtension_YCbCrMatrix, CVYCbCrMatrixGetStringForIntegerCodePoint(Int32(video.matrix))),
            (kCMFormatDescriptionExtension_ColorPrimaries, CVColorPrimariesGetStringForIntegerCodePoint(Int32(video.primaries))),
            (kCMFormatDescriptionExtension_TransferFunction, CVTransferFunctionGetStringForIntegerCodePoint(Int32(video.transfer))),
        ]
        for (key, value) in named {
            if let value { extensions[key] = value.takeUnretainedValue() }
        }
        if video.fullRange { extensions[kCMFormatDescriptionExtension_FullRangeVideo] = true }
        var format: CMFormatDescription?
        let status = CMVideoFormatDescriptionCreate(
            allocator: nil, codecType: type, width: Int32(stream.width), height: Int32(stream.height),
            extensions: extensions as CFDictionary, formatDescriptionOut: &format)
        guard status == noErr, let format else { throw BuildError.malformed }
        return format
    }
}

extension DemuxEngine {
    /// True when the FFmpeg path decodes `codec`, "av1" or "vp9", on this
    /// device. Both decode only in hardware.
    public nonisolated static func decodesInHardware(codec: String) -> Bool {
        SampleBuilder.hardwareDecodes(codec)
    }
}
