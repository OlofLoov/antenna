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
        app.launchInEnglish()
        XCTAssertTrue(app.row(0).waitForExistence(timeout: 10), "the channel list never appeared")
        return app
    }

    /// Presses the down arrow until the ring is on the first row.
    private func ringOnFirstRow(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        ring(onto: app.row(0), app, file: file, line: line)
    }

    /// Presses the down arrow until `row` has the ring. The simulator drops
    /// a key press now and then, so each press gets five seconds to show
    /// before the next, enough on a loaded runner; a press that was only
    /// slow would otherwise carry the ring past `row`. The sidebar's group search once took the first arrow
    /// key and kept every later one, so a failure names what holds the keyboard.
    private func ring(onto row: XCUIElement, _ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let ringed = NSPredicate(format: "value == 'Keyboard focus'")
        for _ in 0..<4 {
            app.typeKey(.downArrow, modifierFlags: [])
            let shown = XCTNSPredicateExpectation(predicate: ringed, object: row)
            if XCTWaiter().wait(for: [shown], timeout: 5) == .completed { return }
        }
        XCTFail("the arrow keys never moved the ring to \(row.identifier); \(ringState(app))", file: file, line: line)
    }

    /// Which row has the ring and what holds the keyboard, for failure messages.
    private func ringState(_ app: XCUIApplication) -> String {
        let rows = (0..<4).map { app.row($0) } + [app.element(cabinFilm)]
        let ring = rows.firstIndex { $0.value as? String == "Keyboard focus" }
        let holder = app.descendants(matching: .any).matching(NSPredicate(format: "hasKeyboardFocus == true"))
            .allElementsBoundByIndex.map(\.identifier)
        return "ring on row \(ring.map(String.init) ?? "none"), keyboard in \(holder)"
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
        ring(onto: app.row(1), app)
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

    // live-tv-on-iphone-ipad-mac/keyboard-shortcuts. On iPadOS 26 nothing
    // held first responder after launch, so the list's shortcuts missed
    // presses and in some launches every press until a tap. The simulator
    // spends the first key after launch on attaching its keyboard, so two
    // presses must reach the list without a tap.
    func testTheArrowsReachTheListWithoutATap() throws {
        let app = try launch()
        app.waitForEngine("idle loads=0")
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.downArrow, modifierFlags: [])
        let deadline = Date.now.addingTimeInterval(5)
        func ringed() -> Bool { [app.row(0), app.row(1)].contains { $0.value as? String == "Keyboard focus" } }
        while !ringed(), Date.now < deadline { RunLoop.current.run(until: .now.addingTimeInterval(0.5)) }
        XCTAssertTrue(ringed(), "two arrow presses did nothing; \(ringState(app))")
    }

    // live-tv-on-iphone-ipad-mac/keyboard-shortcuts, holding an arrow key
    func testArrowsStopAtTheEndsWithoutSwitchingChannel() throws {
        let app = try launch()
        ringOnFirstRow(app)
        for _ in 0..<8 { app.typeKey(.downArrow, modifierFlags: []) }
        // Five rows, so eight presses run past the end even when one is dropped.
        let last = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Keyboard focus'"), object: app.element(cabinFilm))
        XCTAssertEqual(XCTWaiter().wait(for: [last], timeout: 3), .completed, "the ring is not on the last row; \(ringState(app))")
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
