import XCTest

/// Play on from iPhone (play-on-apple-tv capability), against the scripted
/// account and Apple TV of `UITestingPlayOn`: `one` has Living Room ready
/// now, `two` adds Bedroom, not open, `refused` has local network access
/// refused.
@MainActor
final class PlayOnUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ scenario: String?, answer: String? = nil, live: Bool = false) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = live ? ["-ui-testing-live", "channels"] : ["-ui-testing-shelf", "titles", "-ui-testing-reduce-motion"]
        if let scenario { app.launchArguments += ["-ui-testing-play-on", scenario] }
        if let answer { app.launchArguments += ["-ui-testing-play-on-answer", answer] }
        app.launchInEnglish()
        return app
    }

    /// Opens The Long Harbor's page from the Movies banner.
    private func openMovie(_ app: XCUIApplication) {
        let tab = app.tabBars.buttons["Movies"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        let info = app.element("movies.hero.info")
        XCTAssertTrue(info.waitForExistence(timeout: 10))
        info.tap()
        XCTAssertTrue(app.element("title.name").waitForExistence(timeout: 10))
    }

    private func probe(_ app: XCUIApplication) -> String {
        app.element("playOn.probe").label
    }

    private func expectSent(_ app: XCUIApplication, _ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let sent = app.element("playOn.sent")
        XCTAssertTrue(sent.waitForExistence(timeout: 5), "no line after the send", file: file, line: line)
        XCTAssertEqual(sent.label, text, file: file, line: line)
    }

    // play-on-apple-tv/apple-tvs-on-the-same-icloud-account
    func testNoAppleTVOnTheAccountShowsNoPlayOn() throws {
        let app = try launch("none")
        openMovie(app)
        XCTAssertTrue(app.element("title.myList").exists)
        XCTAssertFalse(app.element("title.playOn").exists)
        XCTAssertFalse(app.element("title.playOn.menu").exists)
        XCTAssertEqual(probe(app), "browser 0", "no Apple TV, no local network prompt")
    }

    // play-on-apple-tv/play-on-from-what-can-be-played
    // play-on-apple-tv/starts-at-once-on-the-same-network
    func testOneAppleTVSendsTheFilmAtOnce() throws {
        let app = try launch("one")
        openMovie(app)
        let button = app.element("title.playOn")
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        XCTAssertEqual(button.label, "Play on Living Room")
        XCTAssertEqual(probe(app), "browser 0", "the browser waits for the first tap on Play on")
        button.tap()
        expectSent(app, "Playing on Living Room")
        XCTAssertEqual(probe(app), "browser 1")
    }

    // play-on-apple-tv/play-on-from-what-can-be-played
    // play-on-apple-tv/apple-tvs-on-the-same-icloud-account
    func testTwoAppleTVsOpenAMenuSayingWhichStartsNow() throws {
        let app = try launch("two")
        openMovie(app)
        let menu = app.element("title.playOn.menu")
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        XCTAssertEqual(menu.label, "Play on")
        menu.tap()
        let rows = app.buttons.matching(identifier: "title.playOn.menu.device")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows.element(boundBy: 0).label.contains("Living Room"), rows.element(boundBy: 0).label)
        XCTAssertTrue(rows.element(boundBy: 0).label.contains("Ready now"), rows.element(boundBy: 0).label)
        XCTAssertTrue(rows.element(boundBy: 1).label.contains("Bedroom"), rows.element(boundBy: 1).label)
        XCTAssertTrue(rows.element(boundBy: 1).label.contains("Plays when Antuna opens there"), rows.element(boundBy: 1).label)
        XCTAssertEqual(probe(app), "browser 1", "opening the menu starts the browser")
        rows.element(boundBy: 0).tap()
        expectSent(app, "Playing on Living Room")
    }

    // play-on-apple-tv/the-local-network-is-asked-for-only-when-needed
    func testRefusedAccessListsEveryTVAsWaitingAndPointsAtSettings() throws {
        let app = try launch("refused")
        openMovie(app)
        let menu = app.element("title.playOn.menu")
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        menu.tap()
        let rows = app.buttons.matching(identifier: "title.playOn.menu.device")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        expect(app.buttons["playOn.menu.settings"], "label == 'Allow local network access'")
        for index in 0..<rows.count {
            XCTAssertTrue(rows.element(boundBy: index).label.contains("Plays when Antuna opens there"), rows.element(boundBy: index).label)
        }
    }

    // play-on-apple-tv/the-phone-says-why-the-tv-cannot-play
    func testTheTVsRefusalReadsInWords() throws {
        let app = try launch("one", answer: "needsPasscode")
        openMovie(app)
        let button = app.element("title.playOn")
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertEqual(alert.label, "Enter the passcode on Living Room.")
        alert.buttons["playOn.error.ok"].firstMatch.tap()
        XCTAssertFalse(alert.exists)
    }

    // play-on-apple-tv/play-on-from-what-can-be-played
    func testAChannelsMenuOffersPlayOn() throws {
        let app = try launch("one", live: true)
        XCTAssertTrue(app.row(1).waitForExistence(timeout: 10), "the channel list never appeared")
        app.row(1).press(forDuration: 1.2)
        let item = app.buttons["channel.menu.playOn"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        XCTAssertEqual(item.label, "Play on Living Room")
        item.tap()
        expectSent(app, "Playing on Living Room")
        XCTAssertTrue(app.element("browse.nothingSelected").exists, "the phone plays nothing itself")
    }

    // play-on-apple-tv/apple-tvs-on-the-same-icloud-account
    func testAChannelsMenuHasNoPlayOnWithoutATV() throws {
        let app = try launch("none", live: true)
        XCTAssertTrue(app.row(1).waitForExistence(timeout: 10), "the channel list never appeared")
        app.row(1).press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["browse.menu.favorite"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["channel.menu.playOn"].exists)
    }

    private func expect(_ element: XCUIElement, _ predicate: String, file: StaticString = #filePath, line: UInt = #line) {
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [wait], timeout: 10), .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }
}
