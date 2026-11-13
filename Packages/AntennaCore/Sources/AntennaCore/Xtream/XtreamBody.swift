import Foundation

/// Cleans a panel's JSON body before it is decoded
/// (xtream-vod-client/panel-bodies-that-are-almost-json). Panels built on
/// PHP send bodies that `JSONDecoder` refuses: a PHP notice printed before
/// the JSON, text after it, plots saved in Latin-1 or Windows-1252, and
/// tabs or line breaks typed straight into a string. A body with none of
/// these comes back as it was, without a copy.
enum XtreamBody {
    /// The body with a leading byte-order mark and PHP notice removed, text
    /// after the top-level value removed, bytes that are not UTF-8 read as
    /// Windows-1252, and control characters inside strings escaped. A
    /// prefix holding `<html` or `<!doctype` is a web page and is kept,
    /// so it still fails to decode.
    static func readable(_ data: Data) -> Data {
        data.withUnsafeBytes { buffer -> Data in
            let bytes = buffer.bindMemory(to: UInt8.self)
            let start = valueStart(bytes)
            var writer = Writer(bytes: bytes, start: start)
            let end = walk(bytes, from: start, into: &writer)
            if let out = writer.out { return Data(out) }
            if start == 0 && end == bytes.count { return data }
            return Data(bytes[start..<end])
        }
    }

    /// Copies nothing until the first byte that needs changing, then
    /// everything from `start` on.
    private struct Writer {
        let bytes: UnsafeBufferPointer<UInt8>
        let start: Int
        var out: [UInt8]?

        mutating func change(at index: Int, to replacement: [UInt8]) {
            if out == nil { out = Array(bytes[start..<index]) }
            out?.append(contentsOf: replacement)
        }

        mutating func keep(_ index: Int, count: Int = 1) {
            out?.append(contentsOf: bytes[index..<index + count])
        }
    }

    private static let whitespace: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0D]

    /// Where the JSON value starts: after a byte-order mark, and after a
    /// PHP notice when the body does not start like JSON.
    private static func valueStart(_ bytes: UnsafeBufferPointer<UInt8>) -> Int {
        var index = bytes.starts(with: [0xEF, 0xBB, 0xBF]) ? 3 : 0
        let afterMark = index
        while index < bytes.count, whitespace.contains(bytes[index]) { index += 1 }
        guard index < bytes.count else { return afterMark }
        let first = bytes[index]
        let startsLikeJSON = "{[\"-0123456789tfn".utf8.contains(first)
        if startsLikeJSON { return afterMark }
        guard let open = bytes[index...].firstIndex(where: { $0 == UInt8(ascii: "{") || $0 == UInt8(ascii: "[") }) else {
            return afterMark
        }
        let prefix = String(decoding: bytes[index..<open], as: UTF8.self).lowercased()
        if prefix.contains("<html") || prefix.contains("<!doctype") { return afterMark }
        return open
    }

    /// Walks the value from `start`, handing repairs to `writer`. Returns
    /// where the value ends.
    private static func walk(_ bytes: UnsafeBufferPointer<UInt8>, from start: Int, into writer: inout Writer) -> Int {
        var index = start
        var inString = false
        var escaped = false
        var depth = 0
        var opened = false
        while index < bytes.count {
            let byte = bytes[index]
            if byte >= 0x80 {
                let length = utf8Length(bytes, at: index)
                if length > 0 {
                    writer.keep(index, count: length)
                    index += length
                } else {
                    writer.change(at: index, to: windows1252(byte))
                    index += 1
                }
                escaped = false
                continue
            }
            if inString {
                if escaped {
                    escaped = false
                } else if byte == UInt8(ascii: "\\") {
                    escaped = true
                } else if byte == UInt8(ascii: "\"") {
                    inString = false
                } else if byte < 0x20 {
                    writer.change(at: index, to: Array(String(format: "\\u%04x", byte).utf8))
                    index += 1
                    continue
                }
                writer.keep(index)
                index += 1
                continue
            }
            switch byte {
            case UInt8(ascii: "\""):
                inString = true
            case UInt8(ascii: "{"), UInt8(ascii: "["):
                depth += 1
                opened = true
            case UInt8(ascii: "}"), UInt8(ascii: "]"):
                depth -= 1
            case _ where byte < 0x20 && !whitespace.contains(byte):
                writer.change(at: index, to: [])
                index += 1
                continue
            default:
                break
            }
            writer.keep(index)
            index += 1
            if opened && depth == 0 {
                let rest = bytes[index...]
                if rest.allSatisfy(whitespace.contains) { return bytes.count }
                return index
            }
        }
        return bytes.count
    }

    /// The length of the well-formed UTF-8 sequence at `index`, 0 when it is not one.
    private static func utf8Length(_ bytes: UnsafeBufferPointer<UInt8>, at index: Int) -> Int {
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

    /// Windows-1252 code points for 0x80 to 0x9F; 0 where the code page has none.
    private static let windows1252High: [UInt32] = [
        0x20AC, 0, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0, 0x017D, 0,
        0, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0, 0x017E, 0x0178,
    ]

    /// The UTF-8 bytes of `byte` read as Windows-1252, U+FFFD where the code page has no character.
    private static func windows1252(_ byte: UInt8) -> [UInt8] {
        let value = byte < 0xA0 ? windows1252High[Int(byte - 0x80)] : UInt32(byte)
        let scalar = Unicode.Scalar(value == 0 ? 0xFFFD : value) ?? "\u{FFFD}"
        return Array(String(Character(scalar)).utf8)
    }
}
