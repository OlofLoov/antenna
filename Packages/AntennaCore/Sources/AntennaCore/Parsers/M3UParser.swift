import Foundation

/// Parses extended M3U playlists as emitted by IPTV providers.
///
/// Handles `#EXTM3U` header attributes (`url-tvg`, `x-tvg-url`), `#EXTINF`
/// attributes with quoted values, `#EXTGRP`, and the common catch-up tags.
/// Unknown directives are ignored. Parsing is line-based and allocation-light,
/// so playlists with tens of thousands of entries stay fast.
public struct M3UParser: Sendable {
    public init() {}

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
            channels.append(entry.channel(url: url, fallbackIndex: index))
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

        func channel(url: URL, fallbackIndex: Int) -> Channel {
            let epgID = attributes["tvg-id"].flatMap { $0.isEmpty ? nil : $0 }
            let catchup = attributes["catchup"] ?? attributes["tvg-rec"]
            let catchupDays = (attributes["catchup-days"] ?? attributes["tvg-rec"]).flatMap(Int.init)
            return Channel(
                id: epgID.map { "\($0)#\(url.absoluteString)" } ?? "m3u#\(url.absoluteString)#\(fallbackIndex)",
                name: attributes["tvg-name"].flatMap { $0.isEmpty ? nil : $0 } ?? title,
                streamURL: url,
                group: group,
                logoURL: attributes["tvg-logo"].flatMap(URL.init(string:)),
                epgID: epgID,
                number: attributes["tvg-chno"].flatMap(Int.init),
                hasCatchup: catchup != nil && catchup != "0",
                catchupDays: catchupDays
            )
        }
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
