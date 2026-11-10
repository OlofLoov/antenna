import AntennaCore
import AudioToolbox
import CoreMedia
import Foundation

extension SampleBuilder {
    static func mp3Format(sampleRate: Int, channels: Int) throws -> CMFormatDescription {
        guard sampleRate > 0, channels > 0 else { throw BuildError.malformed }
        var description = AudioStreamBasicDescription(
            mSampleRate: Float64(sampleRate), mFormatID: kAudioFormatMPEGLayer3, mFormatFlags: 0, mBytesPerPacket: 0,
            mFramesPerPacket: 1152, mBytesPerFrame: 0, mChannelsPerFrame: UInt32(channels), mBitsPerChannel: 0, mReserved: 0)
        var format: CMAudioFormatDescription?
        let status = CMAudioFormatDescriptionCreate(
            allocator: nil, asbd: &description, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil,
            extensions: nil, formatDescriptionOut: &format)
        guard status == noErr, let format else { throw BuildError.malformed }
        return format
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
        let cookie = esds(config: config, objectType: 0x40, streamType: 0x15)
        var format: CMAudioFormatDescription?
        let status = cookie.withUnsafeBytes { raw in
            CMAudioFormatDescriptionCreate(
                allocator: nil, asbd: &description, layoutSize: 0, layout: nil, magicCookieSize: cookie.count,
                magicCookie: raw.baseAddress, extensions: nil, formatDescriptionOut: &format)
        }
        guard status == noErr, let format else { throw BuildError.malformed }
        return format
    }

    /// An MPEG-4 elementary stream descriptor with `config` as its decoder
    /// configuration: object type 0x40 and stream type 0x15 for AAC, 0x20
    /// and 0x11 for MPEG-4 Part 2 video. Configurations up to 100 bytes.
    static func esds(config: Data, objectType: UInt8, streamType: UInt8) -> Data {
        let decoderSpecific = [UInt8(0x05), UInt8(config.count)] + [UInt8](config)
        let decoderConfig: [UInt8] =
            [0x04, UInt8(13 + decoderSpecific.count), objectType, streamType, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] + decoderSpecific
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
