import XCTest

/// Movies and Series while sources fail, come back empty or wait for a
/// login, and Series on its own (movies-and-series-browsing capability), on
/// the scripted Xtream sources Cabin and Office of `UITestingShelf`.
@MainActor
final class ShelfStatesUITests: XCTestCase {
    static let office = "00000000-0000-0000-0000-0000000000E3"

    override func setUp() {
        continueAfterFailure = false
    }

    func launch(_ scenario: String) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", scenario, "-ui-testing-reduce-motion"]
        app.launch()
        let tab = app.tabBars.buttons["Movies"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        return app
    }

    func expectGone(_ element: XCUIElement, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: timeout), .completed, "\(element) stayed", file: file, line: line)
    }

    // movies-and-series-browsing/when-sources-fail, some sources failed
    func testABannerNamesTheFailedSourceOverTheOthersTitles() throws {
        let app = try launch("failing")
        let banner = app.element("movies.failure")
        XCTAssertTrue(banner.waitForExistence(timeout: 10))
        XCTAssertEqual(app.element("movies.failure.text").label, "Could not load Office")
        XCTAssertTrue(app.element("movies.hero").exists, "Cabin's titles still show")
        XCTAssertFalse(app.element("movies.card.xtream#office#vod#1").exists)

        app.element("movies.failure.retry").tap()
        expectGone(banner)
        XCTAssertTrue(app.element("movies.card.xtream#office#vod#1").waitForExistence(timeout: 5), "Office's titles arrive")
    }

    // movies-and-series-browsing/when-sources-fail, dismissing the banner
    func testTheBannerCanBeDismissed() throws {
        let app = try launch("failing")
        XCTAssertTrue(app.element("movies.failure").waitForExistence(timeout: 10))
        app.element("movies.failure.dismiss").tap()
        expectGone(app.element("movies.failure"))
        XCTAssertTrue(app.element("movies.hero").exists)
    }

    // movies-and-series-browsing/when-sources-fail, no source has titles
    func testNoSourceWithTitlesSaysCouldNotLoadWithRetry() throws {
        let app = try launch("error")
        let error = app.element("movies.error")
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        XCTAssertTrue(error.staticTexts["Could not load movies"].exists)
        XCTAssertTrue(error.staticTexts["Office: waiting for its login to sync from iCloud"].exists)
        XCTAssertFalse(error.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'hostname'")).firstMatch.exists)
        XCTAssertTrue(app.element("movies.retry").exists)
    }

    // movies-and-series-browsing/when-sources-fail, offline
    func testOfflineSaysSo() throws {
        let app = try launch("offline")
        let error = app.element("movies.error")
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        XCTAssertTrue(error.staticTexts["You're offline."].exists)
        XCTAssertTrue(app.element("movies.retry").exists)
    }

    // movies-and-series-browsing/when-sources-fail, every source answered with nothing
    func testNothingHereYetHasALinePerSource() throws {
        let app = try launch("empty")
        let empty = app.element("movies.empty")
        XCTAssertTrue(empty.waitForExistence(timeout: 10))
        XCTAssertTrue(empty.staticTexts["Nothing here yet"].exists)
        XCTAssertTrue(empty.staticTexts["Cabin: no movies"].exists)
        XCTAssertTrue(empty.staticTexts["Office: waiting for its login to sync from iCloud"].exists)
    }

    // movies-and-series-browsing/when-sources-fail, a login not yet arrived
    func testASourceWaitingForItsLoginIsNamedAndTriedAgain() throws {
        let app = try launch("waiting")
        let note = app.element("movies.waiting.\(Self.office)")
        XCTAssertTrue(note.waitForExistence(timeout: 10))
        XCTAssertTrue(app.element("movies.hero").exists)
        expectGone(note, timeout: 20)
        XCTAssertTrue(app.element("movies.card.xtream#office#vod#1").waitForExistence(timeout: 5))
    }

    // movies-and-series-browsing/series-work-the-same-way
    func testSeriesOrderByLastChangeAndShowSeasons() throws {
        let app = try launch("titles")
        app.element("movies.kind.series").tap()
        let title = app.element("series.hero.title")
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "Harbor Watch", "the series changed last")
        let seasons = app.element("series.hero").staticTexts.matching(NSPredicate(format: "label CONTAINS '3 seasons'")).firstMatch
        XCTAssertTrue(seasons.waitForExistence(timeout: 5))
        XCTAssertTrue(app.element("series.row.recentlyAdded").exists)
        XCTAssertTrue(app.element("series.genres.crime").exists)
    }
}
