import Foundation

/// One recent search (watch-progress-sync/recent-searches-stay-short-and-tidy).
public struct RecentSearch: Sendable, Hashable {
    /// The record's own id, the last tie-break between copies.
    public var id: String
    public var query: String
    public var updatedAt: Date

    public init(id: String, query: String, updatedAt: Date) {
        self.id = id
        self.query = query
        self.updatedAt = updatedAt
    }

    /// How many searches are kept.
    public static let limit = 10
    /// How many characters of a search are kept.
    public static let length = 100

    /// The search as stored: trimmed, runs of whitespace made one space and
    /// cut to 100 characters. Nil for a blank search.
    public static func tidy(_ query: String) -> String? {
        let words = query.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return nil }
        let joined = words.joined(separator: " ")
        return String(joined.prefix(length)).trimmingCharacters(in: .whitespaces)
    }

    /// What two searches must share to count as one: the tidy text without
    /// case or accents.
    public static func fold(_ query: String) -> String {
        (tidy(query) ?? "").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// False for a damaged record whose search is blank.
    public var isUsable: Bool {
        Self.tidy(query) != nil
    }

    /// One search per fold, keeping the latest spelling, then the lower id;
    /// the ten newest are the winners, newest first, and the rest are losers.
    public static func resolve(_ copies: [RecentSearch]) -> Resolution<RecentSearch> {
        let folded = Resolution(copies, usable: \.isUsable, key: { fold($0.query) }) { lhs, rhs in
            newestFirst(lhs, rhs)
        }
        let ordered = folded.winnerIndices.sorted { newestFirst(copies[$0], copies[$1]) }
        return Resolution(copies, winnerIndices: Array(ordered.prefix(limit)), losers: folded.losers + ordered.dropFirst(limit))
    }

    /// Newest first, then by id so the order never wavers.
    public static func newestFirst(_ lhs: RecentSearch, _ rhs: RecentSearch) -> Bool {
        lhs.updatedAt != rhs.updatedAt ? lhs.updatedAt > rhs.updatedAt : lhs.id < rhs.id
    }

    /// The times for searches an earlier build kept on the device, newest
    /// first, one second apart ending at `now`
    /// (watch-progress-sync/recent-searches-from-an-earlier-build-carry-over).
    /// Blank searches are left out.
    public static func carriedOver(_ queries: [String], now: Date) -> [(query: String, updatedAt: Date)] {
        let tidied = queries.compactMap(tidy)
        return zip(tidied, 0...).map { query, offset in (query, now.addingTimeInterval(-Double(offset))) }
    }
}
