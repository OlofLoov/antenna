import Foundation

/// Rewrites the two entity mistakes common in provider XMLTV so that
/// `XMLParser`, which cannot resume after a fatal error, reads the guide:
/// a `&` that starts no valid XML reference becomes `&amp;`, and a known HTML
/// named entity such as `&nbsp;` becomes a numeric character reference.
///
/// Input that needs neither rewrite is returned unchanged, byte for byte.
/// CDATA sections, comments, processing instructions and the DOCTYPE are
/// copied as they are. A document whose DOCTYPE declares entities
/// (`<!ENTITY`) or that starts with a UTF-16 byte order mark is returned
/// unchanged.
enum XMLEntitySanitizer {
    static func sanitize(_ data: Data) -> Data {
        guard !data.isEmpty, !startsWithUTF16BOM(data) else { return data }
        return data.withUnsafeBytes { raw -> Data in
            let bytes = raw.bindMemory(to: UInt8.self)
            var output: Data?
            var copiedUpTo = 0
            var i = 0

            func replace(upTo end: Int, resumeAt resume: Int, with replacement: String) {
                if output == nil {
                    output = Data(capacity: bytes.count + bytes.count / 64)
                }
                output?.append(UnsafeBufferPointer(rebasing: bytes[copiedUpTo..<end]))
                output?.append(contentsOf: Array(replacement.utf8))
                copiedUpTo = resume
            }

            while i < bytes.count {
                switch bytes[i] {
                case ascii("<"):
                    guard let next = skipMarkup(bytes, at: i) else { return data }
                    i = next
                case ascii("&"):
                    switch scanReference(bytes, at: i) {
                    case .valid(let end):
                        i = end
                    case .html(let end, let scalar):
                        replace(upTo: i, resumeAt: end, with: "&#\(scalar);")
                        i = end
                    case .stray:
                        replace(upTo: i, resumeAt: i + 1, with: "&amp;")
                        i += 1
                    }
                default:
                    i += 1
                }
            }

            guard var result = output else { return data }
            result.append(UnsafeBufferPointer(rebasing: bytes[copiedUpTo..<bytes.count]))
            return result
        }
    }

    private enum Reference {
        case valid(end: Int)
        case html(end: Int, scalar: Int)
        case stray
    }

    private static let maxNameLength = 32

    private static func scanReference(_ bytes: UnsafeBufferPointer<UInt8>, at start: Int) -> Reference {
        var cursor = start + 1
        while cursor < bytes.count, cursor - start <= maxNameLength, isNameByte(bytes[cursor], first: cursor == start + 1) {
            cursor += 1
        }
        guard cursor < bytes.count, bytes[cursor] == ascii(";"), cursor > start + 1 else { return .stray }
        let name = bytes[(start + 1)..<cursor]
        let end = cursor + 1
        if isValidXMLReference(name) { return .valid(end: end) }
        if let scalar = htmlEntities[String(decoding: name, as: UTF8.self)] { return .html(end: end, scalar: scalar) }
        return .stray
    }

    private static func isNameByte(_ byte: UInt8, first: Bool) -> Bool {
        isASCIIAlphanumeric(byte) || (first && byte == ascii("#"))
    }

    /// True for the five predefined entities and for character references
    /// to a code point XML allows.
    private static func isValidXMLReference(_ name: Slice<UnsafeBufferPointer<UInt8>>) -> Bool {
        guard let first = name.first else { return false }
        guard first == ascii("#") else { return xmlEntityNames.contains(String(decoding: name, as: UTF8.self)) }
        let rest = name.dropFirst()
        let isHex = rest.first == ascii("x")
        let digits = isHex ? rest.dropFirst() : rest
        guard !digits.isEmpty, digits.count <= 8,
            digits.allSatisfy(isHex ? isASCIIHexDigit : isASCIIDigit),
            let value = Int(String(decoding: digits, as: UTF8.self), radix: isHex ? 16 : 10)
        else { return false }
        return isXMLChar(value)
    }

    private static func isXMLChar(_ value: Int) -> Bool {
        switch value {
        case 0x9, 0xA, 0xD, 0x20...0xD7FF, 0xE000...0xFFFD, 0x10000...0x10FFFF: true
        default: false
        }
    }

    /// Returns the index after a CDATA section, comment, processing
    /// instruction or DOCTYPE that starts at `start`, or `start + 1` when none
    /// starts there. Returns nil when the DOCTYPE declares entities.
    private static func skipMarkup(_ bytes: UnsafeBufferPointer<UInt8>, at start: Int) -> Int? {
        if hasPrefix(bytes, at: start, cdataOpen) {
            return indexAfter(cdataClose, in: bytes, from: start + cdataOpen.count)
        }
        if hasPrefix(bytes, at: start, commentOpen) {
            return indexAfter(commentClose, in: bytes, from: start + commentOpen.count)
        }
        if hasPrefix(bytes, at: start, processingOpen) {
            return indexAfter(processingClose, in: bytes, from: start + processingOpen.count)
        }
        if hasPrefix(bytes, at: start, doctypeOpen) {
            return skipDoctype(bytes, from: start + doctypeOpen.count)
        }
        return start + 1
    }

