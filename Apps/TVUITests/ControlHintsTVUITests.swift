import XCTest

/// Remote hints on Apple TV, over the shell's scripted `channels` scenario.
/// `-ui-testing-hints` starts with hints on and keeps the legend from fading.
extension ShellUITests {
    var legend: XCUIElement { element("hints.legend") }

    func launchWithHints() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels", "-ui-testing-hints"]
        app.launch()
        expectFocus("shell.picture")
        expect(element("zapBar.bar"), "exists == false", timeout: 10)
    }

    /// Moves down Settings one row at a time until the switch has focus.
    func focusRemoteHintsRow() {
        // The list cell takes focus; the identifier sits on the button inside it.
        let focused = app.cells.matching(NSPredicate(format: "hasFocus == true"))
            .containing(.any, identifier: "settings.remoteHints").firstMatch
        for _ in 0..<30 where !focused.waitForExistence(timeout: 1) { press(.down) }
        XCTAssertTrue(focused.exists, "focused: \(focusedElements())")
    }

    // control-hints/remote-hints-show-what-the-buttons-do
    // control-hints/each-screen-lists-its-own-actions
    func testRemoteHintsFollowTheScreen() {
        launchWithHints()
        expect(legend, "label CONTAINS 'Click, Channel list.'")
        expect(legend, "label CONTAINS 'Swipe up or down, Change channel.'")

        press(.select)
        expect(legend, "label CONTAINS 'Click, Watch.'")
        press(.left)
        expect(legend, "label CONTAINS 'Choose a group'")
    }

    // control-hints/turn-remote-hints-off
    func testRemoteHintsTurnOffInSettings() {
        launchWithHints()
        expect(legend, "exists == true")

        press(.menu)
        let settings = element("shell.settings")
        for _ in 0..<8 where !settings.hasFocus { press(.right) }
        expectFocus("shell.settings")
        press(.select)
        expect(legend, "label CONTAINS 'Open or change'")

        let row = element("settings.remoteHints")
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        focusRemoteHintsRow()
        press(.select)
        expect(legend, "exists == false")

        // Off stays off on the shell's screens.
        press(.menu)
        expectFocus("shell.settings")
        expect(legend, "exists == false")

        // On again shows the legend straight away, and leaves the device as it was.
        press(.select)
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        focusRemoteHintsRow()
        press(.select)
        expect(legend, "exists == true")
    }
}
