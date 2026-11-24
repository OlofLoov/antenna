import XCTest

/// A person's page on iPhone (browse-by-person capability), on the scripted
/// sources of `UITestingShelf`. Mira Holt is in The Long Harbor's info
/// answer, in Quiet Engines' and Small Rooms' list rows, and directs Paper
/// Cities. The other titles have no names until their info call answers.
@MainActor
final class PersonUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func launch() throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", "titles", "-ui-testing-reduce-motion", "-mock-title-scores", "NO"]
        app.launchInEnglish()
        return app
    }

    func expect(_ element: XCUIElement, _ predicate: String, file: StaticString = #filePath, line: UInt = #line) {
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [wait], timeout: 15), .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    func card(_ app: XCUIApplication, in row: String, _ id: String) -> XCUIElement {
        app.element("person.row.\(row)").descendants(matching: .any)["person.row.\(row).card.\(id)"].firstMatch
    }

    // browse-by-person/pick-someone-in-the-cast
    // browse-by-person/a-person-s-page
    // browse-by-person/a-person-s-page-never-asks-the-provider, names from the list and from details
    func testPickANameSeeTheRowsOpenATitleAndComeBack() throws {
        let app = try launch()
        let tab = app.tabBars.buttons["Movies"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        expect(app.element("movies.hero.title"), "label == 'The Long Harbor'")
        app.element("movies.hero.info").tap()

        let chip = app.element("title.cast.0")
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertEqual(chip.label, "Mira Holt")
        chip.tap()

        XCTAssertTrue(app.element("person.header").waitForExistence(timeout: 5))
        expect(app.element("person.count"), "label == 'Acting · 4 in your sources'")
        XCTAssertTrue(card(app, in: "movies", "xtream#cabin#vod#1").waitForExistence(timeout: 5), "The Long Harbor, from its info answer")
        XCTAssertTrue(card(app, in: "movies", "xtream#cabin#vod#5").exists, "Quiet Engines, from its list row")
        XCTAssertTrue(card(app, in: "series", "xtream#cabin#series#3").exists, "Small Rooms, from its list row")
        XCTAssertTrue(card(app, in: "directed", "xtream#cabin#vod#4").exists, "Paper Cities, directed")
        XCTAssertFalse(card(app, in: "movies", "xtream#cabin#vod#2").exists, "Second Act names nobody yet")
        XCTAssertTrue(app.element("person.note").exists, "titles without names may be missing")
        XCTAssertTrue(app.tabBars.buttons["Movies"].exists, "the tab bar stays on iPhone")

        card(app, in: "movies", "xtream#cabin#vod#5").tap()
        expect(app.element("title.name"), "label == 'Quiet Engines'")
        expect(app.element("title.back"), "label == 'Back to Mira Holt'")
        XCTAssertEqual(app.element("title.cast.1").label, "Teodor Lind", "the row's names, split at the slash")

        app.element("title.back").tap()
        XCTAssertTrue(app.element("person.header").waitForExistence(timeout: 5))
        app.element("person.back").tap()
        expect(app.element("title.name"), "label == 'The Long Harbor'")
        XCTAssertTrue(app.element("title.cast.0").isHittable, "back on the page with the chip in view")

        app.element("title.back").tap()
        XCTAssertTrue(app.element("movies.hero.info").waitForExistence(timeout: 5))
    }

    // browse-by-person/the-same-person-across-titles, a placeholder in the list is not a name
    func testASeriesRowNamesItsCastWithoutPlaceholders() throws {
        let app = try launch()
        let tab = app.tabBars.buttons["Movies"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        app.element("movies.hero.info").tap()
        app.element("title.cast.0").tap()
        let smallRooms = card(app, in: "series", "xtream#cabin#series#3")
        XCTAssertTrue(smallRooms.waitForExistence(timeout: 5))
        smallRooms.tap()
        expect(app.element("title.name"), "label == 'Small Rooms'")
        XCTAssertEqual(app.element("title.cast.0").label, "Mira Holt")
        XCTAssertEqual(app.element("title.cast.1").label, "Teodor Lind")
        XCTAssertFalse(app.element("title.cast.2").exists, "N/A is not a name")
    }
}
