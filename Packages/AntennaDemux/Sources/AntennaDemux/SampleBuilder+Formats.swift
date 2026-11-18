import AudioToolbox
import CoreMedia
import Foundation

extension SampleBuilder {
    // MARK: Opus

    /// The channel mapping family of an Opus identification header: 0 for
    /// mono and stereo, which Apple's decoder takes; 1 and up for more
    /// channels, which it decodes to nothing. Nil when the bytes are no
    /// identification header.
    static func opusMappingFamily(_ head: Data) -> Int? {
        let bytes = [UInt8](head)
        guard bytes.count >= 19, bytes.starts(with: Array("OpusHead".utf8)) else { return nil }
        return Int(bytes[18])
    }

    /// An Opus format with the identification header as its magic cookie.
    /// Opus always decodes at 48 kHz, and packets hold 2.5 to 120 ms, so
    /// each packet says how many samples it has.
    static func opusFormat(head: Data) throws -> CMFormatDescription {
        let bytes = [UInt8](head)
        guard opusMappingFamily(head) == 0, (1...2).contains(bytes[9]) else { throw BuildError.malformed }
        let channels = Int(bytes[9])
        var description = AudioStreamBasicDescription(
            mSampleRate: 48000, mFormatID: kAudioFormatOpus, mFormatFlags: 0, mBytesPerPacket: 0, mFramesPerPacket: 0,
            mBytesPerFrame: 0, mChannelsPerFrame: UInt32(channels), mBitsPerChannel: 0, mReserved: 0)
        return try compressedFormat(
            &description, layout: channels == 1 ? kAudioChannelLayoutTag_Mono : kAudioChannelLayoutTag_Stereo, cookie: head)
    }

    /// The samples in one Opus packet at 48 kHz, from its table-of-contents
    /// byte: the frame length its configuration gives times the frame count.
    static func opusSamples(_ packet: Data) -> Int? {
        let bytes = [UInt8](packet.prefix(2))
        guard let toc = bytes.first else { return nil }
        let configuration = Int(toc >> 3)
        let length =
            switch configuration {
            case 0..<12: [480, 960, 1920, 2880][configuration % 4]
            case 12..<16: [480, 960][configuration % 2]
            default: [120, 240, 480, 960][configuration % 4]
            }
        switch toc & 0x03 {
        case 0: return length
        case 1, 2: return 2 * length
        default: return bytes.count == 2 ? length * Int(bytes[1] & 0x3F) : nil
        }
    }

    // MARK: FLAC

    /// A FLAC format from the 34-byte STREAMINFO block the container
    /// carries. The magic cookie is the body of an MP4 `dfLa` box: a
    /// version, the block's header, then the block.
    static func flacFormat(streamInfo: Data) throws -> CMFormatDescription {
        var info = [UInt8](streamInfo)
        if info.starts(with: Array("fLaC".utf8)), info.count >= 42 { info = Array(info[8..<42]) }
        guard info.count >= 34 else { throw BuildError.malformed }
        let blockSize = Int(info[2]) << 8 | Int(info[3])
        let rate = Int(info[10]) << 12 | Int(info[11]) << 4 | Int(info[12] >> 4)
        let channels = Int((info[12] >> 1) & 0x07) + 1
        let bits = Int((info[12] & 0x01) << 4 | info[13] >> 4) + 1
        guard blockSize > 0, rate > 0 else { throw BuildError.malformed }
        let flags: AudioFormatFlags =
            switch bits {
            case ...16: kAppleLosslessFormatFlag_16BitSourceData
            case ...20: kAppleLosslessFormatFlag_20BitSourceData
            case ...24: kAppleLosslessFormatFlag_24BitSourceData
            default: kAppleLosslessFormatFlag_32BitSourceData
            }
        var description = AudioStreamBasicDescription(
            mSampleRate: Float64(rate), mFormatID: kAudioFormatFLAC, mFormatFlags: flags, mBytesPerPacket: 0,
            mFramesPerPacket: UInt32(blockSize), mBytesPerFrame: 0, mChannelsPerFrame: UInt32(channels), mBitsPerChannel: 0, mReserved: 0)
        let cookie = Data([0, 0, 0, 0, 0x80, 0, 0, 34] + info.prefix(34))
        return try compressedFormat(&description, layout: waveLayouts[channels] ?? kAudioChannelLayoutTag_Stereo, cookie: cookie)
    }

