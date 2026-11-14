import XCTest

/// The tvos-shell capability on Apple TV. Each test launches the app with
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

    func launch(_ scenario: String, environment: [String: String] = [:]) {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", scenario]
        app.launchEnvironment.merge(environment) { $1 }
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

    /// Presses `button` and waits for `target` to take focus. tvOS can drop
    /// a press while a list that just appeared settles; when focus is still
    /// on `origin` after three seconds the press is sent once more. A press
    /// that landed moves focus off `origin`, so this never overshoots.
    func press(
        _ button: XCUIRemote.Button, toFocus target: XCUIElement, from origin: XCUIElement,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        press(button)
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasFocus == true"), object: target)
        if XCTWaiter().wait(for: [focused], timeout: 3) == .completed { return }
        let afterFirst = focusedElements()
        if origin.hasFocus { press(button) }
        let again = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasFocus == true"), object: target)
        guard XCTWaiter().wait(for: [again], timeout: 10) != .completed else { return }
        XCTFail(
            "\(target) never took focus; after the first press: \(afterFirst); now: \(focusedElements())",
            file: file, line: line)
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

    func expectGone(_ identifier: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        expect(element(identifier), "exists == false", timeout: timeout, file: file, line: line)
    }

    /// The channel overlay's rows in the shown group, top to bottom.
    /// Only the rows themselves: their logo, progress and catch-up parts
    /// share the prefix.
    func overlayRows() -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "overlay.channel."))
    }

    /// The `channels` scenario with its first channel playing full screen
    /// and the info bar from the launch tune gone again.
    func launchPlaying() {
        launch("channels")
        expectEngine("playing loads=1 file=a1.ts")
        expectFocus("shell.picture")
        expectGone("zapBar.bar", timeout: 10)
    }
}

// MARK: The bar

extension ShellUITests {
    // tvos-shell/the-tabs-in-order
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

    // tvos-shell/menu-shows-the-tab-bar-over-the-picture
    func testMenuShowsBarOverPicture() {
        launchPlaying()
        press(.menu)
        expectFocus("shell.tab.live")
        expect(element("shell.player"), "value == 'dimmed'")
        expectEngine("playing loads=1 file=a1.ts")
    }

    // tvos-shell/menu-shows-the-tab-bar-over-the-picture
    func testMenuOverFailedStreamKeepsItFailed() {
        launch("failing")
        expectEngine("failed loads=1 file=a1.ts")
        // The tune shows the info bar, which takes the first Menu press.
        expectGone("zapBar.bar", timeout: 10)
        press(.menu)
        expectFocus("shell.tab.live")
        expect(element("shell.player"), "value == 'dimmed'")
        expectEngine("failed loads=1 file=a1.ts")
    }

    // tvos-shell/back-to-full-screen-from-the-tab-bar
    func testBackToFullScreen() {
        launchPlaying()
        for back: XCUIRemote.Button in [.down, .select] {
            press(.menu)
            expectFocus("shell.tab.live")
            press(back)
            expectGone("shell.tab.live")
            expect(element("shell.player"), "value == 'full'")
            expectEngine("playing loads=1 file=a1.ts")
        }
    }

    // tvos-shell/back-to-full-screen-from-the-tab-bar
    func testSelectLiveReloadsFailedStream() {
        launch("failing")
        expectEngine("failed loads=1 file=a1.ts")
        // The tune shows the info bar, which takes the first Menu press.
        expectGone("zapBar.bar", timeout: 10)
        press(.menu)
        expectFocus("shell.tab.live")
        press(.select)
        expectEngine("failed loads=2 file=a1.ts")
        expectGone("shell.tab.live")
    }

    // tvos-shell/moving-along-the-bar-does-not-switch-tabs
    func testMovingAlongBarKeepsTab() {
        launchPlaying()
        press(.menu)
        expectFocus("shell.tab.live")
        press(.right, times: 4)
        expectFocus("shell.tab.search")
        XCTAssertTrue(element("shell.tab.live").isSelected)
        XCTAssertFalse(element("shell.tab.search").isSelected)
        XCTAssertFalse(element("search.results").exists)
        expect(element("shell.player"), "value == 'dimmed'")
    }

    // tvos-shell/open-settings
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
    // tvos-shell/back-from-a-tab-goes-to-the-tab-bar
    func testMenuFromTabReachesBar() {
        launchPlaying()
        press(.menu)
        press(.right, times: 2)
        expectFocus("shell.tab.movies")
        press(.select)
        expectFocus("movies.hero.play")
        press(.menu)
        expectFocus("shell.tab.movies")
        XCTAssertTrue(element("shell.tab.movies").isSelected)
        XCTAssertTrue(element("movies.hero.play").exists)

        press(.select)
        expectFocus("movies.hero.play")
        press(.up)
        expectFocus("shell.tab.movies")
        XCTAssertTrue(element("movies.hero.play").exists)
    }

