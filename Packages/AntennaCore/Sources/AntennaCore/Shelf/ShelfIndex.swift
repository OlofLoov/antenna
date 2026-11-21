import Foundation

/// Everything Movies or Series derives from its loaded titles, built once
/// each time a source's titles change and read on every redraw
/// (movies-and-series-browsing/browsing-stays-responsive).
public struct ShelfIndex: Sendable {
    /// Every source's titles, in source order and each source's order.
    public let titles: [ShelfTitle]
    /// The same titles newest first, undated ones last in the providers' order.
    public let newest: [ShelfTitle]
    /// Recently added, then a row per category (`Shelf.rows`).
    public let rows: [ShelfRow]
    /// The banner's titles (`Shelf.banner`).
    public let banner: [ShelfTitle]
    private let positions: [ActivityKey: Int]
    /// Adult titles left out while the profile hides adult content, for a
    /// link that names one (adult-content/links-to-hidden-content-ask-first).
    private let withheld: [ActivityKey: ShelfTitle]

    public static let empty = ShelfIndex(catalogues: [], showsAdult: false, now: .distantPast)

    /// The index of `catalogues` in source order. `now` dates Recently
    /// added's count. Unless `showsAdult` is set, adult titles are left out
    /// of every list and lookup, and with them their rows, banner places,
    /// people and progress (adult-content/hidden-everywhere-by-default).
    public init(catalogues: [ShelfCatalogue], showsAdult: Bool, now: Date) {
        let loaded = catalogues.count == 1 ? catalogues[0].titles : catalogues.flatMap(\.titles)
        var withheld: [ActivityKey: ShelfTitle] = [:]
        let titles = showsAdult ? loaded : AdultTitles.split(loaded, withheld: &withheld)
        let newest = ShelfTitle.newestFirst(titles)
        let positions = Self.positions(titles)
        self.titles = titles
        self.newest = newest
        self.positions = positions
        self.withheld = withheld
        rows = Shelf.rows(titles, newest: newest, categoryOrder: Shelf.categoryOrder(catalogues.map(\.categories)), now: now)
        banner = Array(newest.prefix(Shelf.bannerCount))
    }

    /// Only the lookups of `titles`, for an index that shows no rows.
    init(lookingUp titles: [ShelfTitle]) {
        let positions = Self.positions(titles)
        self.titles = titles
        self.positions = positions
        newest = []
        rows = []
        banner = []
        withheld = [:]
    }

    /// Builds the index away from the caller's actor, so a main-actor
    /// caller keeps drawing while 50 000 titles are sorted.
    @concurrent
    public static func build(_ catalogues: [ShelfCatalogue], showsAdult: Bool, now: Date) async -> ShelfIndex {
        ShelfIndex(catalogues: catalogues, showsAdult: showsAdult, now: now)
    }

    /// The first loaded title with this key, or nil.
    public func title(_ key: ActivityKey) -> ShelfTitle? {
        positions[key].map { titles[$0] }
    }

    private static func positions(_ titles: [ShelfTitle]) -> [ActivityKey: Int] {
        var positions: [ActivityKey: Int] = [:]
        positions.reserveCapacity(titles.count)
        for (position, title) in titles.enumerated() where positions[title.activityKey] == nil {
            positions[title.activityKey] = position
        }
        return positions
    }

    /// Where the first loaded title with this key sits in `titles`, or nil.
    func position(_ key: ActivityKey) -> Int? {
        positions[key]
    }

    /// The adult title with this key that the index leaves out, or nil.
    public func withheldTitle(_ key: ActivityKey) -> ShelfTitle? {
        withheld[key]
    }
}

extension ShelfTitle {
    /// True when the provider marks the title adult or its category's name
    /// is adult (adult-content/adult-groups-are-found-by-name).
    public var isAdultContent: Bool {
        isAdult || category.map(AdultContent.isAdultName) == true
    }
}

extension Array where Element == ShelfTitle {
    /// The titles a profile sees: all of them when it shows adult content,
    /// else those that are not adult, in order
    /// (adult-content/hidden-everywhere-by-default).
    public func visible(showsAdult: Bool) -> [ShelfTitle] {
        guard !showsAdult else { return self }
        var withheld: [ActivityKey: ShelfTitle] = [:]
        return AdultTitles.split(self, withheld: &withheld)
    }
}

/// Splits titles into the ones a profile that hides adult content sees and
/// the adult ones (adult-content/adult-groups-are-found-by-name).
enum AdultTitles {
    /// True when the provider marks `title` adult or its category's name is adult.
    static func isAdult(_ title: ShelfTitle, names: inout [String: Bool]) -> Bool {
        if title.isAdult { return true }
        guard let category = title.category else { return false }
        if let known = names[category] { return known }
        let adult = AdultContent.isAdultName(category)
        names[category] = adult
        return adult
    }

    /// The titles that are not adult, in order; the adult ones go into `withheld`.
    static func split(_ titles: [ShelfTitle], withheld: inout [ActivityKey: ShelfTitle]) -> [ShelfTitle] {
        var names: [String: Bool] = [:]
        var kept: [ShelfTitle] = []
        kept.reserveCapacity(titles.count)
        for title in titles {
            if isAdult(title, names: &names) {
                if withheld[title.activityKey] == nil { withheld[title.activityKey] = title }
            } else {
                kept.append(title)
            }
        }
        return kept
    }
}
