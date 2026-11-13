import AntennaCore
import AudioToolbox
import CoreMedia
import Foundation

extension SampleBuilder {
    /// What an MPEG audio frame header says.
    struct MPEGAudioHeader: Equatable {
        /// 1, 2 or 3.
        let layer: Int
        let sampleRate: Int
        let channels: Int
        let samples: Int
    }

    /// The header of an MPEG-1, MPEG-2 or MPEG-2.5 audio frame, nil when the
    /// bytes do not start with one.
    static func mpegAudioHeader(_ frame: Data) -> MPEGAudioHeader? {
        let bytes = [UInt8](frame.prefix(4))
        guard bytes.count == 4, bytes[0] == 0xFF, bytes[1] & 0xE0 == 0xE0 else { return nil }
        let version = Int((bytes[1] >> 3) & 0x03)  // 3 MPEG-1, 2 MPEG-2, 0 MPEG-2.5
        let layer = 4 - Int((bytes[1] >> 1) & 0x03)
        let rateIndex = Int((bytes[2] >> 2) & 0x03)
        guard version != 1, (1...3).contains(layer), rateIndex < 3 else { return nil }
        let rates = [[11025, 12000, 8000], [], [22050, 24000, 16000], [44100, 48000, 32000]][version]
        let samples = layer == 1 ? 384 : (layer == 3 && version != 3 ? 576 : 1152)
        let channels = bytes[3] >> 6 == 3 ? 1 : 2
        return MPEGAudioHeader(layer: layer, sampleRate: rates[rateIndex], channels: channels, samples: samples)
    }

