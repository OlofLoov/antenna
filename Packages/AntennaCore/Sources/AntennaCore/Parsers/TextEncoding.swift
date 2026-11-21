import Foundation

/// Reads text that providers save as UTF-8, UTF-16 or Windows-1252
/// (m3u-playlists/playlist-text-in-older-encodings).
public enum TextEncoding {
    /// `data` as text. A UTF-8 byte-order mark is dropped; after a UTF-16
    /// mark the rest is UTF-16; otherwise UTF-8, with each byte that starts
    /// no valid UTF-8 sequence read as Windows-1252. A file that mixes UTF-8
    /// names with Latin-1 ones keeps both.
    public static func text(_ data: Data) -> String {
        data.withUnsafeBytes { raw -> String in
            let bytes = raw.bindMemory(to: UInt8.self)
            if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { return repairedUTF8(bytes, from: 3) }
            if bytes.starts(with: [0xFF, 0xFE]) { return utf16(bytes, littleEndian: true) }
            if bytes.starts(with: [0xFE, 0xFF]) { return utf16(bytes, littleEndian: false) }
            return repairedUTF8(bytes, from: 0)
        }
    }

    /// `bytes[start...]` as UTF-8, each byte outside a valid sequence read as
    /// Windows-1252. Valid text is decoded without a copy of the bytes.
    private static func repairedUTF8(_ bytes: UnsafeBufferPointer<UInt8>, from start: Int) -> String {
        var repaired: [UInt8]?
        var copied = start
        var index = start
        while index < bytes.count {
            let byte = bytes[index]
            if byte < 0x80 {
                index += 1
                continue
            }
            let length = utf8Length(bytes, at: index)
            if length > 0 {
                index += length
                continue
            }
            if repaired == nil { repaired = []; repaired?.reserveCapacity(bytes.count - start + 64) }
            repaired?.append(contentsOf: bytes[copied..<index])
            repaired?.append(contentsOf: windows1252(byte))
            index += 1
            copied = index
        }
        guard var repaired else { return String(decoding: UnsafeBufferPointer(rebasing: bytes[start...]), as: UTF8.self) }
        repaired.append(contentsOf: bytes[copied...])
        return String(decoding: repaired, as: UTF8.self)
    }

    private static func utf16(_ bytes: UnsafeBufferPointer<UInt8>, littleEndian: Bool) -> String {
        var units: [UInt16] = []
        units.reserveCapacity(bytes.count / 2)
        var index = 2
        while index + 1 < bytes.count {
            let first = UInt16(bytes[index])
            let second = UInt16(bytes[index + 1])
            units.append(littleEndian ? first | second << 8 : first << 8 | second)
            index += 2
        }
        return String(decoding: units, as: UTF16.self)
    }

    /// The length of the well-formed UTF-8 sequence at `index`, 0 when it is not one.
    static func utf8Length(_ bytes: UnsafeBufferPointer<UInt8>, at index: Int) -> Int {
        let lead = bytes[index]
        let length: Int
        var low: UInt8 = 0x80
        var high: UInt8 = 0xBF
        switch lead {
        case 0xC2...0xDF: length = 2
        case 0xE0: (length, low) = (3, 0xA0)
        case 0xE1...0xEC, 0xEE...0xEF: length = 3
        case 0xED: (length, high) = (3, 0x9F)
        case 0xF0: (length, low) = (4, 0x90)
        case 0xF1...0xF3: length = 4
        case 0xF4: (length, high) = (4, 0x8F)
        default: return 0
        }
        guard index + length <= bytes.count else { return 0 }
        guard (low...high).contains(bytes[index + 1]) else { return 0 }
        for offset in 2..<length where !(0x80...0xBF).contains(bytes[index + offset]) { return 0 }
        return length
    }

    /// The UTF-8 bytes of `byte`, 0x80 or above, read as Windows-1252. U+FFFD
    /// where the code page has no character.
    static func windows1252(_ byte: UInt8) -> [UInt8] {
        windows1252Table[Int(byte & 0x7F)]
    }

    /// Windows-1252 code points for 0x80 to 0x9F; 0 where the code page has none.
    private static let windows1252High: [UInt32] = [
        0x20AC, 0, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0, 0x017D, 0,
        0, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0, 0x017E, 0x0178,
    ]

    /// UTF-8 for 0x80 to 0xFF read as Windows-1252, by `byte - 0x80`.
    private static let windows1252Table: [[UInt8]] = (0x80...0xFF).map { byte in
        let value = byte < 0xA0 ? windows1252High[byte - 0x80] : UInt32(byte)
        let scalar = Unicode.Scalar(value == 0 ? 0xFFFD : value) ?? "\u{FFFD}"
        return Array(String(Character(scalar)).utf8)
    }
}
