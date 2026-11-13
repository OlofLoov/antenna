import XCTest

/// Screenshot walk-throughs on Apple TV (add-app-screenshots-ci). The
/// change's design.md names the board each step compares with.
@MainActor
final class TVJourneys: XCTestCase {
    private let remote = XCUIRemote.shared

    override func setUp() {
        continueAfterFailure = false
    }

    /// Waits up to 10 seconds for `identifier` to take focus.
    private func expectFocus(_ identifier: String, in journey: Journey, file: StaticString = #filePath, line: UInt = #line) {
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasFocus == true"), object: journey.element(identifier))
        guard XCTWaiter().wait(for: [focused], timeout: 10) != .completed else { return }
        XCTFail("\(identifier) never took focus", file: file, line: line)
    }

    /// Waits up to 10 seconds for `identifier` to go away.
    private func expectGone(_ identifier: String, in journey: Journey, file: StaticString = #filePath, line: UInt = #line) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: journey.element(identifier))
        guard XCTWaiter().wait(for: [gone], timeout: 10) != .completed else { return }
        XCTFail("\(identifier) never went away", file: file, line: line)
    }

    /// Polls `element`'s frame every quarter second, up to 5 seconds, until
    /// two readings match: a page sliding in has stopped.
    private func waitUntilStill(_ element: XCUIElement) {
        guard element.waitForExistence(timeout: 10) else { return }
        var last = element.frame
        for _ in 0..<20 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            let now = element.frame
            if now == last { return }
            last = now
        }
    }

    /// Presses right until `identifier` has focus, at most `limit` times.
    private func moveRight(to identifier: String, in journey: Journey, limit: Int = 8) {
        for _ in 0..<limit where !journey.element(identifier).hasFocus {
            remote.press(.right)
        }
        expectFocus(identifier, in: journey)
    }

    /// What a new user sees before adding a source.
    func testFirstRun() {
        let journey = Journey(self, scenario: "empty")
        journey.snap("welcome", anchor: "onboarding.welcome")
    }

    /// Live with the zap bar, then the menu bar, the guide and settings, with two sources.
    func testShell() {
        let journey = Journey(self, scenario: "full")
        journey.snap("live", anchor: "zapBar.bar")
        expectGone("zapBar.bar", in: journey)
        expectFocus("shell.picture", in: journey)
        remote.press(.menu)
        expectFocus("shell.tab.live", in: journey)
        journey.snap("menu", anchor: "shell.tab.live")
        remote.press(.right)
        expectFocus("shell.tab.guide", in: journey)
        journey.snap("focused-tab", anchor: "shell.tab.guide")
        remote.press(.select)
        expectFocus("guide.grid", in: journey)
        journey.snap("guide", anchor: "guide.grid")
        remote.press(.menu)
        expectFocus("shell.tab.guide", in: journey)
        journey.snap("guide-menu", anchor: "shell.tab.guide")
        moveRight(to: "shell.settings", in: journey)
        remote.press(.select)
        // Settings slides in over the guide. The picture waits until the
        // focus has left the bar and the page stops moving.
        let bar = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasFocus == false"), object: journey.element("shell.settings"))
        XCTAssertEqual(XCTWaiter().wait(for: [bar], timeout: 10), .completed, "the focus stayed on the bar")
        waitUntilStill(journey.element("settings.addSource"))
        journey.snap("settings", anchor: "settings.addSource")
    }

    /// The shell while sources load, when they add nothing, and its menu then.
    func testShellStates() {
        let journey = Journey(self, arguments: ["-ui-testing-shell", "loading"])
        journey.snap("loading", anchor: "shell.loading")
        journey.launch(["-ui-testing-shell", "empty"])
        journey.snap("empty", anchor: "shell.empty")
        remote.press(.menu)
        expectFocus("shell.tab.live", in: journey)
        journey.snap("empty-menu", anchor: "shell.tab.live")
    }

    /// Movies moved down to Recently watched, with titles played on this
    /// profile (add-discover-rows, `TV-Movies-Discover`).
    func testMoviesDiscover() {
        let journey = Journey(self, arguments: ["-ui-testing-shelf", "watching", "-ui-testing-reduce-motion"])
        remote.press(.menu)
        moveRight(to: "shell.tab.movies", in: journey)
        remote.press(.select)
        expectFocus("movies.hero.play", in: journey)
        let row = journey.element("movies.row.recentlyWatched")
        let focused = row.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
        for _ in 0..<4 where !focused.exists {
            remote.press(.down)
            RunLoop.current.run(until: Date().addingTimeInterval(1))
        }
        journey.snap("movies-recently-watched", anchor: "movies.row.recentlyWatched")
    }
}
