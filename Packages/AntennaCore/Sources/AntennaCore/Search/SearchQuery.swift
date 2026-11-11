import Foundation

/// What the user typed into Search, matched the way the Live filter matches
/// (search/find-things-the-way-you-type-them): trimmed, runs of spaces made
/// one, cut to 100 characters, case and accents ignored, and every word a
/// part of the same field.
public struct SearchQuery: Sendable, Equatable {
    /// The fewest characters, spaces left out, that start a search.
    public static let minimumLength = 2

    /// The query as typed, trimmed and with runs of whitespace made one space.
    public let text: String
    /// The words, folded, in typed order.
    public var tokens: [String] { filter.tokens }
    /// The digits that start a channel number, leading zeros removed, when
    /// the query is only digits and not all zeros
    /// (search/find-a-channel-by-its-number).
    public var digits: String? { filter.digits }

    let filter: ChannelFilter
    /// The folded words joined by one space, for "starts with the whole query".
    let folded: String

    public init(_ typed: String) {
        let words = String(typed.prefix(ChannelFilter.maximumLength)).split(whereSeparator: \.isWhitespace)
        text = words.joined(separator: " ")
        filter = ChannelFilter(text)
        folded = filter.tokens.joined(separator: " ")
    }

    /// True from the second letter on. A single character shows nothing yet.
    public var isSearchable: Bool {
        text.count(where: { !$0.isWhitespace }) >= Self.minimumLength
    }

    /// True when every word is part of `folded`, a field folded with `fold(_:)`.
    func matches(folded field: String) -> Bool {
        !field.isEmpty && tokens.allSatisfy { field.contains($0) }
    }

    /// Text without case or accents, as the index keeps it.
    static func fold(_ text: String) -> String {
        ChannelFilter.fold(text)
    }

    /// Where to highlight each word in `text`: its first occurrence, case and
    /// accents ignored. Ranges are in `text`, in the order they occur, and
    /// overlapping ones are merged. Empty when a word is not in `text`.
    public func highlights(in text: String) -> [Range<String.Index>] {
        guard !tokens.isEmpty else { return [] }
        // Fold one character at a time, remembering which character of
        // `text` each folded character came from, so a fold that changes
        // length still maps back.
        var folded: [Character] = []
        var origin: [String.Index] = []
        for index in text.indices {
            for character in Self.fold(String(text[index])) {
                folded.append(character)
                origin.append(index)
            }
        }
        var ranges: [Range<String.Index>] = []
        for token in tokens {
            let needle = Array(token)
            guard let start = Self.firstOffset(of: needle, in: folded) else { continue }
            let lower = origin[start]
            let last = origin[start + needle.count - 1]
            ranges.append(lower..<text.index(after: last))
        }
        return Self.merged(ranges)
    }

    private static func firstOffset(of needle: [Character], in haystack: [Character]) -> Int? {
        guard !needle.isEmpty, needle.count <= haystack.count else { return nil }
        for start in 0...(haystack.count - needle.count) where haystack[start..<start + needle.count].elementsEqual(needle) {
            return start
        }
        return nil
    }

    private static func merged(_ ranges: [Range<String.Index>]) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = result.last, range.lowerBound <= last.upperBound {
                result[result.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                result.append(range)
            }
        }
        return result
    }
}
