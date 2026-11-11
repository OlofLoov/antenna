import AntennaCore
import Foundation
import Testing

/// Grids: a genre's titles, the genres with their counts, and the three orders.
@Suite struct ShelfGridTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let source = UUID()

    private func title(_ id: Int, _ name: String, daysAgo: Double? = nil, category: String? = nil) -> ShelfTitle {
        ShelfTitle(
            id: "xtream#h#vod#\(id)", kind: .movie, sourceID: source, name: name,
            added: daysAgo.map { now.addingTimeInterval(-$0 * 86_400) }, category: category)
    }

    @Test("movies-and-series-browsing/browse-a-genre-or-sort-the-lot the year comes from the name")
    func years() {
        #expect(title(1, "Dune (2021)").year == 2021)
        #expect(title(1, "Dune - 2021 4K").year == 2021)
        #expect(title(1, "Blade Runner 2049 [2017]").year == 2017)
        #expect(title(1, "Dune 2160p").year == nil)
        #expect(title(1, "Ocean's 12345").year == nil)
        #expect(title(1, "Heat").year == nil)
    }

    @Test("movies-and-series-browsing/browse-a-genre-or-sort-the-lot title, year and recently added orders")
    func orders() {
        let titles = [
            title(1, "beta (1999)", daysAgo: 5), title(2, "Alpha", daysAgo: 1), title(3, "Émile (2020)"),
            title(4, "Delta (2020)", daysAgo: 3),
        ]
        #expect(Shelf.sorted(titles, by: .title).map(\.name) == ["Alpha", "beta (1999)", "Delta (2020)", "Émile (2020)"])
        #expect(Shelf.sorted(titles, by: .year).map(\.name) == ["Delta (2020)", "Émile (2020)", "beta (1999)", "Alpha"])
        #expect(Shelf.sorted(titles, by: .recentlyAdded).map(\.name) == ["Alpha", "Delta (2020)", "beta (1999)", "Émile (2020)"])
        #expect(ShelfSort.allCases.map(\.name) == ["Recently added", "Title", "Year"])
    }

    @Test("movies-and-series-browsing/browse-a-genre-or-sort-the-lot a genre holds every source's titles with its count")
    func genres() {
        let titles = [
            title(1, "One", daysAgo: 1, category: "Drama"), title(2, "Two", category: "Action"),
            title(3, "Three", daysAgo: 2, category: "Drama"),
        ]
        let rows = Shelf.rows(titles, categoryOrder: ["Drama", "Action", "Kids"], now: now)
        #expect(Shelf.genres(rows) == [ShelfGenre(name: "Drama", count: 2), ShelfGenre(name: "Action", count: 1)])
        #expect(Shelf.titles(in: "Drama", of: titles).map(\.name) == ["One", "Three"])
    }
}
