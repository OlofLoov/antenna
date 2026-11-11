import Foundation

/// The banner and rows of the Movies or Series section, built from every
/// Xtream source's titles (movies-and-series-browsing).
public enum Shelf {
    /// How many titles the banner moves through.
    public static let bannerCount = 4
    /// How many titles Recently added holds.
    public static let recentCount = 50
    /// Recently added's header counts titles added within this many days.
    public static let recentDays = 30

    /// The banner's titles: the four newest by date added, filled up in the
    /// providers' order when fewer than four have dates
    /// (movies-and-series-browsing/new-titles-up-front).
    public static func banner(_ titles: [ShelfTitle]) -> [ShelfTitle] {
        Array(ShelfTitle.newestFirst(titles).prefix(bannerCount))
    }

    /// Recently added, then one row per category that has titles, in
    /// `categoryOrder`. Categories with the same name from several sources
    /// make one row (movies-and-series-browsing/rows-in-a-predictable-order).
    /// `titles` are in the providers' order; titles with no category show
    /// only in Recently added.
    public static func rows(_ titles: [ShelfTitle], categoryOrder: [String], now: Date) -> [ShelfRow] {
        guard !titles.isEmpty else { return [] }
        let since = now.addingTimeInterval(-Double(recentDays) * 86_400)
        let recent = ShelfRow(
            id: .recentlyAdded, titles: Array(ShelfTitle.newestFirst(titles).prefix(recentCount)),
            count: titles.filter { ($0.added ?? .distantPast) >= since }.count)
        var byCategory: [String: [ShelfTitle]] = [:]
        for title in titles {
            if let category = title.category { byCategory[category, default: []].append(title) }
        }
        var seen = Set<String>()
        let categories = categoryOrder.filter { seen.insert($0).inserted }.compactMap { name -> ShelfRow? in
            guard let titles = byCategory[name], !titles.isEmpty else { return nil }
            return ShelfRow(id: .category(name), titles: titles, count: titles.count)
        }
        return [recent] + categories
    }

    /// The category names of several sources in order: the first source's
    /// order, then names the next sources add, in theirs.
    public static func categoryOrder(_ sources: [[String]]) -> [String] {
        var seen = Set<String>()
        return sources.flatMap { $0 }.filter { seen.insert($0).inserted }
    }
}

/// One row of the section.
public struct ShelfRow: Sendable, Hashable, Identifiable {
    public enum Kind: Sendable, Hashable {
        case recentlyAdded
        case category(String)
    }

    public var id: Kind
    /// The row's titles in the order shown.
    public var titles: [ShelfTitle]
    /// The number in the header: the category's titles, or for Recently
    /// added those added in the last 30 days.
    public var count: Int

    public init(id: Kind, titles: [ShelfTitle], count: Int) {
        self.id = id
        self.titles = titles
        self.count = count
    }

    /// The row's heading.
    public var name: String {
        switch id {
        case .recentlyAdded: "Recently added"
        case .category(let name): name
        }
    }
}
