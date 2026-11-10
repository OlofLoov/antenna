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

    // MARK: Dolby Digital and Dolby Digital Plus

    /// What an AC-3 or E-AC-3 frame header says about its sound.
    struct DolbyHeader: Equatable {
        let isEnhanced: Bool
        let sampleRate: Int
        let channels: Int
        /// Samples per channel in the frame: 1536 for AC-3, 256 per block for E-AC-3.
        let samples: Int
        /// The speaker layout, for more than two channels.
        var layoutTag: AudioChannelLayoutTag {
            switch channels {
            case 1: kAudioChannelLayoutTag_Mono
            case 2: kAudioChannelLayoutTag_Stereo
            case 6: kAudioChannelLayoutTag_MPEG_5_1_C  // AC-3 order: L C R Ls Rs LFE
            default: kAudioChannelLayoutTag_DiscreteInOrder | AudioChannelLayoutTag(channels)
            }
        }
    }

    /// The header of an AC-3 (bsid up to 10) or E-AC-3 (bsid 16) frame, nil
    /// when the bytes do not start with one.
    static func dolbyHeader(_ frame: Data) -> DolbyHeader? {
        let bytes = [UInt8](frame.prefix(8))
        guard bytes.count >= 8, bytes[0] == 0x0B, bytes[1] == 0x77 else { return nil }
        let bsid = Int(bytes[5] >> 3)
        let channelsByMode = [2, 1, 2, 3, 3, 4, 4, 5]
        if bsid <= 10 {
            let rates = [48000, 44100, 32000]
            let fscod = Int(bytes[4] >> 6)
            guard fscod < rates.count else { return nil }
            let acmod = Int(bytes[6] >> 5)
            // lfeon follows optional 2-bit mix levels that depend on acmod.
            var bit = 3
            if acmod & 1 != 0, acmod != 1 { bit += 2 }
            if acmod & 4 != 0 { bit += 2 }
            if acmod == 2 { bit += 2 }
            let word = Int(bytes[6]) << 8 | Int(bytes[7])
            let lfe = (word >> (15 - bit)) & 1
            return DolbyHeader(isEnhanced: false, sampleRate: rates[fscod], channels: channelsByMode[acmod] + lfe, samples: 1536)
        }
        guard bsid == 16 else { return nil }
        let fscod = Int(bytes[4] >> 6)
        let second = Int((bytes[4] >> 4) & 0x03)
        let rate: Int
        let blocks: Int
        if fscod == 3 {
            guard second < 3 else { return nil }
            rate = [24000, 22050, 16000][second]
            blocks = 6
        } else {
            rate = [48000, 44100, 32000][fscod]
            blocks = [1, 2, 3, 6][second]
        }
        let acmod = Int((bytes[4] >> 1) & 0x07)
        let lfe = Int(bytes[4] & 0x01)
        return DolbyHeader(isEnhanced: true, sampleRate: rate, channels: channelsByMode[acmod] + lfe, samples: blocks * 256)
    }

    static func dolbyFormat(_ header: DolbyHeader) throws -> CMFormatDescription {
        var description = AudioStreamBasicDescription(
            mSampleRate: Float64(header.sampleRate), mFormatID: header.isEnhanced ? kAudioFormatEnhancedAC3 : kAudioFormatAC3,
            mFormatFlags: 0, mBytesPerPacket: 0, mFramesPerPacket: UInt32(header.samples), mBytesPerFrame: 0,
            mChannelsPerFrame: UInt32(header.channels), mBitsPerChannel: 0, mReserved: 0)
        var layout = AudioChannelLayout(
            mChannelLayoutTag: header.layoutTag, mChannelBitmap: [], mNumberChannelDescriptions: 0,
            mChannelDescriptions: AudioChannelDescription())
        var format: CMAudioFormatDescription?
        let status = CMAudioFormatDescriptionCreate(
            allocator: nil, asbd: &description, layoutSize: MemoryLayout<AudioChannelLayout>.size, layout: &layout,
            magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &format)
        guard status == noErr, let format else { throw BuildError.malformed }
        return format
    }
}
