import Foundation

/// The text of one subtitle packet from a container, for the text
/// subtitle formats the FFmpeg path shows (playback-engine/audio-and-subtitle-languages).
/// Styling and positioning tags are dropped; line breaks are kept.
public enum SubtitleText {
    /// The codec names whose packets carry text. Picture-based subtitles
    /// (DVB, PGS, DVD) and teletext are not listed.
    public static let textCodecs: Set<String> = ["subrip", "srt", "ass", "ssa", "webvtt", "mov_text", "text"]

    /// The lines in `data` for a packet of `codec`, nil when it holds none.
    public static func decode(_ data: Data, codec: String) -> String? {
        let raw: String?
        switch codec {
        case "mov_text":
            // A 16-bit big-endian length, then the text.
            guard data.count >= 2 else { return nil }
            let length = Int(data[data.startIndex]) << 8 | Int(data[data.startIndex + 1])
            raw = String(bytes: data.dropFirst(2).prefix(length), encoding: .utf8)
        case "ass", "ssa":
            raw = String(bytes: data, encoding: .utf8).map(assDialogue)
        default:
            raw = String(bytes: data, encoding: .utf8) ?? String(bytes: data, encoding: .isoLatin1)
        }
        guard let raw else { return nil }
        let text = stripTags(raw)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// The text field of a Matroska ASS packet: "ReadOrder, Layer, Style,
    /// Name, MarginL, MarginR, MarginV, Effect, Text", with `\N` and `\n` as
    /// line breaks and `\h` as a space.
    private static func assDialogue(_ packet: String) -> String {
        let fields = packet.split(separator: ",", maxSplits: 8, omittingEmptySubsequences: false)
        let text = fields.count == 9 ? String(fields[8]) : packet
        return text.replacingOccurrences(of: "\\N", with: "\n").replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\h", with: " ")
    }

    /// Drops `<i>`-style markup and `{\an8}`-style override blocks.
    private static func stripTags(_ text: String) -> String {
        var result = ""
        var closing: Character?
        for character in text.replacingOccurrences(of: "\r\n", with: "\n") {
            if let end = closing {
                if character == end { closing = nil }
                continue
            }
            switch character {
            case "<": closing = ">"
            case "{": closing = "}"
            default: result.append(character)
            }
        }
        return result
    }
}