    static func mp3Format(sampleRate: Int, channels: Int, samples: Int = 1152) throws -> CMFormatDescription {
        guard sampleRate > 0, channels > 0 else { throw BuildError.malformed }
        var description = AudioStreamBasicDescription(
            mSampleRate: Float64(sampleRate), mFormatID: kAudioFormatMPEGLayer3, mFormatFlags: 0, mBytesPerPacket: 0,
            mFramesPerPacket: UInt32(samples), mBytesPerFrame: 0, mChannelsPerFrame: UInt32(channels), mBitsPerChannel: 0, mReserved: 0)
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
    ///
    /// ADTS labels HE-AAC as AAC LC at half the rate and leaves the SBR
    /// layer, which rebuilds the treble, implied. Apple's decoder plays such
    /// a config as plain LC, at half the bandwidth. A config of LC at 24 kHz
    /// or less is therefore declared as HE-AAC at twice the rate; a stream
    /// that is plain LC at that rate still decodes, upsampled.
    static func aacFormat(config: Data) throws -> CMFormatDescription {
        guard config.count >= 2 else { throw BuildError.malformed }
        let bytes = [UInt8](config)
        let objectType = Int(bytes[0] >> 3)
        let rateIndex = Int((bytes[0] & 0x07) << 1 | bytes[1] >> 7)
        let configuration = Int((bytes[1] >> 3) & 0x0F)
        guard rateIndex < aacSampleRates.count, let speakers = aacLayouts[configuration] else { throw BuildError.malformed }
        let channels = Int(AudioChannelLayoutTag_GetNumberOfChannels(speakers))
        var cookieConfig = config
        var formatID = kAudioFormatMPEG4AAC
        var flags = objectType
        var sampleRate = aacSampleRates[rateIndex]
        var frames = 1024
        if objectType == 2, sampleRate <= 24000, let doubled = aacSampleRates.firstIndex(of: sampleRate * 2) {
            cookieConfig = explicitSBR(rateIndex: rateIndex, channels: configuration, extensionRateIndex: doubled)
            (formatID, flags, sampleRate, frames) = (kAudioFormatMPEG4AAC_HE, 5, sampleRate * 2, 2048)
        } else if objectType == 5 || objectType == 29, bytes.count >= 3 {
            // Explicit SBR (and, for 29, parametric stereo): the rate after
            // SBR follows the channel configuration.
            let extensionIndex = Int((bytes[1] & 0x07) << 1 | bytes[2] >> 7)
            guard extensionIndex < aacSampleRates.count else { throw BuildError.malformed }
            formatID = objectType == 5 ? kAudioFormatMPEG4AAC_HE : kAudioFormatMPEG4AAC_HE_V2
            (sampleRate, frames) = (aacSampleRates[extensionIndex], 2048)
        }
        var description = AudioStreamBasicDescription(
            mSampleRate: Float64(sampleRate), mFormatID: formatID,
            mFormatFlags: AudioFormatFlags(flags), mBytesPerPacket: 0, mFramesPerPacket: UInt32(frames),
            mBytesPerFrame: 0, mChannelsPerFrame: UInt32(channels), mBitsPerChannel: 0, mReserved: 0)
        let cookie = esds(config: cookieConfig, objectType: 0x40, streamType: 0x15)
        var layout = AudioChannelLayout(
            mChannelLayoutTag: speakers, mChannelBitmap: [], mNumberChannelDescriptions: 0, mChannelDescriptions: AudioChannelDescription())
        var format: CMAudioFormatDescription?
        let status = cookie.withUnsafeBytes { raw in
            CMAudioFormatDescriptionCreate(
                allocator: nil, asbd: &description, layoutSize: MemoryLayout<AudioChannelLayout>.size, layout: &layout,
                magicCookieSize: cookie.count, magicCookie: raw.baseAddress, extensions: nil, formatDescriptionOut: &format)
        }
        guard status == noErr, let format else { throw BuildError.malformed }
        return format
    }

    /// The speakers of each AAC channel configuration, in AAC's order.
    /// Configurations 7, 12 and 14 are 7.1, eight channels. Configuration 0 leaves the
    /// layout to a program config element in the stream, which is not read.
    static let aacLayouts: [Int: AudioChannelLayoutTag] = [
        1: kAudioChannelLayoutTag_Mono, 2: kAudioChannelLayoutTag_Stereo, 3: kAudioChannelLayoutTag_AAC_3_0,
        4: kAudioChannelLayoutTag_AAC_4_0, 5: kAudioChannelLayoutTag_AAC_5_0, 6: kAudioChannelLayoutTag_AAC_5_1,
        7: kAudioChannelLayoutTag_AAC_7_1, 11: kAudioChannelLayoutTag_AAC_6_1, 12: kAudioChannelLayoutTag_AAC_7_1_B,
        14: kAudioChannelLayoutTag_AAC_7_1_C,
    ]

    /// An AudioSpecificConfig for HE-AAC with explicit SBR: object type 5,
    /// the core rate and channels, the rate after SBR, then LC as the core.
    static func explicitSBR(rateIndex: Int, channels: Int, extensionRateIndex: Int) -> Data {
        let bits = UInt32(5) << 27 | UInt32(rateIndex) << 23 | UInt32(channels) << 19 | UInt32(extensionRateIndex) << 15 | UInt32(2) << 10
        return Data([UInt8(bits >> 24), UInt8((bits >> 16) & 0xFF), UInt8((bits >> 8) & 0xFF), UInt8(bits & 0xFF)])
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
        /// The speakers, in the order Dolby codes them.
        let layoutTag: AudioChannelLayoutTag

        /// The speaker layout for the header's audio coding mode (acmod) and
        /// low-frequency channel, in Dolby's channel order.
        static func layoutTag(mode: Int, lfe: Bool) -> AudioChannelLayoutTag {
            switch (mode, lfe) {
            case (1, false): kAudioChannelLayoutTag_Mono
            case (1, true): kAudioChannelLayoutTag_AC3_1_0_1
            case (0, false), (2, false): kAudioChannelLayoutTag_Stereo
            case (0, true), (2, true): kAudioChannelLayoutTag_DVD_4
            case (3, false): kAudioChannelLayoutTag_AC3_3_0
            case (3, true): kAudioChannelLayoutTag_AC3_3_0_1
            case (4, false): kAudioChannelLayoutTag_ITU_2_1
            case (4, true): kAudioChannelLayoutTag_AC3_2_1_1
            case (5, false): kAudioChannelLayoutTag_AC3_3_1
            case (5, true): kAudioChannelLayoutTag_AC3_3_1_1
            case (6, false): kAudioChannelLayoutTag_ITU_2_2
            case (6, true): kAudioChannelLayoutTag_DVD_18
            case (_, false): kAudioChannelLayoutTag_MPEG_5_0_C
            case (_, true): kAudioChannelLayoutTag_MPEG_5_1_C
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
            return DolbyHeader(
                isEnhanced: false, sampleRate: rates[fscod], channels: channelsByMode[acmod] + lfe, samples: 1536,
                layoutTag: DolbyHeader.layoutTag(mode: acmod, lfe: lfe == 1))
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
        return DolbyHeader(
            isEnhanced: true, sampleRate: rate, channels: channelsByMode[acmod] + lfe, samples: blocks * 256,
            layoutTag: DolbyHeader.layoutTag(mode: acmod, lfe: lfe == 1))
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
