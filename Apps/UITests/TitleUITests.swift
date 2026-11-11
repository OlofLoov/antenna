import XCTest

/// Movie and series pages on iPhone (title-detail-and-episode-picker
/// capability), on the scripted sources of `UITestingShelf`. The Long Harbor
/// has every detail and a trailer, Salt Road only a length.
@MainActor
final class TitleUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func launch(_ scenario: String = "titles") throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", scenario, "-ui-testing-reduce-motion"]
        app.launch()
        return app
    }

    func openSection(_ app: XCUIApplication, _ kind: String) {
        let tab = app.tabBars.buttons["Movies"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        if kind == "series" {
            app.element("movies.kind.series").tap()
        }
        XCTAssertTrue(app.element("\(kind).hero").waitForExistence(timeout: 10))
    }

    func card(_ app: XCUIApplication, _ prefix: String, in row: String, _ id: String) -> XCUIElement {
        app.element("\(prefix).row.\(row)").descendants(matching: .any)["\(prefix).card.\(id)"].firstMatch
    }

    func expect(_ element: XCUIElement, _ predicate: String, file: StaticString = #filePath, line: UInt = #line) {
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [wait], timeout: 5), .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    // title-detail-and-episode-picker/open-a-movie-s-page
    // title-detail-and-episode-picker/what-the-title-is-about
    func testMoreInfoOnTheBannerOpensTheMoviePageWithItsDetails() throws {
        let app = try launch()
        openSection(app, "movies")
        expect(app.element("movies.hero.title"), "label == 'The Long Harbor'")
        app.element("movies.hero.info").tap()

        XCTAssertTrue(app.element("title.name").waitForExistence(timeout: 5))
        XCTAssertEqual(app.element("title.name").label, "The Long Harbor")
        XCTAssertEqual(app.element("title.eyebrow").label, "Movie · Action")
        expect(app.element("title.meta"), "label CONTAINS '2024, 2 h 08 min, Thriller, rating 7.4, 15'")
        XCTAssertTrue(app.element("title.plot").exists)
        XCTAssertTrue(app.element("title.more").exists, "a long description is cut with More")
        XCTAssertTrue(app.element("title.cast").label.contains("Mira Holt"))
        XCTAssertTrue(app.element("title.director").label.contains("Sanna Weiss"))
        XCTAssertFalse(app.element("movies.hero").isHittable, "the page covers the section")
        XCTAssertTrue(app.tabBars.buttons["Movies"].exists, "the tab bar stays on iPhone")

        app.element("title.more").tap()
        expect(app.element("title.more"), "exists == false")

        app.element("title.back").tap()
        expect(app.element("title.name"), "exists == false")
        XCTAssertTrue(app.element("movies.hero.info").isHittable)
    }

    // title-detail-and-episode-picker/open-a-movie-s-page, from the poster's menu
    // title-detail-and-episode-picker/what-the-title-is-about, missing fields
    func testThePosterMenuOpensAMovieWithFieldsMissing() throws {
        let app = try launch()
        openSection(app, "movies")
        app.swipeUp()
        let poster = card(app, "movies", in: "action", "xtream#cabin#vod#3")
        XCTAssertTrue(poster.waitForExistence(timeout: 5))
        poster.press(forDuration: 1.2)
        let info = app.element("movies.menu.info")
        XCTAssertTrue(info.waitForExistence(timeout: 5))
        info.tap()

        XCTAssertTrue(app.element("title.name").waitForExistence(timeout: 5))
        XCTAssertEqual(app.element("title.name").label, "Salt Road")
        expect(app.element("title.meta"), "label == '1 h 32 min'")
        XCTAssertFalse(app.element("title.plot").exists)
        XCTAssertFalse(app.element("title.cast").exists)
        XCTAssertFalse(app.element("title.director").exists)
        XCTAssertFalse(app.element("title.trailer").exists)
        XCTAssertFalse(app.staticTexts["Unknown"].exists)
    }

    // title-detail-and-episode-picker/trailer
    func testTrailerOpensTheLinkOutsideThePage() throws {
        let app = try launch()
        openSection(app, "movies")
        expect(app.element("movies.hero.title"), "label == 'The Long Harbor'")
        app.element("movies.hero.info").tap()
        let trailer = app.element("title.trailer")
        XCTAssertTrue(trailer.waitForExistence(timeout: 5))
        trailer.tap()
        expect(app.element("shelf.debug.opened"), "value == 'https://trailers.example/long-harbor'")
    }

    // title-detail-and-episode-picker/open-a-series-page
    func testSelectingASeriesOpensItsPageWithoutPlaying() throws {
        let app = try launch()
        openSection(app, "series")
        let poster = card(app, "series", in: "recentlyAdded", "xtream#cabin#series#1")
        XCTAssertTrue(poster.waitForExistence(timeout: 5))
        poster.tap()

        XCTAssertTrue(app.element("title.name").waitForExistence(timeout: 5))
        XCTAssertEqual(app.element("title.name").label, "Northern Lights")
        XCTAssertEqual(app.element("title.eyebrow").label, "Series · Drama")
        expect(app.element("title.play"), "label == 'Play S2 E1'")
        expect(app.element("title.meta"), "label CONTAINS '1 season'")
        XCTAssertFalse(app.element("series.player").exists, "nothing plays")

        app.element("title.back").tap()
        XCTAssertTrue(app.element("series.hero.info").waitForExistence(timeout: 5))
        app.element("series.hero.info").tap()
        XCTAssertTrue(app.element("title.name").waitForExistence(timeout: 5))
    }
}
