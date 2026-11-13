import XCTest

/// The Guide window preference on the Apple TV guide grid, over the shell's
/// scripted `channels` scenario.
extension ShellUITests {
    /// The half-hour labels over the grid.
    func guideColumns() -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "guide.column")
    }

    /// The focused element whose label starts with `title`.
    func focusedRow(_ title: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true AND label BEGINSWITH %@", title)).firstMatch
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
        // On Apple TV the preference is a row with its value that pushes the choices
        // (design-system/forms-use-the-platform-form-style): down to the row, select,
        // down to "4 hours", select, and the row reads the new value.
        for _ in 0..<20 where !focusedRow("Guide window").waitForExistence(timeout: 1) { press(.down) }
        XCTAssertTrue(focusedRow("Guide window").exists, "focused: \(focusedElements())")
        expect(element("settings.guideWindow"), "label CONTAINS '2 hours'")
        press(.select)
        XCTAssertTrue(focusedRow("2 hours").waitForExistence(timeout: 5), "the choices never opened: \(focusedElements())")
        XCTAssertTrue(
            app.descendants(matching: .any).matching(NSPredicate(format: "label == '2 hours' AND isSelected == true")).firstMatch.exists,
            "2 hours is not ticked")
        press(.down, times: 2)
        XCTAssertTrue(focusedRow("4 hours").waitForExistence(timeout: 5), "focused: \(focusedElements())")
        press(.select)
        expect(element("settings.guideWindow"), "label CONTAINS '4 hours'")

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
