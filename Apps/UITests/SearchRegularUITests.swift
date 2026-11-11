import XCTest

/// Search on iPad (search capability), on the scripted sources of
/// `UITestingShelf`. Skips on an iPhone.
@MainActor
final class SearchRegularUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func launch(_ scenario: String = "titles") throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "the sidebar layout runs on iPad and Mac")
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", scenario, "-ui-testing-reduce-motion"]
        app.launch()
        return app
    }

    /// Opens the Search section; the field is ready for typing.
    func openSearch(_ app: XCUIApplication) -> XCUIElement {
        let section = app.element("browse.section.search")
        XCTAssertTrue(section.waitForExistence(timeout: 10))
        section.tap()
        let field = app.element("search.field")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        expect(field, "hasKeyboardFocus == true")
        return field
    }

    func expect(
        _ element: XCUIElement, _ predicate: String, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line
    ) {
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [wait], timeout: timeout), .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    // search/results-grouped-best-first
    // search/narrow-to-one-kind
    func testResultsInSectionsWithChipsInTheContentColumn() throws {
        let app = try launch()
        let field = openSearch(app)
        field.typeText("sport")

        XCTAssertTrue(app.element("search.section.channels").waitForExistence(timeout: 5))
        expect(app.element("search.result.channel.0"), "label BEGINSWITH 'Channels, Sport One'")
        expect(app.element("search.result.programme.0"), "label BEGINSWITH 'In the guide, Sport Tonight'")
        expect(app.element("search.chip.all"), "label == 'All · 2'")
        app.element("search.chip.guide").tap()
        XCTAssertFalse(app.element("search.result.channel.0").waitForExistence(timeout: 1), "only the guide")
        XCTAssertTrue(app.element("search.result.programme.0").exists)
    }

    // search/search-with-a-keyboard
    func testCommandFArrowsAndReturnPickAResult() throws {
        let app = try launch()
        let field = openSearch(app)
        field.typeText("news")
        XCTAssertTrue(app.element("search.result.channel.1").waitForExistence(timeout: 5))

        // The simulator sometimes drops the first key press.
        for _ in 0..<3 where app.element("search.result.channel.0").value as? String != "Keyboard focus" {
            app.typeKey(.downArrow, modifierFlags: [])
        }
        expect(app.element("search.result.channel.0"), "value == 'Keyboard focus'")
        expect(field, "hasKeyboardFocus == false")
        app.typeKey(.downArrow, modifierFlags: [])
        expect(app.element("search.result.channel.1"), "value == 'Keyboard focus'")
        // XCUITest sends the Return key for "\n"; `.return` reaches no key command.
        app.typeKey("\n", modifierFlags: [])

        expect(app.element("browse.debug.engine"), "value == 'playing loads=1'")
        expect(app.element("browse.panel.now"), "label CONTAINS 'News Two'")

        app.element("browse.section.search").tap()
        app.typeKey("f", modifierFlags: .command)
        expect(app.element("search.field"), "hasKeyboardFocus == true")
        expect(app.element("search.field"), "value == 'news'", timeout: 2)
    }

    // search/clear-the-field
    func testClearEmptiesTheFieldAndKeepsItReady() throws {
        let app = try launch()
        let field = openSearch(app)
        field.typeText("kids")
        XCTAssertTrue(app.element("search.result.channel.0").waitForExistence(timeout: 5))
        app.element("search.clear").tap()
        expect(field, "hasKeyboardFocus == true")
        XCTAssertFalse(app.element("search.result.channel.0").exists)
    }

    // search/find-things-the-way-you-type-them, one letter
    func testOneLetterShowsNothing() throws {
        let app = try launch()
        let field = openSearch(app)
        field.typeText("s")
        XCTAssertFalse(app.element("search.chips").waitForExistence(timeout: 2))
        XCTAssertFalse(app.element("search.empty").exists)
    }

    // search/pick-a-programme
    func testPickingALaterProgrammeShowsItAsLaterUnderUpNext() throws {
        let app = try launch()
        let field = openSearch(app)
        field.typeText("late film")
        let result = app.element("search.result.programme.0")
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()

        expect(app.element("browse.panel.now"), "label CONTAINS 'News One'")
        let later = app.element("browse.later")
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        XCTAssertTrue(later.label.contains("Late Film"), later.label)
    }

    // title-detail-and-episode-picker/back-to-where-you-were
    func testBackFromASeriesPageReturnsToSearchWithTheQuery() throws {
        let app = try launch()
        let field = openSearch(app)
        field.typeText("harbor watch")
        let result = app.element("search.result.title.0")
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        result.tap()
        XCTAssertTrue(app.element("title.name").waitForExistence(timeout: 5))
        XCTAssertTrue(app.element("browse.section.search").isSelected, "the page shows in the Search column")

        app.element("title.back").tap()
        expect(app.element("title.name"), "exists == false")
        expect(app.element("search.field"), "value == 'harbor watch'")
        XCTAssertTrue(result.isHittable)
    }

    // search/recent-searches
    func testRecentSearchesInTheSidebarRunAgain() throws {
        let app = try launch()
        let field = openSearch(app)
        field.typeText("kids")
        let result = app.element("search.result.channel.0")
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        expect(app.element("browse.panel.now"), "label CONTAINS 'Kids One'")

        app.element("browse.section.search").tap()
        let recent = app.element("search.recent.0")
        XCTAssertTrue(recent.waitForExistence(timeout: 5), "the sidebar lists recent searches")
        XCTAssertEqual(recent.label, "Recent search, kids")
        app.element("search.clear").tap()
        recent.tap()
        expect(app.element("search.field"), "value == 'kids'")
        XCTAssertTrue(app.element("search.result.channel.0").waitForExistence(timeout: 5))
    }

    // movies-and-series-browsing/search-from-the-section
    func testTypingInTheMoviesToolbarOpensSearchWithTheText() throws {
        let app = try launch()
        let section = app.element("browse.section.movies")
        XCTAssertTrue(section.waitForExistence(timeout: 10))
        section.tap()
        let toolbar = app.textFields["movies.search"].firstMatch
        XCTAssertTrue(toolbar.waitForExistence(timeout: 10))
        toolbar.tap()
        toolbar.typeText("h")

        let field = app.element("search.field")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        expect(field, "value == 'h'")
        expect(field, "hasKeyboardFocus == true")
        field.typeText("arbor")
        XCTAssertTrue(app.element("search.result.title.0").waitForExistence(timeout: 10))
        XCTAssertTrue(app.element("search.chip.movies").isSelected)
        XCTAssertFalse(app.element("search.result.title.1").exists, "only movies")
    }
}