    /// Skips to the `>` that closes the DOCTYPE, past quoted literals and an
    /// internal subset in brackets. Returns nil when the subset declares an
    /// entity.
    private static func skipDoctype(_ bytes: UnsafeBufferPointer<UInt8>, from start: Int) -> Int? {
        var index = start
        var quote: UInt8?
        var subsetStart: Int?
        while index < bytes.count {
            let byte = bytes[index]
            if let open = quote {
                if byte == open { quote = nil }
            } else if byte == ascii("\"") || byte == ascii("'") {
                quote = byte
            } else if byte == ascii("["), subsetStart == nil {
                subsetStart = index
            } else if byte == ascii("<"), subsetStart != nil, hasPrefix(bytes, at: index, entityOpen) {
                return nil
            } else if byte == ascii(">") {
                guard let subset = subsetStart else { return index + 1 }
                if isSubsetClosed(bytes, from: subset, to: index) { return index + 1 }
            }
            index += 1
        }
        return bytes.count
    }

    /// True when the last non-space byte before `end` is the `]` that closes
    /// the internal subset opened at `subset`.
    private static func isSubsetClosed(_ bytes: UnsafeBufferPointer<UInt8>, from subset: Int, to end: Int) -> Bool {
        var index = end - 1
        while index > subset, isXMLSpace(bytes[index]) { index -= 1 }
        return index > subset && bytes[index] == ascii("]")
    }

    private static func isXMLSpace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
    }

    private static let cdataOpen = Array("<![CDATA[".utf8)
    private static let cdataClose = Array("]]>".utf8)
    private static let commentOpen = Array("<!--".utf8)
    private static let commentClose = Array("-->".utf8)
    private static let processingOpen = Array("<?".utf8)
    private static let processingClose = Array("?>".utf8)
    private static let doctypeOpen = Array("<!DOCTYPE".utf8)
    private static let entityOpen = Array("<!ENTITY".utf8)

    private static func hasPrefix(_ bytes: UnsafeBufferPointer<UInt8>, at start: Int, _ prefix: [UInt8]) -> Bool {
        guard start + prefix.count <= bytes.count else { return false }
        for offset in 0..<prefix.count where bytes[start + offset] != prefix[offset] { return false }
        return true
    }

    private static func indexAfter(_ terminator: [UInt8], in bytes: UnsafeBufferPointer<UInt8>, from start: Int) -> Int {
        var index = start
        while index + terminator.count <= bytes.count {
            if hasPrefix(bytes, at: index, terminator) { return index + terminator.count }
            index += 1
        }
        return bytes.count
    }

    private static func startsWithUTF16BOM(_ data: Data) -> Bool {
        guard data.count >= 2 else { return false }
        let first = data[data.startIndex]
        let second = data[data.startIndex + 1]
        return (first == 0xFE && second == 0xFF) || (first == 0xFF && second == 0xFE)
    }

    private static func ascii(_ character: Unicode.Scalar) -> UInt8 { UInt8(character.value) }
    private static func isASCIIDigit(_ byte: UInt8) -> Bool { byte >= 0x30 && byte <= 0x39 }
    private static func isASCIIHexDigit(_ byte: UInt8) -> Bool {
        isASCIIDigit(byte) || (byte >= 0x41 && byte <= 0x46) || (byte >= 0x61 && byte <= 0x66)
    }
    private static func isASCIIAlphanumeric(_ byte: UInt8) -> Bool {
        isASCIIDigit(byte) || (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A)
    }

    private static let xmlEntityNames: Set<String> = ["amp", "lt", "gt", "quot", "apos"]

    /// HTML named entities seen in EPG text: the Latin-1 supplement
    /// (U+00A0 to U+00FF) plus common punctuation and a few Latin Extended-A
    /// letters.
    private static let htmlEntities: [String: Int] = {
        let latin1 = [
            "nbsp", "iexcl", "cent", "pound", "curren", "yen", "brvbar", "sect", "uml", "copy", "ordf", "laquo", "not",
            "shy", "reg", "macr", "deg", "plusmn", "sup2", "sup3", "acute", "micro", "para", "middot", "cedil", "sup1",
            "ordm", "raquo", "frac14", "frac12", "frac34", "iquest", "Agrave", "Aacute", "Acirc", "Atilde", "Auml",
            "Aring", "AElig", "Ccedil", "Egrave", "Eacute", "Ecirc", "Euml", "Igrave", "Iacute", "Icirc", "Iuml", "ETH",
            "Ntilde", "Ograve", "Oacute", "Ocirc", "Otilde", "Ouml", "times", "Oslash", "Ugrave", "Uacute", "Ucirc",
            "Uuml", "Yacute", "THORN", "szlig", "agrave", "aacute", "acirc", "atilde", "auml", "aring", "aelig",
            "ccedil", "egrave", "eacute", "ecirc", "euml", "igrave", "iacute", "icirc", "iuml", "eth", "ntilde",
            "ograve", "oacute", "ocirc", "otilde", "ouml", "divide", "oslash", "ugrave", "uacute", "ucirc", "uuml",
            "yacute", "thorn", "yuml",
        ]
        var table: [String: Int] = [:]
        for (offset, name) in latin1.enumerated() { table[name] = 0xA0 + offset }
        let others: [String: Int] = [
            "OElig": 0x152, "oelig": 0x153, "Scaron": 0x160, "scaron": 0x161, "Yuml": 0x178, "Zcaron": 0x17D,
            "zcaron": 0x17E, "ndash": 0x2013, "mdash": 0x2014, "lsquo": 0x2018, "rsquo": 0x2019, "sbquo": 0x201A,
            "ldquo": 0x201C, "rdquo": 0x201D, "bdquo": 0x201E, "dagger": 0x2020, "bull": 0x2022, "hellip": 0x2026,
            "permil": 0x2030, "lsaquo": 0x2039, "rsaquo": 0x203A, "euro": 0x20AC, "trade": 0x2122,
        ]
        table.merge(others) { current, _ in current }
        return table
    }()
}
