import AntennaCore
import AudioToolbox
import CoreMedia
import Foundation

extension SampleBuilder {
    // MARK: H.264

    /// An H.264 NAL unit's type, from its first byte.
    static func h264Type(_ unit: Data) -> Int? {
        unit.first.map { Int($0 & 0x1F) }
    }

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

    // MARK: HEVC

    /// An HEVC NAL unit's type, from the first byte of its header.
    static func hevcType(_ unit: Data) -> Int? {
        unit.first.map { Int(($0 >> 1) & 0x3F) }
    }

    /// The VPS, SPS and PPS listed in an hvcC configuration record.
    static func hevcParameterSets(hvcC: Data) throws -> [Data] {
        let bytes = [UInt8](hvcC)
        guard bytes.count > 23 else { throw BuildError.malformed }
        var index = 23
        var found: [Int: Data] = [:]
        for _ in 0..<Int(bytes[22]) {
            guard index + 3 <= bytes.count else { throw BuildError.malformed }
            let type = Int(bytes[index] & 0x3F)
            let count = Int(bytes[index + 1]) << 8 | Int(bytes[index + 2])
            index += 3
            for _ in 0..<count {
                guard index + 2 <= bytes.count else { throw BuildError.malformed }
                let length = Int(bytes[index]) << 8 | Int(bytes[index + 1])
                index += 2
                guard index + length <= bytes.count else { throw BuildError.malformed }
                if found[type] == nil { found[type] = Data(bytes[index..<(index + length)]) }
                index += length
            }
        }
        let sets = [32, 33, 34].compactMap { found[$0] }
        guard sets.count == 3 else { throw BuildError.malformed }
        return sets
    }

    /// An HEVC format from its VPS, SPS and PPS. CoreMedia reads the
    /// color description in the SPS into the format's extensions.
    static func hevcFormat(parameterSets sets: [Data]) throws -> CMFormatDescription {
        var format: CMFormatDescription?
        let pointers = sets.map { set in
            let copy = UnsafeMutablePointer<UInt8>.allocate(capacity: set.count)
            set.copyBytes(to: copy, count: set.count)
            return UnsafePointer(copy)
        }
        defer { pointers.forEach { $0.deallocate() } }
        let status = CMVideoFormatDescriptionCreateFromHEVCParameterSets(
            allocator: nil, parameterSetCount: sets.count, parameterSetPointers: pointers,
            parameterSetSizes: sets.map(\.count), nalUnitHeaderLength: 4, extensions: nil, formatDescriptionOut: &format)
        guard status == noErr, let format else { throw BuildError.malformed }
        return format
    }

    /// The dynamic range a video format's transfer function says.
    static func dynamicRange(of format: CMFormatDescription) -> PresentationInfo.DynamicRange {
        let transfer = CMFormatDescriptionGetExtension(format, extensionKey: kCMFormatDescriptionExtension_TransferFunction)
        guard let transfer = transfer as? String else { return .sdr }
        if transfer == kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ as String { return .hdr10 }
        if transfer == kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG as String { return .hlg }
        return .sdr
    }

    // MARK: MPEG-4 Part 2 and MP3

    /// MPEG-4 Part 2 video described by an `esds` wrapping the stream's
    /// configuration (its VOL header), the form VideoToolbox reads.
    static func mpeg4VideoFormat(config: Data, width: Int, height: Int) throws -> CMFormatDescription {
        guard !config.isEmpty, width > 0, height > 0 else { throw BuildError.malformed }
        let extensions: [CFString: Any] = [
            // As an atom, esds is a full box: version and flags come first.
            kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms: [
                "esds": Data(count: 4) + esds(config: config, objectType: 0x20, streamType: 0x11)
            ]
        ]
        var format: CMFormatDescription?
        let status = CMVideoFormatDescriptionCreate(
            allocator: nil, codecType: kCMVideoCodecType_MPEG4Video, width: Int32(width), height: Int32(height),
            extensions: extensions as CFDictionary, formatDescriptionOut: &format)
        guard status == noErr, let format else { throw BuildError.malformed }
        return format
    }

    /// The configuration in front of an MPEG-4 Part 2 frame: everything
    /// before its first picture start code (00 00 01 B6), nil when the frame
    /// starts with the picture.
    static func mpeg4Config(inFrame data: Data) -> Data? {
        let bytes = [UInt8](data)
        guard bytes.count > 4 else { return nil }
        let pictureStart: [UInt8] = [0, 0, 1, 0xB6]
        for index in 0..<(bytes.count - 3) where Array(bytes[index..<(index + 4)]) == pictureStart {
            return index > 0 ? Data(bytes[0..<index]) : nil
        }
        return nil
    }
}
