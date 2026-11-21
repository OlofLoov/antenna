import Foundation

/// Parses extended M3U playlists as emitted by IPTV providers.
///
/// Handles `#EXTM3U` header attributes (`url-tvg`, `x-tvg-url`, `tvg-url`), `#EXTINF`
/// attributes with quoted values, `#EXTGRP`, the common catch-up tags, and the
/// stream headers of `#EXTVLCOPT`, `#EXTHTTP`, `#KODIPROP` and Kodi's `link|headers`.
/// Unknown directives are ignored. Parsing is line-based and allocation-light,
/// so playlists with tens of thousands of entries stay fast.
public struct M3UParser: Sendable {
    /// Where a channel's name comes from.
    public enum NameSource: Sendable {
        /// `tvg-name`, then the title after the comma when it is absent or empty.
        case tvgName
        /// The title after the comma, then `tvg-name` when the title is empty
        /// (m3u-playlists/title-first-channel-names).
        case title
    }

    public var nameSource: NameSource

    public init(nameSource: NameSource = .tvgName) {
        self.nameSource = nameSource
    }

    /// A byte-order mark at the start of `text` is ignored.
    public func parse(_ text: String) -> Playlist {
        var text = Substring(text)
        if text.unicodeScalars.first == "\u{FEFF}" {
            text = Substring(text.unicodeScalars.dropFirst())
        }
        var channels: [Channel] = []
        channels.reserveCapacity(text.utf8.count / 120)

        var epgURLs: [URL] = []
        var pending: PendingEntry?
        var groupOverride: String?
        var headers = StreamHeaders()
        var index = 0
        var ids = M3UChannelIDs(capacity: text.utf8.count / 120)

        for rawLine in Self.lines(text) {
            let line = Self.trimmedLine(rawLine)
            if line.isEmpty { continue }

            if line.hasPrefix("#EXTM3U") {
                let attrs = Self.attributes(in: line.dropFirst("#EXTM3U".count))
                for key in ["url-tvg", "x-tvg-url", "tvg-url"] {
                    if let value = attrs[key] {
                        epgURLs += value.split(separator: ",").compactMap { URL(string: String($0).trimmingCharacters(in: .whitespaces)) }
                    }
                }
                continue
            }

            if line.hasPrefix("#EXTINF:") {
                pending = Self.parseExtInf(line.dropFirst("#EXTINF:".count))
                continue
            }

            if line.hasPrefix("#EXTGRP:") {
                groupOverride = String(line.dropFirst("#EXTGRP:".count)).trimmingCharacters(in: .whitespaces)
                continue
            }

            if line.hasPrefix("#") {
                Self.readHeaders(line, into: &headers)
                continue
            }

            let link = Self.splitLink(line)
            defer { headers = StreamHeaders() }
            guard var entry = pending, let url = URL(string: link.address) else {
                pending = nil
                continue
            }
            if entry.group == nil { entry.group = groupOverride }
            index += 1
            var channel = entry.channel(url: url, nameSource: nameSource)
            let streamHeaders = entry.headers.merging(headers).merging(link.headers)
            channel.headers = streamHeaders.isEmpty ? nil : streamHeaders
            channel.id = ids.next(for: channel, formerID: Self.formerID(channel, position: index))
            channels.append(channel)
            pending = nil
            groupOverride = nil
        }

        return Playlist(channels: channels, epgURLs: epgURLs, formerIDs: ids.formerIDs)
    }

    // MARK: - Internals

    struct PendingEntry: Equatable {
        var title: String
        var attributes: [String: String]
        var group: String?
        /// The number before the attributes, nil when it is not one.
        var duration: Double?

        /// The `user-agent` and `http-user-agent` attributes as headers.
        var headers: StreamHeaders {
            var headers = StreamHeaders()
            for name in ["http-user-agent", "user-agent"] {
                if let value = attributes[name] { headers.set("User-Agent", value) }
            }
            return headers
        }

        /// The channel with an empty id; `parse` gives it one.
        func channel(url: URL, nameSource: NameSource = .tvgName) -> Channel {
            let tvgName = attributes["tvg-name"].flatMap { $0.isEmpty ? nil : $0 }
            let name =
                switch nameSource {
                case .tvgName: tvgName ?? title
                case .title: title.isEmpty ? tvgName ?? "" : title
                }
            let number = attributes["tvg-chno"].flatMap(M3UParser.channelNumber)
            let epgID = attributes["tvg-id"].flatMap { $0.isEmpty ? nil : $0 }
            let catchup = attributes["catchup"] ?? attributes["tvg-rec"]
            let catchupDays = (attributes["catchup-days"] ?? attributes["tvg-rec"]).flatMap(Int.init)
            return Channel(
                id: "",
                name: name,
                streamURL: url,
                group: group,
                logoURL: attributes["tvg-logo"].flatMap(URL.init(string:)),
                epgID: epgID,
                number: number?.major,
                minorNumber: number?.minor,
                hasCatchup: catchup != nil && catchup != "0",
                catchupDays: catchupDays,
                catchupMode: attributes["catchup"].flatMap(CatchupMode.init(attribute:)),
                catchupSource: attributes["catchup-source"].flatMap { $0.isEmpty ? nil : $0 },
                catchupCorrectionHours: attributes["catchup-correction"].flatMap(M3UParser.hours),
                duration: duration
            )
        }
    }

