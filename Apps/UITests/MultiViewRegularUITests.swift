import XCTest

/// Multi-view in the iPad window (multi-view capability). Runs on an iPad
/// simulator; on an iPhone every test skips. `UITESTING_MULTIVIEW` plays
/// through a routed scripted engine so the grid can start.
@MainActor
final class MultiViewRegularUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launchPlaying() throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "multi-view needs an iPad")
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"]
        app.launchEnvironment["UITESTING_MULTIVIEW"] = "1"
        app.launch()
        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 10), "the channel list never appeared")
        app.row(0).tap()
        app.waitForEngine("playing loads=1")
        return app
    }

    private func addToMultiView(_ app: XCUIApplication, row: Int) {
        app.row(row).press(forDuration: 1.2)
        let item = app.buttons["browse.menu.multiView"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "no Add to Multi-view in the menu")
        item.tap()
    }

    private func expect(_ element: XCUIElement, _ predicate: String, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: 5), .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    // multi-view/start-multi-view-on-an-ipad
    func testHoldingAChannelAddsItAsASecondTileThatTapsSelect() throws {
        let app = try launchPlaying()

        addToMultiView(app, row: 1)

        XCTAssertTrue(app.element("multiView.root").waitForExistence(timeout: 5), "no grid")
        XCTAssertTrue(app.element("multiView.tile.1").exists)
        XCTAssertTrue(app.element("multiView.tile.2").exists)
        expect(app.element("multiView.tile.2"), "isSelected == true")
        app.waitForEngine("playing loads=1")

        app.element("multiView.tile.1").tap()
        expect(app.element("multiView.tile.1"), "isSelected == true")
    }

    // multi-view/start-multi-view-on-an-ipad, the window turns compact
    func testTurningCompactLeavesMultiViewWithTheSelectedTile() throws {
        let app = try launchPlaying()
        addToMultiView(app, row: 1)
        XCTAssertTrue(app.element("multiView.root").waitForExistence(timeout: 5), "no grid")

        app.element("browse.debug.switchLayout").tap()

        XCTAssertFalse(app.element("multiView.root").waitForExistence(timeout: 2))
        app.element("browse.debug.switchLayout").tap()
        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 5))
        XCTAssertFalse(app.element("multiView.root").exists, "multi-view stays closed")
    }
}
