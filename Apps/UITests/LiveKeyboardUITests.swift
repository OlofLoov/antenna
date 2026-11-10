import XCTest

/// The filter field and the keyboard on iPad (live-tv-on-iphone-ipad-mac
/// capability), on the scripted launch of `LiveUITests`. Skips on an iPhone.
@MainActor
final class LiveKeyboardUITests: XCTestCase {
    nonisolated let log = FileManager.default.temporaryDirectory.appending(path: "live-engine-\(UUID().uuidString).log")

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: log)
    }

    private func launch() throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "the filter and the shortcuts are on iPad and Mac")
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"]
        app.launchEnvironment["UITESTING_ENGINE_LOG"] = log.path
        app.launch()
        XCTAssertTrue(app.row(0).waitForExistence(timeout: 10), "the channel list never appeared")
        return app
    }

    /// Presses the down arrow until the ring is on the first row. The
    /// simulator sometimes drops the first key press after launch.
    private func ringOnFirstRow(_ app: XCUIApplication) {
        for _ in 0..<3 {
            app.typeKey(.downArrow, modifierFlags: [])
            if app.row(0).value as? String == "Keyboard focus" { return }
        }
        XCTFail("the arrow keys never reached the list")
    }

    private var cabinFilm: String { "browse.row.00000000-0000-0000-0000-0000000000D2.0" }

    // live-tv-on-iphone-ipad-mac/type-to-narrow-the-list
    func testTypingNarrowsTheGroupAfterEveryKeystroke() throws {
        let app = try launch()
        let filter = app.element("browse.filter")
        filter.tap()

        filter.typeText("w")
        XCTAssertTrue(app.row(0).exists)
        XCTAssertTrue(app.row(1).exists)
        XCTAssertFalse(app.row(2).exists, "Sport One has no w")
        XCTAssertFalse(app.row(3).exists, "Kids One has no w")

        filter.typeText(" tw")
        XCTAssertTrue(app.row(1).waitForExistence(timeout: 2))
        XCTAssertFalse(app.row(0).exists)
        XCTAssertEqual(app.element("browse.header.count").label, "5 channels", "the header keeps the group's size")
    }

    // live-tv-on-iphone-ipad-mac/type-to-narrow-the-list, digits match the number
    func testDigitsMatchTheStartOfTheNumber() throws {
        let app = try launch()
        let filter = app.element("browse.filter")
        filter.tap()
        filter.typeText("5")

        XCTAssertTrue(app.element(cabinFilm).waitForExistence(timeout: 2))
        XCTAssertFalse(app.row(0).exists)
    }

    // live-tv-on-iphone-ipad-mac/type-to-narrow-the-list, clearing the filter
    func testClearingTheFilterBringsBackTheWholeGroup() throws {
        let app = try launch()
        let filter = app.element("browse.filter")
        filter.tap()
        filter.typeText("sport")
        XCTAssertFalse(app.row(0).exists)

        app.element("browse.filter.clear").tap()

        for position in 0..<4 {
            XCTAssertTrue(app.row(position).waitForExistence(timeout: 2), "row \(position) did not come back")
        }
        XCTAssertTrue(app.element(cabinFilm).exists)
    }

    // live-tv-on-iphone-ipad-mac/pick-a-group, the filter is cleared
    func testPickingAGroupClearsTheFilter() throws {
        let app = try launch()
        let filter = app.element("browse.filter")
        filter.tap()
        filter.typeText("news")

        app.element("browse.group.3").tap()

        XCTAssertTrue(app.row(2).waitForExistence(timeout: 2), "Sport lists Sport One")
        XCTAssertNotEqual(filter.value as? String, "news")
    }

    // live-tv-on-iphone-ipad-mac/keyboard-shortcuts
    func testArrowsMoveTheRingAndReturnPlays() throws {
        let app = try launch()

        ringOnFirstRow(app)
        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertEqual(app.row(1).value as? String, "Keyboard focus")
        app.waitForEngine("idle loads=0")

        // XCUITest sends the Return key for "\n"; `.return` reaches no key command.
        app.typeKey("\n", modifierFlags: [])
        app.waitForEngine("playing loads=1")
        XCTAssertTrue(app.row(1).isSelected)

        app.typeKey(" ", modifierFlags: [])
        app.waitForEngine("paused loads=1")
        app.typeKey(" ", modifierFlags: [])
        app.waitForEngine("playing loads=1")
    }

    // live-tv-on-iphone-ipad-mac/keyboard-shortcuts, holding an arrow key
    func testArrowsStopAtTheEndsWithoutSwitchingChannel() throws {
        let app = try launch()
        ringOnFirstRow(app)
        for _ in 0..<8 { app.typeKey(.downArrow, modifierFlags: []) }

        XCTAssertEqual(app.element(cabinFilm).value as? String, "Keyboard focus")
        app.waitForEngine("idle loads=0")
    }

    // live-tv-on-iphone-ipad-mac/keyboard-shortcuts, Command-F
    func testCommandFJumpsToTheFilter() throws {
        let app = try launch()
        ringOnFirstRow(app)
        app.typeKey("f", modifierFlags: .command)
        let filter = app.element("browse.filter")
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: filter)
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 3), .completed, "Command-F did not reach the filter")
        app.typeKey("k", modifierFlags: [])
        XCTAssertEqual((filter.value as? String)?.lowercased(), "k")

        app.typeKey(" ", modifierFlags: [])
        app.waitForEngine("idle loads=0")
        XCTAssertEqual((filter.value as? String)?.lowercased(), "k ", "Space types in the field")
    }
}
