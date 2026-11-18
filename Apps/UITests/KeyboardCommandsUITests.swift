import XCTest

/// The Playback and Go menus' keys on an iPad with a keyboard
/// (keyboard-commands capability). Skips on an iPhone, which has no menus.
@MainActor
final class KeyboardCommandsUITests: XCTestCase {
    nonisolated let log = FileManager.default.temporaryDirectory.appending(path: "live-engine-\(UUID().uuidString).log")

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: log)
    }

    private func launchLive(multiView: Bool = false) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "the menus are on iPad and Mac")
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"]
        app.launchEnvironment["UITESTING_ENGINE_LOG"] = log.path
        if multiView { app.launchEnvironment["UITESTING_MULTIVIEW"] = "1" }
        app.launch()
        XCTAssertTrue(app.row(0).waitForExistence(timeout: 10), "the channel list never appeared")
        app.row(0).tap()
        app.waitForEngine("playing loads=1")
        return app
    }

    private func expect(_ element: XCUIElement, _ predicate: String, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: 5), .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    /// Presses `key` until `element` matches `predicate`, up to three times.
    /// The simulator sometimes drops the first key press after launch or a tap.
    private func press(
        _ app: XCUIApplication, _ key: String, _ modifiers: XCUIElement.KeyModifierFlags, until element: XCUIElement, _ predicate: String
    ) {
        for _ in 0..<3 {
            app.typeKey(key, modifierFlags: modifiers)
            let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
            if XCTWaiter().wait(for: [expectation], timeout: 2) == .completed { return }
        }
    }

    // keyboard-commands/go-to-a-section
    func testCommandTwoOpensTheGuideAndTheChannelPlaysOn() throws {
        let app = try launchLive()
        let toolbar = app.element("guide.toolbar")

        press(app, "2", .command, until: toolbar, "exists == true")

        XCTAssertTrue(toolbar.exists, "Command-2 did not open the Guide")
        app.waitForEngine("playing loads=1")
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 5), "Command-1 did not bring Live back")
    }

    // keyboard-commands/menu-items-follow-the-screen-in-front, Space on Live
    func testSpacePausesTheChannel() throws {
        let app = try launchLive()

        app.typeKey(" ", modifierFlags: [])
        app.waitForEngine("paused loads=1")
        app.typeKey(" ", modifierFlags: [])
        app.waitForEngine("playing loads=1")
    }

    // keyboard-commands/typing-is-never-taken-by-a-shortcut
    func testMAndSpaceTypeInTheFilter() throws {
        let app = try launchLive()
        let filter = app.element("browse.filter")
        filter.tap()

        app.typeKey("m", modifierFlags: [])
        app.typeKey(" ", modifierFlags: [])

        XCTAssertEqual((filter.value as? String)?.lowercased(), "m ", "M and Space type in the field")
        app.waitForEngine("playing loads=1")
    }

    // keyboard-commands/menu-items-follow-the-screen-in-front, multi-view
    func testOptionCommandTwoSelectsTheSecondTile() throws {
        let app = try launchLive(multiView: true)
        app.row(1).press(forDuration: 1.2)
        let item = app.buttons["browse.menu.multiView"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "no Add to Multi-view in the menu")
        item.tap()
        let first = app.element("multiView.tile.1")
        let second = app.element("multiView.tile.2")
        XCTAssertTrue(second.waitForExistence(timeout: 5), "no grid")
        expect(second, "isSelected == true")

        press(app, "1", [.command, .option], until: first, "isSelected == true")
        expect(first, "isSelected == true")
        app.typeKey("2", modifierFlags: [.command, .option])
        expect(second, "isSelected == true")
        XCTAssertTrue(app.element("multiView.root").exists, "Command-2 is the Guide; Option-Command-2 stays in multi-view")
    }

    // keyboard-commands/menu-items-follow-the-screen-in-front, the movie player
    func testSpaceAndTheArrowsInTheMoviePlayer() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "the menus are on iPad and Mac")
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", "watching", "-ui-testing-reduce-motion"]
        app.launch()
        let movies = app.element("browse.section.movies")
        XCTAssertTrue(movies.waitForExistence(timeout: 10), "the sidebar never appeared")
        movies.tap()
        let row = app.element("movies.row.continueWatching")
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let poster = row.descendants(matching: .any)["movies.card.xtream#cabin#vod#2"].firstMatch
        XCTAssertTrue(poster.waitForExistence(timeout: 5))
        poster.tap()
        let engine = app.element("shelf.debug.engine")
        expect(engine, "value == 'playing 2.mp4 from 2160'")

        press(app, " ", [], until: engine, "value == 'paused 2.mp4 from 2160'")
        expect(engine, "value == 'paused 2.mp4 from 2160'")
        app.typeKey(" ", modifierFlags: [])
        expect(engine, "value == 'playing 2.mp4 from 2160'")
        app.typeKey(XCUIKeyboardKey.rightArrow.rawValue, modifierFlags: [])
        expect(app.element("shelf.debug.position"), "value == 'at 2170'")
    }
}
