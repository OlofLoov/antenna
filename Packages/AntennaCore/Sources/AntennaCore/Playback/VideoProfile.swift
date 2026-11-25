import Foundation

/// What an HEVC decoder configuration record (hvcC) says about the
/// pictures: their profile, chroma format and bit depth.
public struct HEVCConfiguration: Sendable, Equatable {
    /// general_profile_idc: 1 Main, 2 Main 10, 4 range extensions.
    public var profile: Int
    /// 0 monochrome, 1 4:2:0, 2 4:2:2, 3 4:4:4.
    public var chromaFormat: Int
    /// Bits per luma sample, 8 or more.
    public var bitDepth: Int
    /// How many arrays of parameter sets the record lists.
    public var parameterSetArrays: Int

    /// Nil when `hvcC` is too short to be a version 1 record.
    public init?(hvcC: Data) {
        let bytes = [UInt8](hvcC)
        guard bytes.count >= 23, bytes[0] == 1 else { return nil }
        profile = Int(bytes[1] & 0x1F)
        chromaFormat = Int(bytes[16] & 0x03)
        bitDepth = Int(bytes[17] & 0x07) + 8
        parameterSetArrays = Int(bytes[22])
    }

    /// True for 4:2:0 at 8 or 10 bits, the HEVC Apple's player reads in
    /// an MP4 file. It stalls on the rest without saying why.
    public var appleReadsInFiles: Bool {
        chromaFormat == 1 && bitDepth <= 10
    }

    /// "hevc", then the chroma format when it is not 4:2:0 and the bit
    /// depth when it is above 8: "hevc 10-bit", "hevc 4:2:2 10-bit".
    public var codecName: String {
        let chroma = [0: "4:0:0", 2: "4:2:2", 3: "4:4:4"][chromaFormat]
        let depth = bitDepth > 8 ? "\(bitDepth)-bit" : nil
        return ["hevc", chroma, depth].compactMap(\.self).joined(separator: " ")
    }
}

/// The H.264 profiles beyond 8-bit 4:2:0, by name.
public enum H264Profile {
    /// "h264", with "10-bit", "4:2:2" or "4:4:4" for the High 10, High
    /// 4:2:2 and High 4:4:4 profiles named in an avcC record.
    public static func codecName(avcC: Data) -> String {
        guard avcC.count > 1 else { return "h264" }
        switch avcC[avcC.startIndex + 1] {
        case 110: return "h264 10-bit"
        case 122: return "h264 4:2:2"
        case 244, 44: return "h264 4:4:4"
        default: return "h264"
        }
    }
}
