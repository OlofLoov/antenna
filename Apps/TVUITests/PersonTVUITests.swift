import XCTest

/// A person's page on Apple TV (browse-by-person capability), on the shelf's
/// `titles` script. The Movies banner opens on The Long Harbor, whose info
/// answer names Mira Holt first.
@MainActor
final class PersonTVUITests: XCTestCase {
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

    // browse-by-person/pick-someone-in-the-cast, Apple TV focus
    // browse-by-person/a-person-s-page, Apple TV focus and going back
    // tvos-shell/the-tab-bar-stays-hidden-on-a-title-page
    func testDownFromTheButtonsPicksANameAndMenuComesBackToIt() {
        app.launchArguments = ["-ui-testing-shelf", "titles"]
        app.launchInEnglish()
        // The system bar takes Menu only once something on the page has focus.
        _ = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch.waitForExistence(timeout: 10)
        press(.menu)
        XCTAssertTrue(element("shell.tab.movies").waitForExistence(timeout: 10))
        moveAlongTheBar(.right, to: "shell.tab.movies")
        press(.select)
        expectFocus("movies.hero.play")
        XCTAssertEqual(element("movies.hero.title").label, "The Long Harbor")
        press(.right)
        expectFocus("movies.hero.info")
        press(.select)
        expectFocus("title.play")

        press(.down)
        expectFocus("title.cast.0")
        XCTAssertEqual(element("title.cast.0").label, "Mira Holt")
        press(.right)
        expectFocus("title.cast.1")
        press(.left)
        expectFocus("title.cast.0")
        press(.select)

        XCTAssertTrue(element("person.header").waitForExistence(timeout: 5))
        expectFocus("person.row.movies.card.xtream#cabin#vod#1")
        XCTAssertFalse(element("shell.tab.movies").exists, "no tab bar on the person's page")
        expect(element("person.count"), "label == 'Acting · 4 in your sources'")

        press(.right)
        expectFocus("person.row.movies.card.xtream#cabin#vod#5")
        press(.select)
        expect(element("title.name"), "label == 'Quiet Engines'")
        press(.menu)
        expectFocus("person.row.movies.card.xtream#cabin#vod#5")

        press(.menu)
        expect(element("title.name"), "label == 'The Long Harbor'")
        expectFocus("title.cast.0")
        press(.menu)
        expectFocus("movies.hero.info")
    }
}
