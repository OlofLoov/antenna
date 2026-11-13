import XCTest

/// Movie and series pages on Apple TV (title-detail-and-episode-picker
/// capability), from the shell's `channels` scenario. The Movies banner opens
/// on Night Ferry.
@MainActor
final class TitleTVUITests: XCTestCase {
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

    /// Movies open from the bar, then More info on the banner.
    func openMoviePage() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels"]
        app.launch()
        expectFocus("shell.picture")
        expect(element("zapBar.bar"), "exists == false")
        press(.menu)
        press(.right, times: 2)
        expectFocus("shell.tab.movies")
        press(.select)
        expectFocus("movies.hero.play")
        press(.right)
        expectFocus("movies.hero.info")
        press(.select)
        expectFocus("title.play")
    }

    // title-detail-and-episode-picker/open-a-movie-s-page
    // tvos-shell/the-tab-bar-stays-hidden-on-a-title-page
    func testTheMoviePageHidesTheTabBarAndSwipingUpStaysOnIt() {
        openMoviePage()
        XCTAssertEqual(element("title.name").label, "Night Ferry")
        XCTAssertFalse(element("shell.tab.movies").exists, "no tab bar on the page")
        XCTAssertFalse(element("shell.clock").exists, "no clock on the page")

        press(.up, times: 3)
        XCTAssertTrue(element("title.name").exists, "the page stays open")
        XCTAssertFalse(element("shell.tab.movies").exists)

        press(.menu)
        expect(element("title.name"), "exists == false")
        XCTAssertTrue(element("shell.tab.movies").waitForExistence(timeout: 5), "the bar comes back with the section")
    }

    // title-detail-and-episode-picker/trailer, a stream plays in the app on Apple TV
    func testATrailerThatIsAStreamPlaysInTheApp() {
        openMoviePage()
        press(.right, times: 2)
        expectFocus("title.trailer")
        press(.select)
        expect(element("shelf.debug.engine"), "value == 'playing night-ferry.m3u8 from 0'")
        press(.menu)
        expect(element("movies.player"), "exists == false")
        XCTAssertTrue(element("title.name").exists, "back on the page")
    }

    /// Series from the bar with the shelf's `titles` script, then Northern
    /// Lights, the third poster in Recently added.
    func openNorthernLights() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", "titles"]
        app.launch()
        press(.menu)
        XCTAssertTrue(element("shell.tab.series").waitForExistence(timeout: 10))
        press(.right, times: 3)
        expectFocus("shell.tab.series")
        press(.select)
        expectFocus("series.hero.play")
        press(.down)
        expectFocus("series.card.xtream#cabin#series#2")
        press(.right, times: 2)
        expectFocus("series.card.xtream#cabin#series#1")
        press(.select)
        expectFocus("title.play")
    }

    // title-detail-and-episode-picker/pick-a-season, resting on a chip
    // title-detail-and-episode-picker/what-each-episode-shows
    func testRestingOnASeasonChipShowsItsEpisodes() {
        openNorthernLights()
        XCTAssertEqual(element("title.play").label, "Play S1 E1")
        expect(element("episodes.season.season-1"), "isSelected == true")
        press(.down)
        expectFocus("episodes.season.season-1")
        press(.right)
        expectFocus("episodes.season.season-2")
        expect(element("episodes.season.season-2"), "isSelected == true", timeout: 3)
        XCTAssertTrue(element("episodes.row.xtream#cabin#episode#11").waitForExistence(timeout: 3))
        XCTAssertFalse(element("episodes.row.xtream#cabin#episode#101").exists)
        press(.down)
        expectFocus("episodes.row.xtream#cabin#episode#11")
        XCTAssertEqual(element("episodes.row.xtream#cabin#episode#11").label, "Episode 1, The Weir, 45 min")
    }

    // title-detail-and-episode-picker/back-to-where-you-were, from the banner
    func testMenuGoesBackToMoreInfoOnTheBanner() {
        openMoviePage()
        press(.menu)
        expectFocus("movies.hero.info")
        XCTAssertEqual(element("movies.hero.title").label, "Night Ferry")
    }

    // title-detail-and-episode-picker/back-to-where-you-were, from a poster deep in a row
    func testMenuGoesBackToThePosterThatOpenedThePage() {
        openNorthernLights()
        press(.menu)
        expectFocus("series.card.xtream#cabin#series#1")
        XCTAssertTrue(element("series.row.recentlyAdded").exists, "the rows stay as they were")
    }
}