    // tvos-shell/back-from-a-tab-goes-to-the-tab-bar
    // tvos-shell/the-tabs-in-order
    func testMenuFromGuideShowsBar() {
        launchPlaying()
        press(.menu)
        press(.right)
        expectFocus("shell.tab.guide")
        press(.select)
        expectFocus("guide.grid")
        expectGone("shell.tab.guide")
        press(.menu)
        expectFocus("shell.tab.guide")
        expect(element("shell.player"), "value == 'dimmed'")
        XCTAssertFalse(element("shell.clock").exists)
        XCTAssertTrue(element("guide.clock").exists)
        XCTAssertTrue(element("guide.grid").exists)
    }

    /// Waits for the app to leave the foreground, as Back to the Home Screen does.
    func expectHomeScreen(file: StaticString = #filePath, line: UInt = #line) {
        let left = app.wait(for: .runningBackgroundSuspended, timeout: 10) || app.state == .runningBackground
        XCTAssertTrue(left, "the app stayed in the foreground, state \(app.state.rawValue)", file: file, line: line)
    }

    /// Presses Back until the app leaves the foreground, at most `limit`
    /// times, as a TV remote with only Back and arrows would. Returns the
    /// number of presses it took.
    @discardableResult
    func pressBackUntilHome(limit: Int, file: StaticString = #filePath, line: UInt = #line) -> Int {
        for count in 1...limit {
            press(.menu)
            if app.wait(for: .runningBackgroundSuspended, timeout: 3) || app.state == .runningBackground { return count }
        }
        XCTFail("still in the app after \(limit) presses of Back; focused: \(focusedElements())", file: file, line: line)
        return limit
    }

    // tvos-shell/back-always-leads-out-of-the-app
    func testBackAlwaysLeavesLive() {
        launch("channels")
        expectEngine("playing loads=1 file=a1.ts")
        expectFocus("shell.picture")
        // The channel overlay, then the tab bar, then the Home Screen.
        press(.select)
        XCTAssertTrue(overlayRows().firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(pressBackUntilHome(limit: 6), 3)
    }

    // tvos-shell/back-always-leads-out-of-the-app
    // tvos-shell/back-from-a-tab-goes-to-the-tab-bar
    func testBackAlwaysLeavesAGenreGrid() {
        launchPlaying()
        press(.menu)
        press(.right, times: 2)
        press(.select)
        expectFocus("movies.hero.play")
        let chips = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND hasFocus == true", "movies.genres."))
        for _ in 0..<10 where !chips.firstMatch.exists { press(.down) }
        let all = element("movies.genres.all")
        for _ in 0..<3 where !all.hasFocus { press(.right) }
        expectFocus("movies.genres.all")
        press(.select)
        XCTAssertTrue(element("movies.grid").waitForExistence(timeout: 10))
        // The grid, then the tab bar, then the Home Screen.
        XCTAssertEqual(pressBackUntilHome(limit: 6), 3)
    }

    // tvos-shell/back-from-the-tab-bar-goes-to-the-home-screen
    func testBackFromBarOverLiveGoesHome() {
        launchPlaying()
        press(.menu)
        expectFocus("shell.tab.live")
        press(.menu)
        expectHomeScreen()
    }

    // tvos-shell/back-from-the-tab-bar-goes-to-the-home-screen
    // tvos-shell/back-from-a-tab-goes-to-the-tab-bar
    func testBackFromMoviesGoesToBarThenHome() {
        launchPlaying()
        press(.menu)
        press(.right, times: 2)
        press(.select)
        expectFocus("movies.hero.play")
        press(.menu)
        expectFocus("shell.tab.movies")
        press(.menu)
        expectHomeScreen()
    }

    // tvos-shell/back-from-a-tab-goes-to-the-tab-bar
    func testBackFromALowerRowScrollsToTheTop() {
        launchPlaying()
        press(.menu)
        press(.right, times: 2)
        press(.select)
        expectFocus("movies.hero.play")
        let chips = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND hasFocus == true", "movies.genres."))
        for _ in 0..<10 where !chips.firstMatch.exists { press(.down) }
        XCTAssertTrue(chips.firstMatch.exists, "never reached the genres; focused: \(focusedElements())")
        XCTAssertFalse(element("movies.hero.play").isHittable, "the banner scrolled away")

        press(.menu)
        expectFocus("shell.tab.movies")
        expect(element("movies.hero.play"), "isHittable == true")
        press(.down)
        expectFocus("movies.hero.play")
    }

    // tvos-shell/other-screens-can-send-the-user-somewhere
    // tvos-shell/channel-list-over-the-picture
    func testPickerTuneShowsLive() {
        launchPlaying()
        press(.select)
        XCTAssertTrue(element("overlay.channels").waitForExistence(timeout: 10))
        let rows = overlayRows()
        expect(rows.element(boundBy: 0), "hasFocus == true")
        press(.down, toFocus: rows.element(boundBy: 1), from: rows.element(boundBy: 0))
        press(.select)
        expectGone("overlay.channels")
        expectGone("shell.tab.live")
        expect(element("shell.player"), "value == 'full'")
        expectEngine("playing loads=2 file=a2.ts")
    }
}

// MARK: Before a channel plays

extension ShellUITests {
    // tvos-shell/a-loading-screen-at-launch
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

    // tvos-shell/an-empty-screen-with-retry
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

    // tvos-shell/an-empty-screen-with-retry
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
