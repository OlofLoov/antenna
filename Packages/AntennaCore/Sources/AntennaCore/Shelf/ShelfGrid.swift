import Foundation

/// The orders a grid can take (movies-and-series-browsing/browse-a-genre-or-sort-the-lot).
/// iPhone and Apple TV always show newest first; iPad and Mac offer all three.
public enum ShelfSort: String, Sendable, Hashable, CaseIterable {
    /// Newest first by date added, undated titles after, in the providers' order.
    case recentlyAdded
    /// By name, ignoring case and accents.
    case title
    /// Newest year first; titles without a year after, by name.
    case year

    public var name: String { name(.autoupdatingCurrent) }

    public func name(_ locale: Locale) -> String {
        let words = Words(locale)
        return switch self {
        case .recentlyAdded: words("Recently added")
        case .title: words("Title")
        case .year: words("Year")
        }
    }
}

/// One genre, from the provider's categories with titles, as the sidebar
/// and chips list it.
public struct ShelfGenre: Sendable, Hashable, Identifiable {
    public var name: String
    public var count: Int
    public var id: String { name }

    public init(name: String, count: Int) {
        self.name = name
        self.count = count
    }
}

extension Shelf {
    /// `titles` in `sort` order.
    public static func sorted(_ titles: [ShelfTitle], by sort: ShelfSort) -> [ShelfTitle] {
        switch sort {
        case .recentlyAdded:
            return ShelfTitle.newestFirst(titles)
        case .title:
            return byName(titles)
        case .year:
            // Undated titles count as year 0, so they go after every dated one.
            var keyed = titles.enumerated().map { (year: $1.year ?? 0, key: sortKey($1.name), index: $0) }
            keyed.sort { lhs, rhs in
                if lhs.year != rhs.year { return lhs.year > rhs.year }
                return lhs.key != rhs.key ? lhs.key < rhs.key : lhs.index < rhs.index
            }
            return keyed.map { titles[$0.index] }
        }
    }

    /// The titles in a category, every source's together, in provider order.
    public static func titles(in genre: String, of titles: [ShelfTitle]) -> [ShelfTitle] {
        titles.filter { $0.category == genre }
    }

    /// The genres in rows' order with their counts: every category row.
    public static func genres(_ rows: [ShelfRow]) -> [ShelfGenre] {
        rows.compactMap { row in
            guard case .category(let name) = row.id else { return nil }
            return ShelfGenre(name: name, count: row.count)
        }
    }

    /// The genres whose names hold every word of `query`, folded for case
    /// and accents as the group search folds them, in rows' order. A blank
    /// query keeps them all.
    public static func genres(_ rows: [ShelfRow], matching query: String) -> [ShelfGenre] {
        let filter = ChannelFilter(query)
        return genres(rows).filter { filter.matches(name: $0.name, number: nil) }
    }

    /// By `sortKey`, then in the order given. Each key is worked out once,
    /// so 100 000 titles sort without 1.7 million locale-aware compares
    /// (movies-and-series-browsing/browsing-stays-responsive).
    private static func byName(_ titles: [ShelfTitle]) -> [ShelfTitle] {
        var keyed = titles.enumerated().map { (key: sortKey($1.name), index: $0) }
        keyed.sort { $0.key != $1.key ? $0.key < $1.key : $0.index < $1.index }
        return keyed.map { titles[$0.index] }
    }

    /// The name folded for case and accents, with each run of digits
    /// padded to `digitRun` places so "Movie 2" sorts before "Movie 10".
    static func sortKey(_ name: String) -> String {
        let folded = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        var key: [UInt8] = []
        key.reserveCapacity(folded.utf8.count + digitRun)
        var digits = 0
        for byte in folded.utf8 {
            if byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") {
                digits += 1
                key.append(byte)
                continue
            }
            if digits > 0 { pad(&key, digits) }
            digits = 0
            key.append(byte)
        }
        if digits > 0 { pad(&key, digits) }
        return String(decoding: key, as: UTF8.self)
    }

    /// Puts zeros in front of the `count` digits that end `key`.
    private static func pad(_ key: inout [UInt8], _ count: Int) {
        guard count < digitRun else { return }
        key.insert(contentsOf: [UInt8](repeating: UInt8(ascii: "0"), count: digitRun - count), at: key.count - count)
    }

    /// Numbers up to this many digits sort by value.
    static let digitRun = 8
}

extension ShelfTitle {
    /// The year in the name, as providers write it: "Dune (2021)",
    /// "Dune - 2021" or "Dune [2021]". Only 1900 to 2099, and the last such
    /// number wins. Nil without one.
    public var year: Int? {
        var found: Int?
        var value = 0
        var digits = 0
        // Bytes, not characters: a digit is one ASCII byte, and anything else ends a number.
        for byte in name.utf8 {
            if byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") {
                value = digits < 5 ? value * 10 + Int(byte - UInt8(ascii: "0")) : value
                digits += 1
                continue
            }
            if digits == 4, (1900...2099).contains(value) { found = value }
            value = 0
            digits = 0
        }
        if digits == 4, (1900...2099).contains(value) { found = value }
        return found
    }
}
