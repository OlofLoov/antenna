import Foundation

extension Channel {
    /// Returns `channels` with `sourceID` set to `sourceID` and `position` set
    /// to each channel's 0-based index in `channels`. No other field changes.
    public static func tagged(_ channels: [Channel], sourceID: UUID) -> [Channel] {
        zip(channels.indices, channels).map { index, channel in
            var tagged = channel
            tagged.sourceID = sourceID
            tagged.position = index
            return tagged
        }
    }

    /// Up to four uppercase characters to draw in place of a missing logo,
    /// or "?" when `name` has no letter or digit (design-system/channels-without-a-logo-show-initials).
    ///
    /// A one-word name gives its first four letters and digits ("news24" is
    /// "NEWS"); a longer name gives the first letter or digit of each word
    /// that has one ("BBC - One" is "BO").
    public static func initials(for name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace)
            .map { $0.filter { $0.isLetter || $0.isNumber } }
            .filter { !$0.isEmpty }
        let raw: String
        switch words.count {
        case 0: return "?"
        case 1: raw = String(words[0].prefix(4))
        default: raw = String(words.prefix(4).compactMap(\.first))
        }
        return String(raw.uppercased().prefix(4))
    }
}
