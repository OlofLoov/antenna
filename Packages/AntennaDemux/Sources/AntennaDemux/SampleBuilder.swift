import AudioToolbox
import CoreMedia
import Foundation

/// Turns one stream's compressed packets into `CMSampleBuffer`s that
/// Apple's decoders and sample-buffer renderers read: H.264 (Annex B from
/// MPEG-TS, or avcC from Matroska and MP4) and AAC (ADTS from MPEG-TS, or
/// raw with an AudioSpecificConfig).
public final class SampleBuilder {
    public enum BuildError: Error, Equatable {
        case unsupportedCodec(String)
        case malformed
    }

    private enum Codec {
        case h264AnnexB
        case h264AVCC
        case aacADTS
        case aacRaw(config: Data)
    }

    private let codec: Codec
    public let stream: DemuxedStream
    /// The format of the buffers built so far; nil for H.264 in MPEG-TS
    /// until the first parameter sets arrive.
    public private(set) var formatDescription: CMFormatDescription?
    /// Where the next AAC frame starts, for frames FFmpeg gives no time:
    /// it times only the first frame of a multi-frame packet.
    private var nextSoundTime: CMTime = .invalid

    /// Throws `unsupportedCodec` for a codec with no builder yet.
    public init(stream: DemuxedStream) throws {
        self.stream = stream
        switch stream.codec {
        case "h264" where stream.extradata.first == 1:
            codec = .h264AVCC
            formatDescription = try Self.h264Format(avcC: stream.extradata, width: stream.width, height: stream.height)
        case "h264":
            codec = .h264AnnexB
        case "aac" where !stream.extradata.isEmpty:
            codec = .aacRaw(config: stream.extradata)
        case "aac":
            codec = .aacADTS
        default:
            throw BuildError.unsupportedCodec(stream.codec)
        }
    }

    /// The sample buffer for `packet`, or nil when it cannot be shown yet
    /// (H.264 before its first parameter sets).
    public func sampleBuffer(for packet: DemuxedPacket) throws -> CMSampleBuffer? {
        switch codec {
        case .h264AnnexB:
            let units = Self.nalUnits(annexB: packet.data)
            let sps = units.last { $0.first.map { $0 & 0x1F } == 7 }
            let pps = units.last { $0.first.map { $0 & 0x1F } == 8 }
            if let sps, let pps {
                formatDescription = try Self.h264Format(sps: sps, pps: pps)
            }
            guard let format = formatDescription else { return nil }
            let payload = units.filter { unit in
                guard let type = unit.first.map({ $0 & 0x1F }) else { return false }
                return ![7, 8, 9].contains(type)
            }
            guard !payload.isEmpty else { return nil }
            return try Self.videoBuffer(Self.lengthPrefixed(payload), format: format, packet: packet)
        case .h264AVCC:
            guard let format = formatDescription else { return nil }
            return try Self.videoBuffer(packet.data, format: format, packet: packet)
        case .aacADTS:
            let frames = try Self.adtsFrames(packet.data)
            guard let first = frames.first else { return nil }
            if formatDescription == nil {
                formatDescription = try Self.aacFormat(config: first.config)
            }
            guard let format = formatDescription else { return nil }
            return try soundBuffer(frames.map(\.payload), format: format, packet: packet)
        case .aacRaw(let config):
            if formatDescription == nil {
                formatDescription = try Self.aacFormat(config: config)
            }
            guard let format = formatDescription else { return nil }
            return try soundBuffer([packet.data], format: format, packet: packet)
        }
    }

    /// An AAC buffer timed by the packet, or right after the previous one
    /// when the packet has no time.
    private func soundBuffer(_ frames: [Data], format: CMFormatDescription, packet: DemuxedPacket) throws -> CMSampleBuffer? {
        let time = packet.presentationTime.isValid ? packet.presentationTime : nextSoundTime
        guard time.isValid,
            let rate = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee.mSampleRate, rate > 0
        else { return nil }
        let buffer = try Self.audioBuffer(frames, format: format, time: time)
        nextSoundTime = CMTimeAdd(time, CMTime(value: CMTimeValue(frames.count * 1024), timescale: CMTimeScale(rate)))
        return buffer
    }

    // MARK: H.264

