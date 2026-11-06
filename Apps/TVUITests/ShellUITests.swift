import XCTest

/// Spec 0015 on Apple TV. Each test launches the app with
/// `-ui-testing-shell <scenario>` (`UITestingShell`): two scripted sources on
/// an in-memory store and a recording engine whose state the
/// `shell.debug.engine` probe reads as `"<state> loads=<n> file=<name>"`.
@MainActor
final class ShellUITests: XCTestCase {
    let remote = XCUIRemote.shared
    var app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
    }

    func launch(_ scenario: String) {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", scenario]
        app.launch()
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    func elements(prefix: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
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
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasFocus == true"), object: element(identifier))
        guard XCTWaiter().wait(for: [expectation], timeout: 10) != .completed else { return }
        XCTFail("\(identifier) never took focus; focused: \(focusedElements())", file: file, line: line)
    }

    /// What has focus, for failure messages.
    func focusedElements() -> String {
        let focused = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true"))
        return focused.allElementsBoundByIndex
            .map { "[\($0.identifier) type \($0.elementType.rawValue) label '\($0.label)']" }
            .joined(separator: " ")
    }

    func expectEngine(_ summary: String, file: StaticString = #filePath, line: UInt = #line) {
        expect(element("shell.debug.engine"), "value == '\(summary)'", file: file, line: line)
    }

    func expectGone(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        expect(element(identifier), "exists == false", file: file, line: line)
    }

    /// The `channels` scenario with its first channel playing full screen.
    func launchPlaying() {
        launch("channels")
        expectEngine("playing loads=1 file=a1.ts")
        expectFocus("shell.picture")
    }
}

// MARK: The bar

extension ShellUITests {
    // 0015/AC-1
    func testTabsInOrder() {
        launchPlaying()
        press(.menu)
        let order = [
            "shell.mark", "shell.tab.live", "shell.tab.guide", "shell.tab.movies", "shell.tab.series", "shell.tab.search",
            "shell.settings", "shell.clock",
        ]
        var previous = -CGFloat.infinity
        for identifier in order {
            let item = element(identifier)
            XCTAssertTrue(item.waitForExistence(timeout: 10), "\(identifier) missing in \(app.debugDescription)")
            XCTAssertGreaterThan(item.frame.minX, previous, "\(identifier) is out of order")
            previous = item.frame.minX
        }
        let selected = order.filter { $0.hasPrefix("shell.tab.") && element($0).isSelected }
        XCTAssertEqual(selected, ["shell.tab.live"])
    }

    // 0015/AC-3
    func testMenuShowsBarOverPicture() {
        launchPlaying()
        press(.menu)
        expectFocus("shell.tab.live")
        expect(element("shell.player"), "value == 'dimmed'")
        expectEngine("playing loads=1 file=a1.ts")
    }

    // 0015/AC-3
    func testMenuOverFailedStreamKeepsItFailed() {
        launch("failing")
        expectEngine("failed loads=1 file=a1.ts")
        press(.menu)
        expectFocus("shell.tab.live")
        expect(element("shell.player"), "value == 'dimmed'")
        expectEngine("failed loads=1 file=a1.ts")
    }

    // 0015/AC-4
    func testBackToFullScreen() {
        launchPlaying()
        for back: XCUIRemote.Button in [.menu, .down, .select] {
            press(.menu)
            expectFocus("shell.tab.live")
            press(back)
            expectGone("shell.tab.live")
            expect(element("shell.player"), "value == 'full'")
            expectEngine("playing loads=1 file=a1.ts")
        }
    }

    // 0015/AC-4
    func testSelectLiveReloadsFailedStream() {
        launch("failing")
        expectEngine("failed loads=1 file=a1.ts")
        press(.menu)
        expectFocus("shell.tab.live")
        press(.select)
        expectEngine("failed loads=2 file=a1.ts")
        expectGone("shell.tab.live")
    }

    // 0015/AC-13
    func testMovingAlongBarKeepsTab() {
        launchPlaying()
        press(.menu)
        expectFocus("shell.tab.live")
        press(.right, times: 4)
        expectFocus("shell.tab.search")
        XCTAssertTrue(element("shell.tab.live").isSelected)
        XCTAssertFalse(element("shell.tab.search").isSelected)
        XCTAssertFalse(element("search.standIn").exists)
        expect(element("shell.player"), "value == 'dimmed'")
    }

    // 0015/AC-12a
    func testSettingsOpensOverPicture() {
        launchPlaying()
        press(.menu)
        expectFocus("shell.tab.live")
        press(.right, times: 5)
        expectFocus("shell.settings")
        press(.select)
        XCTAssertTrue(element("settings.addSource").waitForExistence(timeout: 10))
        press(.menu)
        expectFocus("shell.settings")
        expectEngine("playing loads=1 file=a1.ts")
    }
}