    /// "104" as 104 with no minor number, "6.1" as 6 and 1
    /// (m3u-playlists/minor-channel-numbers). Nil for anything else.
    static func channelNumber(_ text: String) -> (major: Int, minor: Int?)? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ".", omittingEmptySubsequences: false)
        let digits = parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }
        guard digits, let major = Int(parts[0]) else { return nil }
        switch parts.count {
        case 1: return (major, nil)
        case 2: return Int(parts[1]).map { (major, $0) }
        default: return nil
        }
    }

    /// The id earlier versions gave the entry: `<tvg-id>#<link>`, or
    /// `m3u#<link>#<position>` counting from 1. It can hold a login, so it
    /// is only ever a key in `Playlist.formerIDs`.
    static func formerID(_ channel: Channel, position: Int) -> String {
        channel.epgID.map { "\($0)#\(channel.streamURL.absoluteString)" } ?? "m3u#\(channel.streamURL.absoluteString)#\(position)"
    }

    /// A finite number of hours such as "-1.5", nil for anything else.
    static func hours(_ text: String) -> Double? {
        guard let value = Double(text.trimmingCharacters(in: .whitespaces)), value.isFinite else { return nil }
        return value
    }

    static func parseExtInf(_ body: Substring) -> PendingEntry {
        body.utf8.allSatisfy({ $0 < 0x80 }) ? parseASCIIExtInf(body) : parseCharacterExtInf(body)
    }

    /// `parseExtInf` for any body, read Character by Character.
    static func parseCharacterExtInf(_ body: Substring) -> PendingEntry {
        // Format: <duration> [key="value" ...],<title>
        // The title is everything after the first comma that follows the attribute block.
        var attrEnd = body.startIndex
        var inQuotes = false
        var titleStart: Substring.Index?
        var i = body.startIndex
        while i < body.endIndex {
            let c = body[i]
            if c == "\"" { inQuotes.toggle() }
            if c == "," && !inQuotes {
                attrEnd = i
                titleStart = body.index(after: i)
                break
            }
            i = body.index(after: i)
        }
        let attrPart = body[body.startIndex..<attrEnd]
        let title = titleStart.map { String(body[$0...]).trimmingCharacters(in: .whitespaces) } ?? ""
        let attrs = attributes(in: attrPart)
        let number = attrPart.drop { $0.isWhitespace }.prefix { !$0.isWhitespace && $0 != "," }
        let duration = Double(number).flatMap { $0.isFinite ? $0 : nil }
        return PendingEntry(title: title, attributes: attrs, group: attrs["group-title"], duration: duration)
    }

    /// Parses `key="value"` and `key=value` pairs, skipping words without
    /// `=`. Keys are lower-cased.
    static func attributes(in text: Substring) -> [String: String] {
        var result: [String: String] = [:]
        var i = text.startIndex
        while i < text.endIndex {
            // skip to key start
            while i < text.endIndex, text[i].isWhitespace || text[i].isNumber || text[i] == "-" { i = text.index(after: i) }
            guard i < text.endIndex else { break }
            let keyStart = i
            while i < text.endIndex, text[i] != "=", !text[i].isWhitespace { i = text.index(after: i) }
            // A word with no `=` is skipped (m3u-playlists/standard-attributes-map-to-the-channel).
            guard i < text.endIndex else { break }
            guard text[i] == "=" else { continue }
            let key = text[keyStart..<i].lowercased()
            i = text.index(after: i)
            guard i < text.endIndex else { break }
            let value: Substring
            if text[i] == "\"" {
                i = text.index(after: i)
                let valueStart = i
                while i < text.endIndex, text[i] != "\"" { i = text.index(after: i) }
                value = text[valueStart..<i]
                if i < text.endIndex { i = text.index(after: i) }
            } else {
                let valueStart = i
                while i < text.endIndex, !text[i].isWhitespace { i = text.index(after: i) }
                value = text[valueStart..<i]
            }
            result[key] = String(value)
        }
        return result
    }

    // MARK: - ASCII lines

    // In ASCII text every byte is a Character, so these read bytes and give
    // what `parseExtInf` and `attributes(in:)` give, without breaking the
    // text into Characters. Character.isWhitespace holds for 0x09 to 0x0D
    // and space, Character.isNumber for the digits, and
    // CharacterSet.whitespaces for tab and space.

    private static func isASCIIWhitespace(_ byte: UInt8) -> Bool { byte == 0x20 || (0x09...0x0D).contains(byte) }

    private static func isASCIIDigit(_ byte: UInt8) -> Bool { (0x30...0x39).contains(byte) }

    /// `parseExtInf` for a body that is all ASCII.
    static func parseASCIIExtInf(_ body: Substring) -> PendingEntry {
        let bytes = body.utf8
        var attrEnd = bytes.startIndex
        var inQuotes = false
        var titleStart: Substring.Index?
        var i = bytes.startIndex
        while i < bytes.endIndex {
            let byte = bytes[i]
            if byte == UInt8(ascii: "\"") { inQuotes.toggle() }
            if byte == UInt8(ascii: ","), !inQuotes {
                attrEnd = i
                titleStart = bytes.index(after: i)
                break
            }
            bytes.formIndex(after: &i)
        }
        let attrPart = body[body.startIndex..<attrEnd]
        let title = titleStart.map { trimmedASCII(body[$0...]) } ?? ""
        let attrs = asciiAttributes(in: attrPart)
        let digits = attrPart.utf8.drop(while: isASCIIWhitespace).prefix { !isASCIIWhitespace($0) && $0 != UInt8(ascii: ",") }
        let number = attrPart[digits.startIndex..<digits.endIndex]
        let duration = Double(number).flatMap { $0.isFinite ? $0 : nil }
        return PendingEntry(title: title, attributes: attrs, group: attrs["group-title"], duration: duration)
    }

    /// `text` without leading and trailing tabs and spaces, as
    /// `trimmingCharacters(in: .whitespaces)` gives for ASCII.
    private static func trimmedASCII(_ text: Substring) -> String {
        let bytes = text.utf8
        guard let first = bytes.firstIndex(where: { $0 != 0x20 && $0 != 0x09 }) else { return "" }
        let last = bytes.lastIndex { $0 != 0x20 && $0 != 0x09 } ?? first
        return String(text[first...last])
    }

    /// `attributes(in:)` for text that is all ASCII.
    static func asciiAttributes(in text: Substring) -> [String: String] {
        let bytes = text.utf8
        var result: [String: String] = [:]
        var i = bytes.startIndex
        while i < bytes.endIndex {
            while i < bytes.endIndex, isASCIIWhitespace(bytes[i]) || isASCIIDigit(bytes[i]) || bytes[i] == UInt8(ascii: "-") {
                bytes.formIndex(after: &i)
            }
            guard i < bytes.endIndex else { break }
            let keyStart = i
            while i < bytes.endIndex, bytes[i] != UInt8(ascii: "="), !isASCIIWhitespace(bytes[i]) { bytes.formIndex(after: &i) }
            guard i < bytes.endIndex else { break }
            guard bytes[i] == UInt8(ascii: "=") else { continue }
            let key = text[keyStart..<i].lowercased()
            bytes.formIndex(after: &i)
            guard i < bytes.endIndex else { break }
            let value: Substring
            if bytes[i] == UInt8(ascii: "\"") {
                bytes.formIndex(after: &i)
                let valueStart = i
                while i < bytes.endIndex, bytes[i] != UInt8(ascii: "\"") { bytes.formIndex(after: &i) }
                value = text[valueStart..<i]
                if i < bytes.endIndex { bytes.formIndex(after: &i) }
            } else {
                let valueStart = i
                while i < bytes.endIndex, !isASCIIWhitespace(bytes[i]) { bytes.formIndex(after: &i) }
                value = text[valueStart..<i]
            }
            result[key] = String(value)
        }
        return result
    }

    /// The lines of `text`, empty ones left out, split where
    /// `Character.isNewline` holds: LF, VT, FF, CR, CR LF, NEL, U+2028 and
    /// U+2029. Each of those is a Character of its own, so splitting on
    /// their bytes gives the lines splitting on Characters gives.
    static func lines(_ text: Substring) -> [Substring] {
        let bytes = text.utf8
        var result: [Substring] = []
        var lineStart = bytes.startIndex
        var i = bytes.startIndex
        while i < bytes.endIndex {
            var width = 0
            switch bytes[i] {
            case 0x0A...0x0D:
                width = 1
            case 0xC2:
                let next = bytes.index(after: i)
                if next < bytes.endIndex, bytes[next] == 0x85 { width = 2 }
            case 0xE2:
                let second = bytes.index(after: i)
                if second < bytes.endIndex, bytes[second] == 0x80 {
                    let third = bytes.index(after: second)
                    if third < bytes.endIndex, bytes[third] == 0xA8 || bytes[third] == 0xA9 { width = 3 }
                }
            default:
                break
            }
            guard width > 0 else {
                bytes.formIndex(after: &i)
                continue
            }
            if lineStart < i { result.append(text[lineStart..<i]) }
            i = bytes.index(i, offsetBy: width)
            lineStart = i
        }
        if lineStart < bytes.endIndex { result.append(text[lineStart..<bytes.endIndex]) }
        return result
    }

    /// `line.trimmingCharacters(in: .whitespaces)`, skipping Foundation
    /// when the first and last bytes are ASCII other than tab and space,
    /// so there is nothing to trim.
    static func trimmedLine(_ line: Substring) -> String {
        func kept(_ byte: UInt8?) -> Bool { byte.map { $0 < 0x80 && $0 != 0x20 && $0 != 0x09 } ?? false }
        return kept(line.utf8.first) && kept(line.utf8.last) ? String(line) : line.trimmingCharacters(in: .whitespaces)
    }
}