    /// The speakers of each channel count in WAVE order, which FLAC and
    /// uncompressed PCM use.
    static let waveLayouts: [Int: AudioChannelLayoutTag] = [
        1: kAudioChannelLayoutTag_Mono, 2: kAudioChannelLayoutTag_Stereo, 3: kAudioChannelLayoutTag_MPEG_3_0_A,
        4: kAudioChannelLayoutTag_Quadraphonic, 5: kAudioChannelLayoutTag_MPEG_5_0_A, 6: kAudioChannelLayoutTag_MPEG_5_1_A,
        7: kAudioChannelLayoutTag_MPEG_6_1_A, 8: kAudioChannelLayoutTag_MPEG_7_1_C,
    ]

    // MARK: PCM

    /// How one sample of uncompressed PCM is stored, from FFmpeg's codec
    /// name: "pcm_s16le", "pcm_s24be", "pcm_f32le" and so on.
    struct PCMSample: Equatable {
        let bytes: Int
        let isFloat: Bool
        let isBigEndian: Bool

        init?(codec: String) {
            let shapes: [String: (Int, Bool)] = [
                "s16": (2, false), "s24": (3, false), "s32": (4, false), "f32": (4, true), "f64": (8, true),
            ]
            guard codec.hasPrefix("pcm_"), codec.count == 9, let shape = shapes[String(codec.dropFirst(4).prefix(3))] else { return nil }
            let order = codec.suffix(2)
            guard order == "le" || order == "be" else { return nil }
            (bytes, isFloat, isBigEndian) = (shape.0, shape.1, order == "be")
        }

        /// The packet's samples as floats, interleaved as they came.
        func floats(_ data: Data) -> [Float] {
            let raw = [UInt8](data)
            let count = raw.count / bytes
            var out = [Float](repeating: 0, count: count)
            for index in 0..<count {
                var word: UInt64 = 0
                for byte in 0..<bytes {
                    let value = UInt64(raw[index * bytes + (isBigEndian ? byte : bytes - 1 - byte)])
                    word = word << 8 | value
                }
                out[index] =
                    switch (bytes, isFloat) {
                    case (4, true): Float(bitPattern: UInt32(word))
                    case (8, true): Float(Double(bitPattern: word))
                    default: Float(Int64(bitPattern: word << (64 - 8 * UInt64(bytes)))) / 9_223_372_036_854_775_808
                    }
            }
            return out
        }
    }

    // MARK: AAC program config element

    /// What an AAC program config element says: the speakers, in the
    /// order the decoder gives them, and the element itself rewritten
    /// byte-aligned, as it follows the header of an AudioSpecificConfig.
    struct ProgramConfig: Equatable {
        let speakers: [AudioChannelLabel]
        let element: Data
    }

    /// Reads a program config element from `reader`, which stands just
    /// after the element's 3-bit id in a frame, or at its start in an
    /// AudioSpecificConfig.
    static func programConfig(_ reader: inout BitReader) -> ProgramConfig? {
        var writer = BitWriter()
        func copy(_ count: Int) -> Int? {
            guard let value = reader.bits(count) else { return nil }
            writer.write(value, count)
            return value
        }
        guard copy(4) != nil, copy(2) != nil, copy(4) != nil, let front = copy(4), let side = copy(4), let back = copy(4),
            let lfe = copy(2), let data = copy(3), let couplings = copy(4)
        else { return nil }
        for bits in [4, 4, 3] {
            guard let present = copy(1) else { return nil }
            if present == 1, copy(bits) == nil { return nil }
        }
        var speakers: [AudioChannelLabel] = []
        func elements(_ count: Int, single: AudioChannelLabel, pairs: [(AudioChannelLabel, AudioChannelLabel)]) -> Bool {
            var pairIndex = 0
            for _ in 0..<count {
                guard let isPair = copy(1), copy(4) != nil else { return false }
                if isPair == 1 {
                    let pair = pairs[min(pairIndex, pairs.count - 1)]
                    speakers += [pair.0, pair.1]
                    pairIndex += 1
                } else {
                    speakers.append(single)
                }
            }
            return true
        }
        let frontPairs = [
            (kAudioChannelLabel_Left, kAudioChannelLabel_Right), (kAudioChannelLabel_LeftWide, kAudioChannelLabel_RightWide),
        ]
        let sidePairs = [(kAudioChannelLabel_LeftSurroundDirect, kAudioChannelLabel_RightSurroundDirect)]
        let backPairs =
            side > 0
            ? [(kAudioChannelLabel_RearSurroundLeft, kAudioChannelLabel_RearSurroundRight)]
            : [(kAudioChannelLabel_LeftSurround, kAudioChannelLabel_RightSurround)]
        guard elements(front, single: kAudioChannelLabel_Center, pairs: frontPairs),
            elements(side, single: kAudioChannelLabel_CenterSurround, pairs: sidePairs),
            elements(back, single: kAudioChannelLabel_CenterSurround, pairs: backPairs)
        else { return nil }
        for _ in 0..<lfe {
            guard copy(4) != nil else { return nil }
            speakers.append(kAudioChannelLabel_LFEScreen)
        }
        for _ in 0..<data { guard copy(4) != nil else { return nil } }
        for _ in 0..<couplings { guard copy(5) != nil else { return nil } }
        // The comment follows a byte alignment, which is counted from the
        // start of the frame and so may differ here: skip to it there,
        // and align afresh in the copy.
        reader.align()
        writer.align()
        guard let length = copy(8) else { return nil }
        for _ in 0..<length { guard copy(8) != nil else { return nil } }
        guard !speakers.isEmpty else { return nil }
        return ProgramConfig(speakers: speakers, element: writer.data)
    }

