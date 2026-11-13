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

    /// Presses down until the focused element's label contains `label`, at most `limit` times. A row in a
    /// `List` reports focus on its cell, so the label finds it where its identifier cannot.
    private func moveDown(toLabel label: String, in journey: Journey, limit: Int = 10, file: StaticString = #filePath, line: UInt = #line) {
        let focused = journey.app.descendants(matching: .any)
            .matching(NSPredicate(format: "hasFocus == true AND label CONTAINS %@", label)).firstMatch
        for _ in 0..<limit where !focused.waitForExistence(timeout: 1) {
            remote.press(.down)
        }
        XCTAssertTrue(focused.exists, "\(label) never took focus", file: file, line: line)
    }

    /// From the full-screen picture, opens Sources & Settings from the tab bar and waits for it to settle.
    private func openSettings(in journey: Journey) {
        expectFocus("shell.picture", in: journey)
        expectGone("zapBar.bar", in: journey)
        remote.press(.menu)
        expectFocus("shell.tab.live", in: journey)
        moveRight(to: "shell.settings", in: journey)
        remote.press(.select)
        let bar = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasFocus == false"), object: journey.element("shell.settings"))
        XCTAssertEqual(XCTWaiter().wait(for: [bar], timeout: 10), .completed, "the focus stayed on the bar")
        waitUntilStill(journey.element("settings.addSource"))
    }

    /// Add a source from Settings, which opens on the form
    /// (refresh-visual-design, `TV-Refresh-AddSource`).
    func testSettingsAddSource() {
        let journey = Journey(self, arguments: ["-ui-testing-shell", "channels"])
        openSettings(in: journey)
        moveDown(toLabel: "Add a source", in: journey)
        remote.press(.select)
        journey.snap("settings-add-source", anchor: "onboarding.connect")
    }

    /// A source's details from Settings (refresh-visual-design, `TV-Refresh-Settings`).
    func testSourceDetails() {
        let journey = Journey(self, arguments: ["-ui-testing-shell", "channels"])
        openSettings(in: journey)
        journey.snap("settings", anchor: "settings.addSource")
        let row = journey.app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'settings.source.'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "no source row")
        let name = row.label.components(separatedBy: ",").first ?? row.label
        moveDown(toLabel: name, in: journey)
        remote.press(.select)
        journey.snap("source-details", anchor: "settings.details.status")
    }

    /// Movies with focus on a poster in the first row (refresh-visual-design, `TV-Movies`).
    func testMoviesFocus() {
        let journey = Journey(self, arguments: ["-ui-testing-shell", "channels", "-ui-testing-reduce-motion"])
        expectFocus("shell.picture", in: journey)
        expectGone("zapBar.bar", in: journey)
        remote.press(.menu)
        moveRight(to: "shell.tab.movies", in: journey)
        remote.press(.select)
        expectFocus("movies.hero.play", in: journey)
        let row = journey.element("movies.row.recentlyAdded")
        let focused = row.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
        for _ in 0..<4 where !focused.exists {
            remote.press(.down)
            RunLoop.current.run(until: Date().addingTimeInterval(1))
        }
        remote.press(.right)
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        XCTAssertTrue(focused.exists, "no poster in Recently added took focus")
        journey.snap("movies-row-focus", anchor: "movies.row.recentlyAdded")
    }

    /// What a new user sees before adding a source, then the kinds and the
    /// Xtream form (refresh-visual-design, `TV-Refresh-AddSource-Kinds`, `TV-Refresh-AddSource`).
    func testFirstRun() {
        let journey = Journey(self, scenario: "empty")
        journey.snap("welcome", anchor: "onboarding.welcome")
        expectFocus("onboarding.addSource", in: journey)
        remote.press(.select)
        expectFocus("onboarding.kind.m3u", in: journey)
        journey.snap("kinds", anchor: "onboarding.kind.m3u")
        moveRight(to: "onboarding.kind.xtream", in: journey)
        remote.press(.select)
        journey.snap("add-source-xtream", anchor: "onboarding.connect")
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

    /// The channel overlay with a channel the source gained since the day
    /// before, in the New group (add-discover-rows, `TV-Overlay-New`).
    func testOverlayNew() {
        let journey = Journey(
            self, arguments: ["-ui-testing-shell", "channels"], environment: ["UITESTING_NEW_CHANNEL": "a3"])
        expectFocus("shell.picture", in: journey)
        remote.press(.select)
        journey.snap("overlay-new", anchor: "overlay.group.new")
    }
}
