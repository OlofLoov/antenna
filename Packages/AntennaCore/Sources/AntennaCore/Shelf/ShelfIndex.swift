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

    public static let empty = ShelfIndex(catalogues: [], now: .distantPast)

    /// The index of `catalogues` in source order. `now` dates Recently added's count.
    public init(catalogues: [ShelfCatalogue], now: Date) {
        let titles = catalogues.count == 1 ? catalogues[0].titles : catalogues.flatMap(\.titles)
        let newest = ShelfTitle.newestFirst(titles)
        var positions: [ActivityKey: Int] = [:]
        positions.reserveCapacity(titles.count)
        for (position, title) in titles.enumerated() where positions[title.activityKey] == nil {
            positions[title.activityKey] = position
        }
        self.titles = titles
        self.newest = newest
        self.positions = positions
        rows = Shelf.rows(titles, newest: newest, categoryOrder: Shelf.categoryOrder(catalogues.map(\.categories)), now: now)
        banner = Array(newest.prefix(Shelf.bannerCount))
    }

    /// Builds the index away from the caller's actor, so a main-actor
    /// caller keeps drawing while 50 000 titles are sorted.
    @concurrent
    public static func build(_ catalogues: [ShelfCatalogue], now: Date) async -> ShelfIndex {
        ShelfIndex(catalogues: catalogues, now: now)
    }

    /// The first loaded title with this key, or nil.
    public func title(_ key: ActivityKey) -> ShelfTitle? {
        positions[key].map { titles[$0] }
    }
}
