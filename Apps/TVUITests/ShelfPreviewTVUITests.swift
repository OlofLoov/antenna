import XCTest

/// The preview at the top of Movies and Series on Apple TV
/// (movies-and-series-browsing/preview-of-the-focused-title-on-apple-tv).
/// Launches the shell's `channels` scenario, whose Movies are Night Ferry,
/// Snow Day and Copper Hills, or the shelf's `titles` script.
@MainActor
final class ShelfPreviewTVUITests: XCTestCase {
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
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    func expectFocus(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        expect(element(identifier), "hasFocus == true", file: file, line: line)
    }

    /// The identifier of the element with focus, for failure messages.
    var focused: String {
        let match = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
        return match.exists ? match.identifier : "nothing"
    }

    /// The number of info calls the scripted shelf has been asked.
    var infoLoads: Int {
        Int(element("shelf.debug.infoLoads").value as? String ?? "") ?? -1
    }

    /// Movies open from the bar in the shell's `channels` scenario, with
    /// focus on the banner's Play button.
    func openMovies() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels"]
        app.launchInEnglish()
        expectFocus("shell.picture")
        expect(element("zapBar.bar"), "exists == false")
        press(.menu)
        press(.right, times: 2)
        expectFocus("shell.tab.movies")
        press(.select)
        expectFocus("movies.hero.play")
        // Play takes focus a second time once the titles have loaded.
        Thread.sleep(forTimeInterval: 1)
    }

    /// A section opened from the bar with the shelf's `titles` script.
    func open(_ tab: String, rights: Int) {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", "titles"]
        app.launchInEnglish()
        press(.menu)
        XCTAssertTrue(element("shell.tab.\(tab)").waitForExistence(timeout: 10))
        expectFocus("shell.tab.live")
        press(.right, times: rights)
        expectFocus("shell.tab.\(tab)")
        press(.select)
        expectFocus("\(tab).hero.play")
        // Play takes focus a second time once the titles have loaded.
        Thread.sleep(forTimeInterval: 1)
    }

    // movies-and-series-browsing/preview-of-the-focused-title-on-apple-tv
    func testRestingOnAPosterShowsItsPreview() {
        openMovies()
        XCTAssertEqual(element("movies.hero.title").label, "Night Ferry")
        press(.down)
        expect(element("movies.preview"), "exists == true")
        XCTAssertTrue(focused.hasPrefix("movies.card."), focused)
        expect(element("movies.preview.title"), "label == 'Night Ferry'")
        // The row comes up just under the preview's 520 pt.
        let row = element("movies.row.recentlyAdded")
        for _ in 0..<10 where !(520...590).contains(row.frame.minY) {
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTAssertTrue((520...590).contains(row.frame.minY), "the row's top is at \(row.frame.minY)")

        press(.right)
        expect(element("movies.preview.title"), "label == 'Snow Day'", timeout: 5)
        expect(element("movies.preview.facts"), "label CONTAINS '2002'")
        expect(element("movies.preview.plot"), "label == 'The story of Snow Day.'")
    }

    // movies-and-series-browsing/preview-of-the-focused-title-on-apple-tv, moving quickly along a row
    // movies-and-series-browsing/title-details-are-asked-once-per-title
    func testAFastSwipeAsksNothingOnTheWay() {
        open("movies", rights: 2)
        press(.down)
        expect(element("movies.preview"), "exists == true")
        Thread.sleep(forTimeInterval: 2)
        let before = infoLoads
        XCTAssertGreaterThanOrEqual(before, 0)
        // Each press lands well inside the 0.8 second rest.
        press(.right, times: 3)
        Thread.sleep(forTimeInterval: 2)
        XCTAssertLessThanOrEqual(infoLoads, before + 1, "only the poster the highlight stopped on is asked about")
    }

    // movies-and-series-browsing/preview-of-the-focused-title-on-apple-tv, back to the banner
    func testUpFromTheFirstRowGoesBackToTheBanner() {
        openMovies()
        press(.down)
        expect(element("movies.preview"), "exists == true")
        press(.up)
        expectFocus("movies.hero.play")
        expect(element("movies.preview"), "exists == false")
        XCTAssertEqual(element("movies.hero.title").label, "Night Ferry", "the banner shows the title it showed before")
    }

    // movies-and-series-browsing/preview-of-the-focused-title-on-apple-tv, back from a title page
    // movies-and-series-browsing/title-details-are-asked-once-per-title, the page uses the kept answer
    func testBackFromAPageShowsThePreviewAtOnce() {
        open("series", rights: 3)
        press(.down)
        expectFocus("series.card.xtream#cabin#series#2")
        press(.right, times: 2)
        expectFocus("series.card.xtream#cabin#series#1")
        expect(element("series.preview.title"), "label == 'Northern Lights'", timeout: 5)
        expect(element("series.preview.plot"), "label == 'A series about Northern Lights.'")
        let asked = infoLoads
        press(.select)
        expectFocus("title.play")
        XCTAssertEqual(infoLoads, asked, "the page uses the preview's answer")
        press(.menu)
        expectFocus("series.card.xtream#cabin#series#1")
        expect(element("series.preview.title"), "label == 'Northern Lights'", timeout: 2)
        XCTAssertEqual(infoLoads, asked)
    }
}