    /// The NAL units in an Annex B byte stream, without start codes.
    static func nalUnits(annexB data: Data) -> [Data] {
        let bytes = [UInt8](data)
        var starts: [(code: Int, payload: Int)] = []
        var index = 0
        while index + 3 <= bytes.count {
            if bytes[index] == 0, bytes[index + 1] == 0, bytes[index + 2] == 1 {
                let code = index > 0 && bytes[index - 1] == 0 ? index - 1 : index
                starts.append((code, index + 3))
                index += 3
            } else {
                index += 1
            }
        }
        return starts.enumerated().compactMap { offset, start in
            let end = offset + 1 < starts.count ? starts[offset + 1].code : bytes.count
            guard end > start.payload else { return nil }
            return Data(bytes[start.payload..<end])
        }
    }

    static func lengthPrefixed(_ units: [Data]) -> Data {
        var out = Data()
        for unit in units {
            var length = UInt32(unit.count).bigEndian
            withUnsafeBytes(of: &length) { out.append(contentsOf: $0) }
            out.append(unit)
        }
        return out
    }

    static func h264Format(sps: Data, pps: Data) throws -> CMFormatDescription {
        var format: CMFormatDescription?
        let status = sps.withUnsafeBytes { spsBytes in
            pps.withUnsafeBytes { ppsBytes in
                guard let spsBase = spsBytes.bindMemory(to: UInt8.self).baseAddress,
                    let ppsBase = ppsBytes.bindMemory(to: UInt8.self).baseAddress
                else { return OSStatus(-1) }
                let pointers = [spsBase, ppsBase]
                let sizes = [sps.count, pps.count]
                return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: nil, parameterSetCount: 2, parameterSetPointers: pointers,
                    parameterSetSizes: sizes, nalUnitHeaderLength: 4, formatDescriptionOut: &format)
            }
        }
        guard status == noErr, let format else { throw BuildError.malformed }
        return format
    }

    static func h264Format(avcC: Data, width: Int, height: Int) throws -> CMFormatDescription {
        let extensions: [CFString: Any] = [
            kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms: ["avcC": avcC]
        ]
        var format: CMFormatDescription?
        let status = CMVideoFormatDescriptionCreate(
            allocator: nil, codecType: kCMVideoCodecType_H264, width: Int32(width), height: Int32(height),
            extensions: extensions as CFDictionary, formatDescriptionOut: &format)
        guard status == noErr, let format else { throw BuildError.malformed }
        return format
    }

    static func videoBuffer(_ data: Data, format: CMFormatDescription, packet: DemuxedPacket) throws -> CMSampleBuffer {
        let block = try blockBuffer(data)
        var timing = CMSampleTimingInfo(
            duration: packet.duration, presentationTimeStamp: packet.presentationTime, decodeTimeStamp: packet.decodeTime)
        var size = data.count
        var buffer: CMSampleBuffer?
        let status = CMSampleBufferCreateReady(
            allocator: nil, dataBuffer: block, formatDescription: format, sampleCount: 1,
            sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 1,
            sampleSizeArray: &size, sampleBufferOut: &buffer)
        guard status == noErr, let buffer else { throw BuildError.malformed }
        guard !packet.isKeyframe,
            let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true),
            CFArrayGetCount(attachments) > 0
        else { return buffer }
        let first = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
        CFDictionarySetValue(
            first, Unmanaged.passUnretained(kCMSampleAttachmentKey_NotSync).toOpaque(),
            Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        return buffer
    }

    // MARK: AAC

    struct ADTSFrame {
        let config: Data
        let payload: Data
    }

    static let aacSampleRates = [96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000, 7350]

    /// The AAC frames in ADTS-framed bytes, headers removed, each with the
    /// AudioSpecificConfig its header describes.
    static func adtsFrames(_ data: Data) throws -> [ADTSFrame] {
        let bytes = [UInt8](data)
        var frames: [ADTSFrame] = []
        var index = 0
        while index + 7 <= bytes.count {
            guard bytes[index] == 0xFF, bytes[index + 1] & 0xF6 == 0xF0 else { throw BuildError.malformed }
            let protectionAbsent = bytes[index + 1] & 0x01 == 1
            let objectType = Int(bytes[index + 2] >> 6) + 1
            let rateIndex = Int((bytes[index + 2] >> 2) & 0x0F)
            let channels = Int((bytes[index + 2] & 0x01) << 2) | Int(bytes[index + 3] >> 6)
            let length = (Int(bytes[index + 3] & 0x03) << 11) | (Int(bytes[index + 4]) << 3) | Int(bytes[index + 5] >> 5)
            let header = protectionAbsent ? 7 : 9
            guard rateIndex < aacSampleRates.count, length > header, index + length <= bytes.count else {
                throw BuildError.malformed
            }
            let config = UInt16(objectType << 11 | rateIndex << 7 | channels << 3)
            frames.append(
                ADTSFrame(
                    config: Data([UInt8(config >> 8), UInt8(config & 0xFF)]),
                    payload: Data(bytes[(index + header)..<(index + length)])))
            index += length
        }
        return frames
    }

    /// An AAC format whose magic cookie is an `esds` descriptor wrapping the
    /// AudioSpecificConfig, the form Apple's AAC decoder reads.
    static func aacFormat(config: Data) throws -> CMFormatDescription {
        guard config.count >= 2 else { throw BuildError.malformed }
        let objectType = Int(config[config.startIndex] >> 3)
        let rateIndex = Int((config[config.startIndex] & 0x07) << 1 | config[config.startIndex + 1] >> 7)
        let channels = Int((config[config.startIndex + 1] >> 3) & 0x0F)
        guard rateIndex < aacSampleRates.count, channels > 0 else { throw BuildError.malformed }
        var description = AudioStreamBasicDescription(
            mSampleRate: Float64(aacSampleRates[rateIndex]), mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: AudioFormatFlags(objectType), mBytesPerPacket: 0, mFramesPerPacket: 1024,
            mBytesPerFrame: 0, mChannelsPerFrame: UInt32(channels), mBitsPerChannel: 0, mReserved: 0)
        let cookie = esds(config: config)
        var format: CMAudioFormatDescription?
        let status = cookie.withUnsafeBytes { raw in
            CMAudioFormatDescriptionCreate(
                allocator: nil, asbd: &description, layoutSize: 0, layout: nil, magicCookieSize: cookie.count,
                magicCookie: raw.baseAddress, extensions: nil, formatDescriptionOut: &format)
        }
        guard status == noErr, let format else { throw BuildError.malformed }
        return format
    }

    /// An MPEG-4 elementary stream descriptor for AAC with `config`.
    static func esds(config: Data) -> Data {
        let decoderSpecific = [UInt8(0x05), UInt8(config.count)] + [UInt8](config)
        let decoderConfig: [UInt8] =
            [0x04, UInt8(13 + decoderSpecific.count), 0x40, 0x15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] + decoderSpecific
        let slConfig: [UInt8] = [0x06, 0x01, 0x02]
        let body: [UInt8] = [0, 0, 0] + decoderConfig + slConfig
        return Data([0x03, UInt8(body.count)] + body)
    }

    static func audioBuffer(_ frames: [Data], format: CMFormatDescription, time: CMTime) throws -> CMSampleBuffer {
        var data = Data()
        var descriptions: [AudioStreamPacketDescription] = []
        for frame in frames {
            descriptions.append(
                AudioStreamPacketDescription(
                    mStartOffset: Int64(data.count), mVariableFramesInPacket: 0, mDataByteSize: UInt32(frame.count)))
            data.append(frame)
        }
        let block = try blockBuffer(data)
        var buffer: CMSampleBuffer?
        let status = CMAudioSampleBufferCreateReadyWithPacketDescriptions(
            allocator: nil, dataBuffer: block, formatDescription: format, sampleCount: frames.count,
            presentationTimeStamp: time, packetDescriptions: descriptions,
            sampleBufferOut: &buffer)
        guard status == noErr, let buffer else { throw BuildError.malformed }
        return buffer
    }

    // MARK: Memory

    static func blockBuffer(_ data: Data) throws -> CMBlockBuffer {
        var block: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: nil, memoryBlock: nil, blockLength: data.count, blockAllocator: nil,
            customBlockSource: nil, offsetToData: 0, dataLength: data.count, flags: kCMBlockBufferAssureMemoryNowFlag,
            blockBufferOut: &block)
        guard status == noErr, let block else { throw BuildError.malformed }
        status = data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return OSStatus(-1) }
            return CMBlockBufferReplaceDataBytes(with: base, blockBuffer: block, offsetIntoDestination: 0, dataLength: data.count)
        }
        guard status == noErr else { throw BuildError.malformed }
        return block
    }
}
