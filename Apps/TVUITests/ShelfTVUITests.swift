import XCTest

/// Movies and Series on Apple TV (movies-and-series-browsing capability).
/// Launches the shell's `channels` scenario, whose Xtream source answers with
/// the scripted titles of `UITestingShelf`: Night Ferry, Snow Day and Copper
/// Hills, newest first.
@MainActor
final class ShelfTVUITests: XCTestCase {
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

    /// The shell's `channels` scenario with its first channel playing full screen.
    func launchPlaying() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels"]
        app.launch()
        expectFocus("shell.picture")
        expect(element("zapBar.bar"), "exists == false")
    }

    /// Movies open from the bar, with focus on the banner's Play button.
    func openMovies() {
        launchPlaying()
        press(.menu)
        press(.right, times: 2)
        expectFocus("shell.tab.movies")
        press(.select)
        expectFocus("movies.hero.play")
    }

    // movies-and-series-browsing/movies-and-series-appear-when-your-provider-has-them
    // tvos-shell/the-tabs-in-order
    func testMoviesAndSeriesOpenFromTheTabBar() {
        openMovies()
        XCTAssertTrue(element("movies.row.recentlyAdded").exists)
        press(.up)
        expectFocus("shell.tab.movies")
        press(.right)
        expectFocus("shell.tab.series")
        press(.select)
        expectFocus("series.hero.play")
    }

    // movies-and-series-browsing/movies-and-series-appear-when-your-provider-has-them, no Xtream source
    // tvos-shell/the-tabs-in-order
    func testNoXtreamSourceHasNoMoviesTab() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", "noXtream"]
        app.launch()
        press(.menu)
        XCTAssertTrue(element("shell.tab.live").waitForExistence(timeout: 10))
        XCTAssertTrue(element("shell.tab.search").exists)
        XCTAssertFalse(element("shell.tab.movies").exists)
        XCTAssertFalse(element("shell.tab.series").exists)
    }

    // movies-and-series-browsing/new-titles-up-front
    func testSwipingPastTheButtonsPagesTheBanner() {
        openMovies()
        let pager = element("movies.hero.pager")
        expect(pager, "value == '1 of 3'")
        XCTAssertEqual(element("movies.hero.title").label, "Night Ferry")
        press(.right, times: 2)
        expectFocus("movies.hero.myList")
        press(.right)
        expect(pager, "value == '2 of 3'")
        XCTAssertEqual(element("movies.hero.title").label, "Snow Day")
        press(.left, times: 2)
        expectFocus("movies.hero.play")
        press(.left)
        expect(pager, "value == '1 of 3'")
        press(.left)
        expect(pager, "value == '3 of 3'", timeout: 5)
    }
}
