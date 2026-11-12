import XCTest

/// The Guide window preference on the Apple TV guide grid, over the shell's
/// scripted `channels` scenario.
extension ShellUITests {
    /// The half-hour labels over the grid.
    func guideColumns() -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "guide.column")
    }

    /// The Guide window segment titled `title` once it has focus.
    func focusedSegment(_ title: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true AND label == %@", title)).firstMatch
    }

    // sources-and-settings/choose-how-the-app-behaves
    func testTheGuideShowsTheHoursChosenInSettings() {
        launchPlaying()
        openGuide()
        expect(guideColumns().element(boundBy: 3), "exists == true")
        XCTAssertEqual(guideColumns().count, 4, "two hours by default")

        press(.menu)
        let settings = element("shell.settings")
        for _ in 0..<8 where !settings.hasFocus { press(.right) }
        expectFocus("shell.settings")
        press(.select)
        XCTAssertTrue(element("settings.guideWindow").waitForExistence(timeout: 10))
        // On Apple TV the picker is a row of segments: down to "2 hours", right to "4 hours".
        for _ in 0..<12 where !focusedSegment("2 hours").waitForExistence(timeout: 1) { press(.down) }
        XCTAssertTrue(focusedSegment("2 hours").exists, "focused: \(focusedElements())")
        press(.right, times: 2)
        XCTAssertTrue(focusedSegment("4 hours").waitForExistence(timeout: 5), "focused: \(focusedElements())")
        press(.select)
        expect(element("settings.guideWindow").buttons["4 hours"], "isSelected == true")

        press(.menu)
        let guide = element("shell.tab.guide")
        for _ in 0..<8 where !guide.hasFocus { press(.left) }
        expectFocus("shell.tab.guide")
        press(.select)
        expectFocus("guide.grid")
        expect(guideColumns().element(boundBy: 7), "exists == true")
        XCTAssertEqual(guideColumns().count, 8, "four hours of half-hour columns")
        let first = guideColumns().element(boundBy: 0).frame.minX
        let second = guideColumns().element(boundBy: 1).frame.minX
        XCTAssertEqual(second - first, 185, accuracy: 1, "the columns share the two-hour width")
    }
}
