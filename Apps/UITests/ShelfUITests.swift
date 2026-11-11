import XCTest

/// Movies and Series on iPhone (movies-and-series-browsing capability), on the
/// scripted sources of `UITestingShelf`: Home (M3U), and the Xtream sources
/// Cabin and Office. Banner order across both: The Long Harbor, Night
/// Ferry, Second Act, Snow Day.
@MainActor
final class ShelfUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func launch(_ scenario: String = "titles", arguments: [String] = []) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", scenario] + arguments
        app.launch()
        return app
    }

    /// Opens the Movies tab and waits for `identifier` in it.
    func openMovies(_ app: XCUIApplication, waitFor identifier: String = "movies.hero") {
        let tab = app.tabBars.buttons["Movies"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "no Movies tab")
        tab.tap()
        XCTAssertTrue(app.element(identifier).waitForExistence(timeout: 10), "\(identifier) never appeared")
    }

    func heroTitle(_ app: XCUIApplication, _ prefix: String = "movies") -> String {
        app.element("\(prefix).hero.title").label
    }

    func waitForHero(_ app: XCUIApplication, _ title: String, timeout: TimeInterval, file: StaticString = #filePath, line: UInt = #line) {
        let shows = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", title), object: app.element("movies.hero.title"))
        XCTAssertEqual(
            XCTWaiter().wait(for: [shows], timeout: timeout), .completed, "the banner never showed \(title)", file: file, line: line)
    }

    // movies-and-series-browsing/movies-and-series-appear-when-your-provider-has-them
    func testMoviesWithItsSeriesSwitchShowsForAnXtreamSource() throws {
        let app = try launch()
        openMovies(app)
        XCTAssertTrue(app.element("movies.kind").exists)
        XCTAssertFalse(app.tabBars.buttons["Series"].exists, "Series has no tab of its own on iPhone")
        XCTAssertTrue(app.element("movies.kind.movies").isSelected)

        app.element("movies.kind.series").tap()
        XCTAssertTrue(app.element("series.hero").waitForExistence(timeout: 10))
        XCTAssertTrue(app.element("movies.kind.series").isSelected)
    }

    // movies-and-series-browsing/movies-and-series-appear-when-your-provider-has-them, no Xtream source
    func testNoXtreamSourceShowsNoMovies() throws {
        let app = try launch("noXtream")
        XCTAssertTrue(app.tabBars.buttons["Live"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.tabBars.buttons["Movies"].exists)
        XCTAssertFalse(app.tabBars.buttons["Series"].exists)
    }

    // movies-and-series-browsing/movies-and-series-appear-when-your-provider-has-them, before the login arrives
    func testMoviesShowsBeforeASourceHasAnswered() throws {
        let app = try launch("loading")
        openMovies(app)
        XCTAssertTrue(app.element("movies.row.recentlyAdded").waitForExistence(timeout: 10))
    }

    // movies-and-series-browsing/new-titles-up-front
    func testTheBannerShowsTheNewestAndMovesOnByItself() throws {
        let app = try launch()
        openMovies(app)
        waitForHero(app, "The Long Harbor", timeout: 5)
        XCTAssertTrue(app.element("movies.hero").staticTexts["RECENTLY ADDED · ACTION"].exists)
        let facts = app.element("movies.hero").staticTexts.matching(NSPredicate(format: "label CONTAINS '2001'")).firstMatch
        XCTAssertTrue(facts.waitForExistence(timeout: 5), "the year and length never showed")
        XCTAssertTrue(app.element("movies.hero").staticTexts["The story of The Long Harbor."].exists)
        // Night Ferry comes from Office: the banner picks from both sources.
        waitForHero(app, "Night Ferry", timeout: 12)
    }

    // movies-and-series-browsing/new-titles-up-front, Reduce Motion
    func testWithReduceMotionTheBannerStaysAndPagingWraps() throws {
        let app = try launch(arguments: ["-ui-testing-reduce-motion"])
        openMovies(app)
        waitForHero(app, "The Long Harbor", timeout: 5)
        Thread.sleep(forTimeInterval: 10)
        XCTAssertEqual(heroTitle(app), "The Long Harbor", "the banner moved by itself")

        app.element("movies.hero.title").swipeRight()
        waitForHero(app, "Snow Day", timeout: 3)
        app.element("movies.hero.title").swipeLeft()
        waitForHero(app, "The Long Harbor", timeout: 3)
        app.element("movies.hero.title").swipeLeft()
        waitForHero(app, "Night Ferry", timeout: 3)
    }

    // movies-and-series-browsing/rows-in-a-predictable-order
    func testRowsFollowTheBanner() throws {
        let app = try launch()
        openMovies(app)
        let recent = app.element("movies.row.recentlyAdded")
        XCTAssertTrue(recent.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(recent.frame.minY, app.element("movies.hero").frame.minY)
        XCTAssertTrue(app.element("movies.card.xtream#cabin#vod#1").exists)
        app.swipeUp()
        XCTAssertTrue(app.element("movies.row.action").waitForExistence(timeout: 5))
        XCTAssertTrue(app.element("movies.row.drama").exists)
    }
}
