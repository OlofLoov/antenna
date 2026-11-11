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

    // title-detail-and-episode-picker/trailer, none on Apple TV
    func testThereIsNoTrailerOnAppleTV() {
        openMoviePage()
        XCTAssertTrue(element("title.myList").exists)
        XCTAssertFalse(element("title.trailer").exists)
    }
}