// MARK: Tabs

extension ShellUITests {
    // 0015/AC-6a
    func testMenuFromTabReachesBar() {
        launchPlaying()
        press(.menu)
        press(.right, times: 2)
        expectFocus("shell.tab.movies")
        press(.select)
        expectFocus("movies.standIn")
        press(.menu)
        expectFocus("shell.tab.movies")
        XCTAssertTrue(element("shell.tab.movies").isSelected)
        XCTAssertTrue(element("movies.standIn").exists)

        press(.select)
        expectFocus("movies.standIn")
        press(.up)
        expectFocus("shell.tab.movies")
        XCTAssertTrue(element("movies.standIn").exists)
    }

    // 0015/AC-6a
    func testMenuFromGuideShowsBar() {
        launchPlaying()
        press(.menu)
        press(.right)
        expectFocus("shell.tab.guide")
        press(.select)
        expectFocus("guide.standIn")
        expectGone("shell.tab.guide")
        press(.menu)
        expectFocus("shell.tab.guide")
        expect(element("shell.player"), "value == 'dimmed'")
        XCTAssertFalse(element("shell.clock").exists)
        XCTAssertTrue(element("guide.clock").exists)
        XCTAssertTrue(element("guide.standIn").exists)
    }

    // 0015/AC-6b
    func testMenuFromBarGoesLive() {
        launchPlaying()
        press(.menu)
        press(.right, times: 2)
        press(.select)
        expectFocus("movies.standIn")
        press(.menu)
        expectFocus("shell.tab.movies")
        press(.menu)
        expectGone("shell.tab.live")
        expectGone("movies.standIn")
        expect(element("shell.player"), "value == 'full'")
        expectEngine("playing loads=1 file=a1.ts")
    }

    // 0015/AC-14a
    func testPickerTuneShowsLive() {
        launchPlaying()
        press(.select)
        XCTAssertTrue(element("overlay.channels").waitForExistence(timeout: 10))
        // A List row takes focus as its cell, which carries no identifier.
        let rows = app.cells
        expect(rows.element(boundBy: 0), "hasFocus == true")
        press(.down)
        expect(rows.element(boundBy: 1), "hasFocus == true")
        press(.select)
        expectGone("overlay.channels")
        expectGone("shell.tab.live")
        expect(element("shell.player"), "value == 'full'")
        expectEngine("playing loads=2 file=a2.ts")
    }
}

// MARK: Before a channel plays

extension ShellUITests {
    // 0015/AC-10
    func testLoadingScreen() {
        launch("loading")
        XCTAssertTrue(element("shell.loading").waitForExistence(timeout: 10))
        let rows = elements(prefix: "shell.loading.")
        XCTAssertEqual(rows.count, 2)
        for index in 0..<rows.count {
            XCTAssertEqual(rows.element(boundBy: index).value as? String, "loading")
        }
        press(.menu)
        expectFocus("shell.tab.live")
        press(.right, times: 5)
        expectFocus("shell.settings")
        press(.select)
        XCTAssertTrue(element("settings.addSource").waitForExistence(timeout: 10))
    }

    // 0015/AC-11
    func testEmptyScreenRetry() {
        launch("empty")
        XCTAssertTrue(element("shell.empty").waitForExistence(timeout: 10))
        let lines = elements(prefix: "shell.empty.source.")
        XCTAssertEqual(lines.count, 2)
        let values = Set((0..<lines.count).compactMap { lines.element(boundBy: $0).value as? String })
        XCTAssertEqual(values, ["loaded:0", "waitingForLogin"])
        expectFocus("shell.retry")
        press(.select)
        XCTAssertTrue(element("shell.loading").waitForExistence(timeout: 10))
        XCTAssertFalse(element("shell.retry").exists)
        let focusedRow = elements(prefix: "shell.loading.").matching(NSPredicate(format: "hasFocus == true"))
        expect(focusedRow.firstMatch, "exists == true")
        expect(element("shell.loading.00000000-0000-0000-0000-00000000000A"), "value == 'loading'")
    }

    // 0015/AC-11
    func testEmptyScreenReachesSettings() {
        launch("empty")
        expectFocus("shell.retry")
        press(.menu)
        expectFocus("shell.tab.live")
        expect(element("shell.retry"), "hasFocus == false")
        press(.right, times: 5)
        expectFocus("shell.settings")
        press(.select)
        XCTAssertTrue(element("settings.addSource").waitForExistence(timeout: 10))
    }
}
