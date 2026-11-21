import Foundation

/// Finds MPEG audio (MP3, MP2) and ADTS (AAC) frames in the first bytes of a
/// stream, for internet radio served at an address with no extension.
enum AudioFrames {
    /// True when `bytes` start with an ID3 tag, or hold two frame headers
    /// in a row, the second where the first one's length puts it. A live
    /// radio stream that starts mid-frame matches at its next frame.
    static func found(in bytes: [UInt8]) -> Bool {
        if bytes.starts(with: Array("ID3".utf8)) { return true }
        var start = 0
        while start + 4 <= bytes.count {
            if let length = frameLength(bytes, at: start), start + length + 4 <= bytes.count {
                if frameLength(bytes, at: start + length) != nil { return true }
            }
            start += 1
        }
        return false
    }

    /// The length of the frame whose header starts at `index`, nil when no
    /// valid ADTS or MPEG audio header starts there.
    static func frameLength(_ bytes: [UInt8], at index: Int) -> Int? {
        guard index + 4 <= bytes.count, bytes[index] == 0xFF, bytes[index + 1] & 0xE0 == 0xE0 else { return nil }
        let second = bytes[index + 1]
        if second & 0xF6 == 0xF0 {
            // ADTS: 12 sync bits, layer 0. The frame length is 13 bits from bit 30.
            guard index + 6 <= bytes.count, (bytes[index + 2] >> 2) & 0x0F < 13 else { return nil }
            let length = (Int(bytes[index + 3] & 0x03) << 11) | (Int(bytes[index + 4]) << 3) | Int(bytes[index + 5] >> 5)
            return length >= 7 ? length : nil
        }
        let version = (second >> 3) & 0x03  // 0 MPEG 2.5, 1 reserved, 2 MPEG 2, 3 MPEG 1
        let layer = (second >> 1) & 0x03  // 1 layer III, 2 layer II, 3 layer I
        let bitrateIndex = Int(bytes[index + 2] >> 4)
        let rateIndex = Int((bytes[index + 2] >> 2) & 0x03)
        guard version != 1, layer != 0, bitrateIndex != 0, bitrateIndex != 15, rateIndex != 3 else { return nil }
        let isMPEG1 = version == 3
        let kilobits: [Int]
        switch (isMPEG1, layer) {
        case (true, 3): kilobits = [0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448]
        case (true, 2): kilobits = [0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384]
        case (true, _): kilobits = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320]
        case (false, 3): kilobits = [0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256]
        case (false, _): kilobits = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160]
        }
        let baseRates = [44100, 48000, 32000]
        let rate = baseRates[rateIndex] / (version == 3 ? 1 : version == 2 ? 2 : 4)
        let bitrate = kilobits[bitrateIndex] * 1000
        let padding = Int((bytes[index + 2] >> 1) & 0x01)
        if layer == 3 { return (12 * bitrate / rate + padding) * 4 }
        let perFrame = layer == 1 && !isMPEG1 ? 72 : 144
        return perFrame * bitrate / rate + padding
    }
}
