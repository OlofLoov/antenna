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

    public var name: String {
        switch self {
        case .recentlyAdded: "Recently added"
        case .title: "Title"
        case .year: "Year"
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
            let named = byName(titles).map { (year: $0.year, title: $0) }
            let dated = named.filter { $0.year != nil }
            let ordered = zip(dated.indices, dated).sorted { lhs, rhs in
                let left = lhs.1.year ?? 0
                let right = rhs.1.year ?? 0
                return left != right ? left > right : lhs.0 < rhs.0
            }
            return ordered.map(\.1.title) + named.filter { $0.year == nil }.map(\.title)
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

    private static func byName(_ titles: [ShelfTitle]) -> [ShelfTitle] {
        let keyed = titles.map { ($0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil), $0) }
        return zip(keyed.indices, keyed).sorted { lhs, rhs in
            let order = lhs.1.0.localizedStandardCompare(rhs.1.0)
            return order != .orderedSame ? order == .orderedAscending : lhs.0 < rhs.0
        }.map(\.1.1)
    }
}

extension ShelfTitle {
    /// The year in the name, as providers write it: "Dune (2021)",
    /// "Dune - 2021" or "Dune [2021]". Only 1900 to 2099, and the last such
    /// number wins. Nil without one.
    public var year: Int? {
        var found: Int?
        var digits = ""
        for character in name + " " {
            if character.isASCII, character.isNumber {
                digits.append(character)
                continue
            }
            if digits.count == 4, let value = Int(digits), (1900...2099).contains(value) { found = value }
            digits = ""
        }
        return found
    }
}
