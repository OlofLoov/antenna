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
        app.launchInEnglish()
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
    // live-tv-on-iphone-ipad-mac/the-iphone-tab-bar
    func testMoviesAndSeriesHaveATabEachForAnXtreamSource() throws {
        let app = try launch()
        openMovies(app)
        XCTAssertEqual(app.element("movies.title").label, "Movies")
        XCTAssertFalse(app.element("movies.kind").exists, "no Movies | Series switch")
        XCTAssertFalse(app.tabBars.buttons["Settings"].exists, "Settings opens from the profile button")
        XCTAssertTrue(app.searchTab.exists)

        app.tabBars.buttons["Series"].tap()
        XCTAssertTrue(app.element("series.hero").waitForExistence(timeout: 10))
        XCTAssertEqual(app.element("series.title").label, "Series")
        XCTAssertTrue(app.tabBars.buttons["Series"].isSelected)
    }

    // live-tv-on-iphone-ipad-mac/the-iphone-tab-bar, each tab keeps its place
    func testMoviesAndSeriesEachKeepTheirGenre() throws {
        let app = try launch()
        openMovies(app)
        app.pickGenre("movies.genres.drama")
        XCTAssertTrue(app.element("movies.grid").waitForExistence(timeout: 5))

        app.tabBars.buttons["Series"].tap()
        XCTAssertTrue(app.element("series.hero").waitForExistence(timeout: 10))
        XCTAssertTrue(app.genreButton("series").label.hasPrefix("All series"), "Series opens on its own rows")

        app.tabBars.buttons["Movies"].tap()
        XCTAssertTrue(app.element("movies.grid").waitForExistence(timeout: 5), "Movies kept its genre")
        XCTAssertEqual(app.genreButton("movies").label, "Drama, 4 titles")
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
        let app = try launch(arguments: ["-ui-testing-banner-rotates"])
        openMovies(app)
        waitForHero(app, "The Long Harbor", timeout: 5)
        XCTAssertTrue(app.element("movies.hero").staticTexts["RECENTLY ADDED · ACTION"].exists)
        // The banner reads the same info call as the title page.
        let facts = app.element("movies.hero").staticTexts.matching(NSPredicate(format: "label CONTAINS '2024'")).firstMatch
        XCTAssertTrue(facts.waitForExistence(timeout: 5), "the year and length never showed")
        let plot = app.element("movies.hero").staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'A harbour pilot'"))
        XCTAssertTrue(plot.firstMatch.exists)
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

    // movies-and-series-browsing/rating-and-trailer-on-the-banner
    func testTheBannerShowsTheRatingAndTrailerOpensTheLink() throws {
        let app = try launch(arguments: ["-ui-testing-reduce-motion"])
        openMovies(app)
        waitForHero(app, "The Long Harbor", timeout: 5)
        let facts = app.element("movies.hero.facts")
        XCTAssertTrue(waitUntil { facts.exists && facts.label.contains("rated 7.4 out of 10") }, "facts read \(facts.label)")
        let trailer = app.element("movies.hero.trailer")
        XCTAssertTrue(trailer.waitForExistence(timeout: 5))
        XCTAssertEqual(trailer.label, "Trailer")
        let play = app.element("movies.hero.play")
        let info = app.element("movies.hero.info")
        let myList = app.element("movies.hero.myList")
        XCTAssertLessThan(play.frame.maxX, info.frame.minX)
        XCTAssertGreaterThan(trailer.frame.minY, play.frame.maxY, "Trailer and My list sit under Play and Info")
        XCTAssertLessThan(trailer.frame.maxX, myList.frame.minX)
        XCTAssertEqual(myList.frame.midY, trailer.frame.midY, accuracy: 1)
        XCTAssertLessThanOrEqual(myList.frame.maxX, app.windows.firstMatch.frame.maxX, "both rows fit the width")
        // Trailer and My list show words, not a glyph in a square.
        for button in [trailer, myList] {
            XCTAssertGreaterThan(button.frame.width, button.frame.height * 1.4, button.identifier)
        }
        XCTAssertEqual(myList.label, "Add to My list")
        XCTAssertEqual(myList.images.count, 0, "My list shows no glyph")

        trailer.tap()
        let opened = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == 'https://trailers.example/long-harbor'"), object: app.element("shelf.debug.opened"))
        XCTAssertEqual(XCTWaiter().wait(for: [opened], timeout: 5), .completed, "the trailer link never opened")

        // Snow Day has neither.
        app.element("movies.hero.title").swipeRight()
        waitForHero(app, "Snow Day", timeout: 3)
        XCTAssertTrue(waitUntil { !trailer.exists }, "Trailer stayed for a title without one")
        XCTAssertFalse(facts.label.contains("rated"), "facts read \(facts.label)")
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

    // movies-and-series-browsing/browse-a-genre-or-sort-the-lot
    // movies-and-series-browsing/pick-a-genre-from-a-list-on-iphone
    func testAGenrePickedFromTheSheetSwapsTheRowsForAGrid() throws {
        let app = try launch()
        openMovies(app)
        let button = app.genreButton("movies")
        XCTAssertTrue(button.label.hasPrefix("All movies"), button.label)
        // No chips along the top: the drama genre is only in the sheet.
        XCTAssertFalse(app.element("movies.genres.drama").exists, "a genre chip is drawn at the top")
        XCTAssertLessThan(button.frame.maxY, app.element("movies.hero.title").frame.minY, "the button sits over the banner's copy")

        button.tap()
        let sheet = app.element("movies.genres.sheet")
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "the button did not open the Genres sheet")
        XCTAssertTrue(app.element("movies.genres.all").isSelected)
        XCTAssertTrue(app.element("movies.genres.myList").exists)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.exists, "the sheet has a search field")
        search.tap()
        search.typeText("dram")
        XCTAssertTrue(app.element("movies.genres.drama").waitForExistence(timeout: 5))
        XCTAssertFalse(app.element("movies.genres.all").exists, "the search keeps only matching genres")
        app.element("movies.genres.drama").tap()

        let grid = app.element("movies.grid")
        XCTAssertTrue(grid.waitForExistence(timeout: 5))
        XCTAssertFalse(sheet.exists, "the pick closes the sheet")
        XCTAssertTrue(grid.staticTexts["4 titles"].exists)
        XCTAssertEqual(button.label, "Drama, 4 titles")
        XCTAssertFalse(app.element("movies.row.recentlyAdded").exists)
        XCTAssertTrue(app.element("movies.hero").exists, "the banner stays over the grid")

        app.pickGenre("movies.genres.all")
        XCTAssertTrue(app.element("movies.row.recentlyAdded").waitForExistence(timeout: 5))
        XCTAssertFalse(grid.exists)
    }

    // live-tv-on-iphone-ipad-mac/tap-the-open-tab-to-go-back-to-the-top
    func testTappingMoviesAgainScrollsToTheTop() throws {
        // The banner holds its title: another title's copy moves the title line.
        let app = try launch(arguments: ["-ui-testing-reduce-motion"])
        openMovies(app)
        let title = app.element("movies.hero.title")
        let top = title.frame.minY
        for _ in 0..<4 where onScreen(title, below: 0) { app.swipeUp() }
        XCTAssertTrue(waitUntil { !self.onScreen(title, below: 0) }, "the banner never scrolled away")

        app.tabBars.buttons["Movies"].tap()
        XCTAssertTrue(
            waitUntil { title.exists && abs(title.frame.minY - top) < 2 }, "the rows never scrolled back to the banner")
    }

    /// True while `element` exists with its top edge at or below `y`.
    private func onScreen(_ element: XCUIElement, below y: CGFloat) -> Bool {
        element.exists && element.frame.minY >= y
    }

    /// Polls `condition` for up to ten seconds.
    private func waitUntil(_ condition: @escaping () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return condition()
    }
}
