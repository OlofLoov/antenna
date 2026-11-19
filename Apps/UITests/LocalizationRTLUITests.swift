import XCTest

/// The iPhone app in Arabic, the one UI test class that does not launch in
/// English. It checks by identifier and frame that the layout reads from the
/// right, and attaches a screenshot of each screen it passes for review.
@MainActor
final class LocalizationRTLUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ arguments: [String], environment: [String: String] = [:]) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout runs on an iPhone")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = arguments + ["-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA"]
        app.launchEnvironment = environment
        app.launchInEnglish()
        return app
    }

    private func snap(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func label(_ app: XCUIApplication, _ id: String, is expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = app.element(id)
        let matches = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", expected), object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [matches], timeout: 10), .completed, "\(id) is \(element.label), expected \(expected)", file: file,
            line: line)
    }

    /// Plays News One with a 20-minute buffer and shows the controls.
    private func launchPlayer() throws -> XCUIApplication {
        let app = try launch(
            ["-ui-testing-live", "channels"],
            environment: ["UITESTING_TIMESHIFT": "buffer", "UITESTING_TIMESHIFT_MINUTES": "20.5", "TZ": "UTC"])
        XCTAssertTrue(app.row(0).waitForExistence(timeout: 10), "the channel list never appeared")
        app.row(0).tap()
        app.waitForEngine("playing loads=1")
        if !app.element("browse.player.controls").exists { app.element("browse.player.surface").tap() }
        XCTAssertTrue(app.element("browse.player.controls").waitForExistence(timeout: 3), "no controls")
        return app
    }

    // design-system/layouts-mirror-in-right-to-left-languages
    func testTheLiveListAndItsChipsReadFromTheRight() throws {
        let app = try launch(["-ui-testing-live", "channels"])
        XCTAssertTrue(app.row(0).waitForExistence(timeout: 10), "the channel list never appeared")
        let first = app.element("browse.group.0")
        let second = app.element("browse.group.1")
        XCTAssertTrue(first.exists && second.exists, "no group chips")
        XCTAssertGreaterThan(first.frame.minX, second.frame.maxX, "the first chip sits at the right")
        let tabs = app.tabBars.buttons.allElementsBoundByIndex
        XCTAssertGreaterThan(tabs.first?.frame.minX ?? 0, tabs.last?.frame.maxX ?? .infinity, "Live is the rightmost tab")
        snap("live")
    }

    // design-system/playback-glyphs-keep-their-meaning
    // design-system/progress-runs-in-the-reading-direction
    func testThePlayerStripMirrorsAndDragsTowardTheLeftMoveForward() throws {
        let app = try launchPlayer()
        let play = app.element("browse.player.playPause").frame
        XCTAssertGreaterThanOrEqual(app.element("timeshift.skipBack").frame.minX, play.maxX, "skip back sits right of play")
        XCTAssertLessThanOrEqual(app.element("timeshift.skipForward").frame.maxX, play.minX, "skip forward sits left of play")
        // design-system/copy-fits-in-every-language
        let live = app.element("browse.player.live")
        XCTAssertEqual(live.label, "مباشر")
        XCTAssertGreaterThan(live.frame.width, live.frame.height, "LIVE reads on one line, not a tall capsule")
        snap("player")
        XCTAssertGreaterThan(app.element("browse.player.progress").frame.width, 20, "the programme bar keeps its width")
        // A double tap on the right half skips back, where skip back is drawn.
        app.element("browse.player.surface").coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.3)).doubleTap()
        label(app, "timeshift.behindLive", is: "متأخر بـ ١ د")
        // The start of the buffer is the right end of the scrubber.
        let scrubber = app.element("timeshift.scrubber")
        let start = scrubber.coordinate(withNormalizedOffset: CGVector(dx: 1.0, dy: 0.5))
        let near = scrubber.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        near.press(forDuration: 0.1, thenDragTo: start)
        label(app, "timeshift.behindLive", is: "متأخر بـ ٢١ د")
        snap("player-behind")
    }

    // design-system/the-guide-s-time-axis-follows-the-reading-direction
    func testTheGuideStripRunsFromTheRight() throws {
        let app = try launch(["-ui-testing-live", "channels"])
        let tab = app.tabBars.buttons["الدليل"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "no Guide tab")
        tab.tap()
        XCTAssertTrue(app.element("guide.root").waitForExistence(timeout: 10), "the guide never appeared")
        let cards = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "guide.block.\(LiveUITests.home).0."))
            .allElementsBoundByIndex
        XCTAssertGreaterThan(cards.count, 1, "News One has a programme strip")
        let now = try XCTUnwrap(cards.first { $0.label.contains("Morning News") }, "no Morning News card")
        for card in cards where card != now {
            XCTAssertLessThan(card.frame.minX, now.frame.minX, "\(card.label) comes after Morning News, to its left")
        }
        snap("guide")
    }

    func testMoviesInArabic() throws {
        let app = try launch(["-ui-testing-shelf", "watching", "-ui-testing-reduce-motion"])
        let tab = app.tabBars.buttons["الأفلام"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "no Movies tab")
        tab.tap()
        sleep(2)
        snap("movies")
    }
}
