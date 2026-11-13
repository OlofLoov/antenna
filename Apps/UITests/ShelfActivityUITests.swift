import XCTest

/// My list and Continue watching on iPhone (movies-and-series-browsing
/// capability), on the `watching` script of `UITestingShelf`: Harbor Watch
/// 30% into its first episode, Northern Lights with its first episode
/// finished, Second Act 40% in, Salt Road finished; Night Ferry then Paper
/// Cities on My list.
@MainActor
final class ShelfActivityUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func launch(_ scenario: String = "watching") throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", scenario, "-ui-testing-reduce-motion"]
        app.launch()
        let tab = app.tabBars.buttons["Movies"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        XCTAssertTrue(app.element("movies.hero").waitForExistence(timeout: 10))
        return app
    }

    func card(_ app: XCUIApplication, in row: String, _ id: String) -> XCUIElement {
        app.element("movies.row.\(row)").descendants(matching: .any)["movies.card.\(id)"].firstMatch
    }

    func expect(_ element: XCUIElement, _ predicate: String, file: StaticString = #filePath, line: UInt = #line) {
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [wait], timeout: 5), .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    // movies-and-series-browsing/continue-watching
    func testContinueWatchingListsMoviesAndSeriesMostRecentFirst() throws {
        let app = try launch()
        let row = app.element("movies.row.continueWatching")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let harbor = card(app, in: "continueWatching", "xtream#cabin#series#2")
        let northern = card(app, in: "continueWatching", "xtream#cabin#series#1")
        let second = card(app, in: "continueWatching", "xtream#cabin#vod#2")
        XCTAssertLessThan(harbor.frame.minX, northern.frame.minX)
        XCTAssertLessThan(northern.frame.minX, second.frame.minX)
        expect(harbor, "label == 'Harbor Watch, S1 E1'")
        XCTAssertEqual(northern.label, "Northern Lights, Next episode")
        XCTAssertEqual(second.label, "Second Act, 54 min left")
        XCTAssertTrue(app.element("movies.card.xtream#cabin#series#2.badge").exists, "series carry the SERIES badge")
        XCTAssertFalse(card(app, in: "continueWatching", "xtream#cabin#vod#3").exists, "a finished movie leaves")

        app.element("movies.seeAll").tap()
        let grid = app.element("movies.grid")
        XCTAssertTrue(grid.waitForExistence(timeout: 5))
        XCTAssertTrue(grid.staticTexts["Continue watching"].exists)
        XCTAssertTrue(grid.staticTexts["3 titles"].exists)
    }

    /// Swipes up until `element` exists, for rows that build as they scroll in.
    func scroll(to element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.exists {
            app.swipeUp()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
    }

    // movies-and-series-browsing/recently-watched
    func testRecentlyWatchedKeepsFinishedTitles() throws {
        let app = try launch()
        let row = app.element("movies.row.recentlyWatched")
        scroll(to: row, in: app)
        let salt = card(app, in: "recentlyWatched", "xtream#cabin#vod#3")
        let second = card(app, in: "recentlyWatched", "xtream#cabin#vod#2")
        XCTAssertTrue(salt.exists, "a finished movie stays")
        XCTAssertLessThan(salt.frame.minX, second.frame.minX, "most recent first")
        XCTAssertTrue(row.staticTexts["2 titles"].exists)

        app.element("movies.kind.series").tap()
        let series = app.element("series.row.recentlyWatched")
        scroll(to: series, in: app)
        let harbor = series.descendants(matching: .any)["series.card.xtream#cabin#series#2"].firstMatch
        let northern = series.descendants(matching: .any)["series.card.xtream#cabin#series#1"].firstMatch
        XCTAssertLessThan(harbor.frame.minX, northern.frame.minX)
        XCTAssertTrue(series.staticTexts["2 titles"].exists, "each series once")
    }

    // movies-and-series-browsing/recently-watched, nothing played
    // movies-and-series-browsing/rows-in-a-predictable-order
    func testNothingPlayedHasNoRecentlyWatched() throws {
        let app = try launch("titles")
        XCTAssertTrue(app.element("movies.row.recentlyAdded").waitForExistence(timeout: 5))
        XCTAssertFalse(app.element("movies.row.recentlyWatched").exists)
    }

    // movies-and-series-browsing/see-everything-new
    func testSeeAllOpensEveryTitleNewestFirst() throws {
        let app = try launch("titles")
        let seeAll = app.element("movies.row.recentlyAdded.seeAll")
        XCTAssertTrue(seeAll.waitForExistence(timeout: 5))
        seeAll.tap()
        let grid = app.element("movies.grid")
        XCTAssertTrue(grid.waitForExistence(timeout: 5))
        XCTAssertTrue(grid.staticTexts["Recently added"].exists)
        XCTAssertTrue(grid.staticTexts["9 titles"].exists)
        let newest = grid.descendants(matching: .any)["movies.card.xtream#cabin#vod#1"].firstMatch
        let next = grid.descendants(matching: .any)["movies.card.xtream#office#vod#1"].firstMatch
        XCTAssertLessThan(newest.frame.minX, next.frame.minX)
        app.element("movies.genres.all").tap()
        expect(grid, "exists == false")
    }

    // movies-and-series-browsing/continue-watching, nothing in progress
    func testNothingInProgressHidesTheRow() throws {
        let app = try launch("titles")
        XCTAssertTrue(app.element("movies.row.recentlyAdded").waitForExistence(timeout: 5))
        XCTAssertFalse(app.element("movies.row.continueWatching").exists)
        XCTAssertFalse(app.element("movies.row.myList").exists)
    }

    // movies-and-series-browsing/keep-a-list-for-later
    func testTheBannerButtonAddsAndRemoves() throws {
        let app = try launch()
        let button = app.element("movies.hero.myList")
        XCTAssertEqual(button.value as? String, "Not on My list")
        XCTAssertTrue(app.element("movies.row.myList").staticTexts["2 titles"].exists, "a title that is not loaded is not counted")

        button.tap()
        expect(button, "value == 'On My list'")
        let added = card(app, in: "myList", "xtream#cabin#vod#1")
        XCTAssertTrue(added.waitForExistence(timeout: 5))
        XCTAssertLessThan(added.frame.minX, card(app, in: "myList", "xtream#office#vod#1").frame.minX, "latest additions first")

        button.tap()
        expect(button, "value == 'Not on My list'")
        expect(added, "exists == false")
    }

    // movies-and-series-browsing/keep-a-list-for-later, the poster's menu
    func testThePosterMenuAddsAndRemoves() throws {
        let app = try launch("titles")
        let poster = card(app, in: "recentlyAdded", "xtream#cabin#vod#2")
        XCTAssertTrue(poster.waitForExistence(timeout: 5))
        poster.press(forDuration: 1.2)
        let item = app.element("movies.menu.myList")
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        XCTAssertEqual(item.label, "Add to My list")
        item.tap()
        XCTAssertTrue(app.element("movies.row.myList").waitForExistence(timeout: 5))

        poster.press(forDuration: 1.2)
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        XCTAssertEqual(item.label, "Remove from My list")
        item.tap()
        expect(app.element("movies.row.myList"), "exists == false")
    }

    // movies-and-series-browsing/keep-a-list-for-later, My list grid
    func testTheMyListChipShowsTheList() throws {
        let app = try launch()
        app.element("movies.genres.myList").tap()
        let grid = app.element("movies.grid")
        XCTAssertTrue(grid.waitForExistence(timeout: 5))
        XCTAssertTrue(grid.staticTexts["2 titles"].exists)
    }
}
