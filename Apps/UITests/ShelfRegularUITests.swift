import XCTest

/// Movies and Series in the iPad window (movies-and-series-browsing
/// capability). Runs on an iPad simulator; on an iPhone every test skips.
/// Uses the same scripted launch as `ShelfUITests`.
@MainActor
final class ShelfRegularUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func launch(_ scenario: String = "titles", arguments: [String] = []) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "the wide layout needs an iPad")
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", scenario] + arguments
        app.launch()
        XCTAssertTrue(app.element("browse.sidebar").waitForExistence(timeout: 10), "the sidebar never appeared")
        return app
    }

    // movies-and-series-browsing/movies-and-series-appear-when-your-provider-has-them
    func testMoviesAndSeriesSitInTheSidebar() throws {
        let app = try launch()
        let order = ["live", "guide", "movies", "series", "search"].map { app.element("browse.section.\($0)") }
        var previous = -CGFloat.infinity
        for section in order {
            XCTAssertTrue(section.exists, "\(section) missing")
            XCTAssertGreaterThan(section.frame.minY, previous)
            previous = section.frame.minY
        }
        app.element("browse.section.movies").tap()
        XCTAssertTrue(app.element("movies.hero").waitForExistence(timeout: 10))
        XCTAssertTrue(app.element("movies.row.recentlyAdded").exists)
        app.element("browse.section.series").tap()
        XCTAssertTrue(app.element("series.hero").waitForExistence(timeout: 10))
    }

    // movies-and-series-browsing/movies-and-series-appear-when-your-provider-has-them, no Xtream source
    func testNoXtreamSourceLeavesThemOut() throws {
        let app = try launch("noXtream")
        XCTAssertTrue(app.element("browse.section.live").exists)
        XCTAssertFalse(app.element("browse.section.movies").exists)
        XCTAssertFalse(app.element("browse.section.series").exists)
    }

    // movies-and-series-browsing/new-titles-up-front, paging by hand
    func testASwipePagesTheBanner() throws {
        let app = try launch(arguments: ["-ui-testing-reduce-motion"])
        app.element("browse.section.movies").tap()
        let pager = app.element("movies.hero.pager")
        XCTAssertTrue(pager.waitForExistence(timeout: 10))
        XCTAssertEqual(pager.value as? String, "1 of 4")
        app.element("movies.hero.title").swipeLeft()
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '2 of 4'"), object: pager)
        XCTAssertEqual(XCTWaiter().wait(for: [moved], timeout: 5), .completed)
    }

    // movies-and-series-browsing/browse-a-genre-or-sort-the-lot
    func testAGenreOrASortShowsAGridAndTheSectionBringsTheRowsBack() throws {
        let app = try launch()
        app.element("browse.section.movies").tap()
        XCTAssertTrue(app.element("movies.row.recentlyAdded").waitForExistence(timeout: 10))

        app.element("movies.genres.drama").tap()
        let grid = app.element("movies.grid")
        XCTAssertTrue(grid.waitForExistence(timeout: 5))
        XCTAssertTrue(grid.staticTexts["4 titles"].exists)
        XCTAssertTrue(app.element("movies.genres.drama").isSelected)
        XCTAssertFalse(app.element("movies.hero").exists)

        app.element("browse.section.movies").tap()
        XCTAssertTrue(app.element("movies.row.recentlyAdded").waitForExistence(timeout: 5))

        app.element("movies.sort").tap()
        app.element("movies.sort.title").tap()
        XCTAssertTrue(grid.waitForExistence(timeout: 5))
        XCTAssertTrue(grid.staticTexts["All movies"].exists)
        XCTAssertEqual(app.element("movies.sort").value as? String, "Title")
        let first = app.element("movies.card.xtream#office#vod#3")
        let second = app.element("movies.card.xtream#cabin#vod#6")
        XCTAssertLessThan(first.frame.minX, second.frame.minX, "Copper Hills before Glass Orchard")

        app.element("movies.sort").tap()
        app.element("movies.sort.recentlyAdded").tap()
        XCTAssertTrue(app.element("movies.row.recentlyAdded").waitForExistence(timeout: 5))
        XCTAssertFalse(grid.exists)
    }
}
