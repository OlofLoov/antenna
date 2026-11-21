import Foundation

/// Stream headers in a playlist (m3u-playlists/stream-headers-from-the-playlist).
extension M3UParser {
    /// Reads `#EXTVLCOPT:http-user-agent=` and `http-referrer=`, `#EXTHTTP:`
    /// with a JSON object of headers, and `#KODIPROP:` stream or common
    /// headers written as `Name=value&Name=value`. Other lines are ignored.
    static func readHeaders(_ line: String, into headers: inout StreamHeaders) {
        if line.hasPrefix("#EXTVLCOPT:") {
            let option = line.dropFirst("#EXTVLCOPT:".count)
            guard let equals = option.firstIndex(of: "=") else { return }
            let name = option[..<equals].trimmingCharacters(in: .whitespaces).lowercased()
            guard ["http-user-agent", "http-referrer", "http-referer"].contains(name) else { return }
            headers.set(name, String(option[option.index(after: equals)...]))
        } else if line.hasPrefix("#EXTHTTP:") {
            let json = Data(line.dropFirst("#EXTHTTP:".count).utf8)
            guard let object = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] else { return }
            for (name, value) in object {
                if let text = value as? String { headers.set(name, text) }
            }
        } else if line.hasPrefix("#KODIPROP:") {
            let property = line.dropFirst("#KODIPROP:".count)
            guard let equals = property.firstIndex(of: "=") else { return }
            let name = property[..<equals].trimmingCharacters(in: .whitespaces).lowercased()
            guard ["inputstream.adaptive.stream_headers", "inputstream.adaptive.common_headers"].contains(name) else { return }
            readQuery(property[property.index(after: equals)...], into: &headers)
        }
    }

    /// Kodi's `link|Name=value&Name=value`: the link before the first `|`
    /// and the percent-decoded headers after it. A line whose part after
    /// the `|` holds no `=` is kept whole.
    static func splitLink(_ line: String) -> (address: String, headers: StreamHeaders) {
        guard let bar = line.firstIndex(of: "|") else { return (line, StreamHeaders()) }
        let suffix = line[line.index(after: bar)...]
        guard suffix.contains("=") else { return (line, StreamHeaders()) }
        var headers = StreamHeaders()
        readQuery(suffix, into: &headers)
        return (String(line[..<bar]), headers)
    }

    private static func readQuery(_ text: Substring, into headers: inout StreamHeaders) {
        for pair in text.split(separator: "&") {
            guard let equals = pair.firstIndex(of: "=") else { continue }
            let name = String(pair[..<equals])
            let value = String(pair[pair.index(after: equals)...])
            headers.set(name.removingPercentEncoding ?? name, value.removingPercentEncoding ?? value)
        }
    }
}
