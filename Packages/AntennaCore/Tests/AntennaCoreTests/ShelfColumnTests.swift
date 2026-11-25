import AntennaCore
import Testing

/// The column the Apple TV highlight keeps between rows.
@Suite struct ShelfColumnTests {
    // Found on 2026-11-25 with the large library: each move up or down landed the highlight a poster to the
    // right, so a walk six rows down and back up ended on the eighth poster instead of the first.
    @Test("movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv a move between rows keeps the column")
    func keepsTheColumn() {
        #expect(ShelfColumn.target(from: 0, landed: 1, count: 100) == 0, "back from the poster to the right")
        #expect(ShelfColumn.target(from: 7, landed: 8, count: 100) == 7)
        #expect(ShelfColumn.target(from: 3, landed: 3, count: 100) == nil, "already in the column")
    }

    // Found on 2026-11-25 in ShelfRowsUpTVUITests: two quick presses up from Recently added passed over a
    // My list of two posters and landed in Continue watching.
    @Test("movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv a move over a short row lands in it")
    func skippedRow() {
        let order = ["continueWatching", "myList", "recentlyWatched", "recentlyAdded"]
        #expect(ShelfColumn.skipped(order, from: "recentlyWatched", to: "continueWatching") == "myList")
        #expect(ShelfColumn.skipped(order, from: "myList", to: "recentlyAdded") == "recentlyWatched")
        #expect(ShelfColumn.skipped(order, from: "myList", to: "recentlyWatched") == nil, "the next row")
        #expect(ShelfColumn.skipped(order, from: "continueWatching", to: "recentlyAdded") == nil, "three rows is not a slip")
        #expect(ShelfColumn.skipped(order, from: "genres", to: "myList") == nil)
    }

    @Test("movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv a shorter row lands on its last poster")
    func shorterRow() {
        #expect(ShelfColumn.target(from: 9, landed: 1, count: 3) == 2)
        #expect(ShelfColumn.target(from: 9, landed: 2, count: 3) == nil)
        #expect(ShelfColumn.target(from: 0, landed: 0, count: 0) == nil, "an empty row")
    }
}
