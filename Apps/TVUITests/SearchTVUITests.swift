import XCTest

/// The Search tab on Apple TV (search capability), on the scripted shell
/// of `ShellUITests`: Channel a1 to a3 and b1, a1's Morning News on now with
/// Weather, Business, Sport Tonight and Late Film after it, and b1's Evening
/// Film on now.
@MainActor
final class SearchTVUITests: XCTestCase {
    let remote = XCUIRemote.shared
    var app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    func press(_ button: XCUIRemote.Button, times: Int = 1) {
        for _ in 0..<times { remote.press(button) }
    }

    func expect(
        _ element: XCUIElement, _ predicate: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: timeout), .completed, "\(element) never matched \(predicate)", file: file,
            line: line)
    }

    func expectFocus(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        expect(element(identifier), "hasFocus == true", file: file, line: line)
    }

    func expectEngine(_ summary: String, file: StaticString = #filePath, line: UInt = #line) {
        expect(element("shell.debug.engine"), "value == '\(summary)'", file: file, line: line)
    }

    /// What has focus, for failure messages.
    func focusedElements() -> String {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex
            .map { "[\($0.identifier) '\($0.label)']" }.joined(separator: " ")
    }

    /// Launches with a1 playing and opens the Search tab from the bar.
    func openSearch() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels"]
        app.launch()
        expectEngine("playing loads=1 file=a1.ts")
        expectFocus("shell.picture")
        expect(element("zapBar.bar"), "exists == false")
        press(.menu)
        expectFocus("shell.tab.live")
        press(.right, times: 4)
        expectFocus("shell.tab.search")
        press(.select)
        XCTAssertTrue(element("search.results").waitForExistence(timeout: 10))
        expectFocus("shell.tab.search")
        press(.down)
    }

    /// Types `text` with the search keyboard.
    func type(_ text: String) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.typeText(text)
    }

    /// Swipes down from the keyboard until a result has focus.
    func moveToResults(_ identifier: String) {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        for _ in 0..<4 {
            if target.hasFocus { return }
            press(.down)
            _ = XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasFocus == true"), object: target)], timeout: 2)
        }
        XCTAssertTrue(target.hasFocus, "never reached \(identifier); focused: \(focusedElements())")
    }

    // search/results-grouped-best-first
    // search/very-long-result-lists, Apple TV lists every programme
    func testEverySectionShowsWithoutChips() {
        openSearch()
        type("film")
        let first = element("search.result.programme.0")
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        XCTAssertTrue(first.label.hasPrefix("In the guide, Evening Film, Now Channel b1"), first.label)
        XCTAssertTrue(element("search.result.programme.1").label.hasPrefix("In the guide, Late Film"))
        XCTAssertFalse(element("search.chips").exists, "Apple TV shows every section")
        XCTAssertFalse(element("search.section.channels").exists)
    }

    // search/pick-a-channel-or-title-to-watch
    func testPickingAChannelPlaysItFullScreen() {
        openSearch()
        type("a2")
        moveToResults("search.result.channel.0")
        press(.select)
        expectEngine("playing loads=2 file=a2.ts")
        expectFocus("shell.picture")
    }

    // search/pick-a-channel-or-title-to-watch, back from a result to the keyboard
    func testSwipingUpFromAResultReachesTheKeyboard() {
        openSearch()
        type("a2")
        moveToResults("search.result.channel.0")
        press(.up)
        expect(element("search.result.channel.0"), "hasFocus == false")
        XCTAssertFalse(element("shell.tab.search").hasFocus, "one swipe up lands on the keyboard: \(focusedElements())")
        app.searchFields.firstMatch.typeText("x")
        expect(app.searchFields.firstMatch, "value == 'a2x'")
    }

    // search/pick-a-programme
    func testPickingAProgrammeOnNowPlaysItsChannel() {
        openSearch()
        type("evening")
        moveToResults("search.result.programme.0")
        press(.select)
        expectEngine("playing loads=2 file=b1.ts")
    }

    // search/pick-a-programme
    func testPickingALaterProgrammeOpensTheGuideAtIt() {
        openSearch()
        type("late film")
        moveToResults("search.result.programme.0")
        press(.select)
        expectFocus("guide.grid")
        expect(element("guide.panel.title"), "label == 'Late Film'")
        expectEngine("playing loads=1 file=a1.ts")
    }

    // programme-reminders/remind-me-appears-only-before-a-programme-starts, in Search on Apple TV
    func testTheBellAfterALaterProgrammeSetsAReminder() {
        openSearch()
        type("late film")
        moveToResults("search.result.programme.0")
        press(.right)
        let bell = element("search.result.programme.0.remind")
        expectFocus("search.result.programme.0.remind")
        XCTAssertEqual(bell.label, "Remind me")
        press(.select)
        expect(bell, "label == 'Reminder set'")
        XCTAssertTrue(element("search.results").exists, "the bell left Search")
        expectEngine("playing loads=1 file=a1.ts")
    }

    // title-detail-and-episode-picker/back-to-where-you-were
    func testMenuOnASeriesPageReturnsToSearchWithTheQuery() {
        openSearch()
        type("long winter")
        moveToResults("search.result.title.0")
        press(.select)
        XCTAssertTrue(element("title.name").waitForExistence(timeout: 10))
        XCTAssertFalse(element("shell.tab.search").exists, "the page hides the tab bar")

        press(.menu)
        expect(element("title.name"), "exists == false")
        expect(app.searchFields.firstMatch, "value BEGINSWITH 'long winter'")
        XCTAssertTrue(element("search.result.title.0").exists)
    }

    // search/recent-searches
    func testRecentSearchesShowWithAnEmptyField() {
        openSearch()
        type("a2")
        moveToResults("search.result.channel.0")
        press(.select)
        expectEngine("playing loads=2 file=a2.ts")
        expectFocus("shell.picture")
        expect(element("zapBar.bar"), "exists == false")

        press(.menu)
        expectFocus("shell.tab.live")
        press(.right, times: 4)
        expectFocus("shell.tab.search")
        press(.select)
        press(.down)
        let field = app.searchFields.firstMatch
        expect(field, "value BEGINSWITH 'a2'")
        field.typeText(XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue)
        let recent = element("search.recent.0")
        XCTAssertTrue(recent.waitForExistence(timeout: 10), "an empty field lists recent searches")
        XCTAssertEqual(recent.label, "Recent search, a2")
    }

    // movies-and-series-browsing/search-from-the-section
    func testMoviesHasNoSearchButtonOnAppleTV() {
        openSearch()
        press(.menu)
        press(.left, times: 2)
        expectFocus("shell.tab.movies")
        press(.select)
        XCTAssertTrue(element("movies.hero").waitForExistence(timeout: 10))
        XCTAssertFalse(element("movies.search").exists, "the Search tab is the way to search")
    }
}
