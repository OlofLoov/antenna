import Foundation

/// Parses extended M3U playlists as emitted by IPTV providers.
///
/// Handles `#EXTM3U` header attributes (`url-tvg`, `x-tvg-url`), `#EXTINF`
/// attributes with quoted values, `#EXTGRP`, and the common catch-up tags.
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
        var index = 0

        for rawLine in text.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line.hasPrefix("#EXTM3U") {
                let attrs = Self.attributes(in: line.dropFirst("#EXTM3U".count))
                for key in ["url-tvg", "x-tvg-url"] {
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

            if line.hasPrefix("#") { continue }

            guard var entry = pending, let url = URL(string: line) else {
                pending = nil
                continue
            }
            if entry.group == nil { entry.group = groupOverride }
            index += 1
            channels.append(entry.channel(url: url, fallbackIndex: index, nameSource: nameSource))
            pending = nil
            groupOverride = nil
        }

        return Playlist(channels: channels, epgURLs: epgURLs)
    }

    // MARK: - Internals

    struct PendingEntry {
        var title: String
        var attributes: [String: String]
        var group: String?

        func channel(url: URL, fallbackIndex: Int, nameSource: NameSource = .tvgName) -> Channel {
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
                id: epgID.map { "\($0)#\(url.absoluteString)" } ?? "m3u#\(url.absoluteString)#\(fallbackIndex)",
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
                catchupCorrectionHours: attributes["catchup-correction"].flatMap(M3UParser.hours)
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

    /// A finite number of hours such as "-1.5", nil for anything else.
    static func hours(_ text: String) -> Double? {
        guard let value = Double(text.trimmingCharacters(in: .whitespaces)), value.isFinite else { return nil }
        return value
    }

    static func parseExtInf(_ body: Substring) -> PendingEntry {
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
        return PendingEntry(title: title, attributes: attrs, group: attrs["group-title"])
    }

    /// Parses `key="value"` and `key=value` pairs. Keys are lower-cased.
    static func attributes(in text: Substring) -> [String: String] {
        var result: [String: String] = [:]
        var i = text.startIndex
        while i < text.endIndex {
            // skip to key start
            while i < text.endIndex, text[i].isWhitespace || text[i].isNumber || text[i] == "-" { i = text.index(after: i) }
            guard i < text.endIndex else { break }
            let keyStart = i
            while i < text.endIndex, text[i] != "=", !text[i].isWhitespace { i = text.index(after: i) }
            guard i < text.endIndex, text[i] == "=" else { break }
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
}
