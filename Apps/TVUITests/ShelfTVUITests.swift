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
        page(.right, pager, to: "2 of 3")
        XCTAssertEqual(element("movies.hero.title").label, "Snow Day")
        press(.left, times: 2)
        expectFocus("movies.hero.play")
        page(.left, pager, to: "1 of 3")
        page(.left, pager, to: "3 of 3")
    }

    /// Presses `button` until the pager reads `value`, at most twice: tvOS
    /// can drop a press while the banner settles, and a press that landed
    /// changes the value, so this never pages twice.
    func page(_ button: XCUIRemote.Button, _ pager: XCUIElement, to value: String, file: StaticString = #filePath, line: UInt = #line) {
        press(button)
        let paged = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: pager)
        if XCTWaiter().wait(for: [paged], timeout: 3) == .completed { return }
        press(button)
        expect(pager, "value == '\(value)'", file: file, line: line)
    }

    // movies-and-series-browsing/browse-a-genre-or-sort-the-lot, on Apple TV
    func testAGenreOpensItsOwnScreenThatMenuCloses() {
        openMovies()
        let chips = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'movies.genres.' AND hasFocus == true"))
        for _ in 0..<10 where !chips.firstMatch.exists {
            press(.down)
            Thread.sleep(forTimeInterval: 1)
        }
        let first = element("movies.genres.myList")
        for _ in 0..<4 where !first.hasFocus {
            press(.left)
            Thread.sleep(forTimeInterval: 0.5)
        }
        expectFocus("movies.genres.myList")
        press(.right)
        expectFocus("movies.genres.all")
        press(.right)
        expectFocus("movies.genres.drama")
        press(.select)
        let grid = element("movies.grid")
        XCTAssertTrue(grid.waitForExistence(timeout: 5))
        XCTAssertFalse(element("movies.hero").exists)
        XCTAssertTrue(grid.staticTexts["2 titles"].exists)

        press(.menu)
        expect(grid, "exists == false")
        expectFocus("movies.hero.play")
        XCTAssertTrue(element("shell.tab.movies").isSelected)
    }

    // movies-and-series-browsing/keep-a-list-for-later, on Apple TV
    func testTheBannerAddsToMyList() {
        openMovies()
        press(.right, times: 2)
        expectFocus("movies.hero.myList")
        let button = element("movies.hero.myList")
        expect(button, "value == 'Not on My list'")
        press(.select)
        expect(button, "value == 'On My list'")
        XCTAssertTrue(element("movies.row.myList").waitForExistence(timeout: 5))
        press(.select)
        expect(button, "value == 'Not on My list'")
        expect(element("movies.row.myList"), "exists == false")
    }

    // movies-and-series-browsing/resume-where-you-left-off, on Apple TV
    func testPlayStartsTheMovieAndMenuGoesBack() {
        openMovies()
        press(.select)
        expect(element("shelf.debug.engine"), "value == 'playing 1.mp4 from 0'")
        expect(element("shell.debug.engine"), "value BEGINSWITH 'idle'")
        press(.menu)
        expect(element("movies.player"), "exists == false")
        expectFocus("movies.hero.play")
        press(.menu)
        expectFocus("shell.tab.movies")
        press(.left, times: 2)
        expectFocus("shell.tab.live")
        press(.select)
        expect(element("shell.debug.engine"), "value BEGINSWITH 'playing loads=2'")
    }
}