    /// The program config element that opens an ADTS frame with channel
    /// configuration 0, nil when the frame opens with another element.
    static func programConfig(inFrame payload: Data) -> ProgramConfig? {
        var reader = BitReader([UInt8](payload.prefix(512)))
        guard reader.bits(3) == 5 else { return nil }  // ID_PCE
        return programConfig(&reader)
    }

    /// An AudioChannelLayout naming each speaker, as the bytes a format
    /// description takes.
    static func layout(speakers: [AudioChannelLabel]) -> Data {
        let header = MemoryLayout<AudioChannelLayout>.offset(of: \.mChannelDescriptions) ?? 12
        var data = Data(count: header + speakers.count * MemoryLayout<AudioChannelDescription>.stride)
        data.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress else { return }
            let layout = base.assumingMemoryBound(to: AudioChannelLayout.self)
            layout.pointee.mChannelLayoutTag = kAudioChannelLayoutTag_UseChannelDescriptions
            layout.pointee.mChannelBitmap = []
            layout.pointee.mNumberChannelDescriptions = UInt32(speakers.count)
            let descriptions = (base + header).assumingMemoryBound(to: AudioChannelDescription.self)
            for (index, label) in speakers.enumerated() {
                descriptions[index] = AudioChannelDescription(mChannelLabel: label, mChannelFlags: [], mCoordinates: (0, 0, 0))
            }
        }
        return data
    }

    // MARK: Formats

    /// A compressed format with a speaker layout and a magic cookie.
    static func compressedFormat(
        _ description: inout AudioStreamBasicDescription, layout tag: AudioChannelLayoutTag, cookie: Data
    ) throws -> CMFormatDescription {
        try compressedFormat(&description, layout: tagLayout(tag), cookie: cookie)
    }

    /// A compressed format with layout bytes, as `layout(speakers:)` makes
    /// them, and a magic cookie.
    static func compressedFormat(
        _ description: inout AudioStreamBasicDescription, layout: Data, cookie: Data
    ) throws -> CMFormatDescription {
        var format: CMAudioFormatDescription?
        let status = layout.withUnsafeBytes { layoutBytes in
            cookie.withUnsafeBytes { cookieBytes in
                CMAudioFormatDescriptionCreate(
                    allocator: nil, asbd: &description, layoutSize: layout.count,
                    layout: layoutBytes.baseAddress?.assumingMemoryBound(to: AudioChannelLayout.self),
                    magicCookieSize: cookie.count, magicCookie: cookie.isEmpty ? nil : cookieBytes.baseAddress,
                    extensions: nil, formatDescriptionOut: &format)
            }
        }
        guard status == noErr, let format else { throw BuildError.malformed }
        return format
    }
}

/// Writes bits most significant first, for rewriting a program config
/// element.
struct BitWriter {
    private(set) var data = Data()
    private var used = 0

    mutating func write(_ value: Int, _ count: Int) {
        for shift in stride(from: count - 1, through: 0, by: -1) {
            if used.isMultiple(of: 8) { data.append(0) }
            if (value >> shift) & 1 == 1 { data[data.count - 1] |= 0x80 >> UInt8(used % 8) }
            used += 1
        }
    }

    /// Pads with zero bits to the next byte.
    mutating func align() {
        used = (used + 7) / 8 * 8
    }
}
