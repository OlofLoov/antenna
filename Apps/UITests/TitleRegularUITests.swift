import XCTest

/// Movie and series pages in the iPad window (title-detail-and-episode-picker
/// capability). Runs on an iPad simulator; on an iPhone every test skips.
@MainActor
final class TitleRegularUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func launch(_ scenario: String = "titles") throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "the wide layout needs an iPad")
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", scenario, "-ui-testing-reduce-motion"]
        app.launch()
        XCTAssertTrue(app.element("browse.sidebar").waitForExistence(timeout: 10), "the sidebar never appeared")
        return app
    }

    func expect(_ element: XCUIElement, _ predicate: String, file: StaticString = #filePath, line: UInt = #line) {
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [wait], timeout: 5), .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    // title-detail-and-episode-picker/open-a-movie-s-page
    // title-detail-and-episode-picker/what-the-title-is-about
    // title-detail-and-episode-picker/trailer
    func testThePageReplacesTheContentColumnAndBackReturns() throws {
        let app = try launch()
        app.element("browse.section.movies").tap()
        expect(app.element("movies.hero.title"), "label == 'The Long Harbor'")
        app.element("movies.hero.info").tap()

        XCTAssertTrue(app.element("title.name").waitForExistence(timeout: 5))
        XCTAssertTrue(app.element("browse.sidebar").exists, "the sidebar stays")
        XCTAssertEqual(app.element("title.back").label, "Back to Movies")
        expect(app.element("title.meta"), "label CONTAINS '2024'")
        XCTAssertTrue(app.element("title.cast").exists)
        XCTAssertTrue(app.element("title.trailer").exists)

        app.element("title.back").tap()
        expect(app.element("title.name"), "exists == false")
        XCTAssertTrue(app.element("movies.hero.info").isHittable)
    }

    // title-detail-and-episode-picker/open-a-series-page
    func testASeriesPosterOpensItsPage() throws {
        let app = try launch()
        app.element("browse.section.series").tap()
        let poster = app.element("series.card.xtream#cabin#series#2")
        XCTAssertTrue(poster.waitForExistence(timeout: 10))
        poster.tap()
        XCTAssertTrue(app.element("title.name").waitForExistence(timeout: 5))
        XCTAssertEqual(app.element("title.name").label, "Harbor Watch")
        XCTAssertEqual(app.element("title.back").label, "Back to Series")
    }

    // title-detail-and-episode-picker/pick-a-season, by the arrow keys
    func testTheArrowKeysPickTheSeason() throws {
        let app = try launch()
        app.element("browse.section.series").tap()
        let poster = app.element("series.card.xtream#cabin#series#1")
        XCTAssertTrue(poster.waitForExistence(timeout: 10))
        poster.tap()
        let first = app.element("episodes.season.season-1")
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(first.isSelected)
        for _ in 0..<3 where !app.element("episodes.season.season-2").isSelected {
            // The simulator sometimes drops the first key press.
            app.typeKey(.rightArrow, modifierFlags: [])
        }
        expect(app.element("episodes.season.season-2"), "isSelected == true")
        XCTAssertTrue(app.element("episodes.row.xtream#cabin#episode#11").exists)
        app.typeKey(.leftArrow, modifierFlags: [])
        expect(app.element("episodes.season.season-1"), "isSelected == true")
    }
}
