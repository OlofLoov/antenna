import XCTest

/// Reminders on Apple TV (programme-reminders capability) on the shell's
/// `channels` scenario: Channel a1 plays at launch with Morning News on now,
/// then Weather, Business, Sport Tonight and Late Film.
extension ShellUITests {
    func launchPlaying(reminders seed: String?) {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels"] + (seed.map { ["-ui-testing-reminders", $0] } ?? [])
        app.launch()
        expectEngine("playing loads=1 file=a1.ts")
        expectFocus("shell.picture")
        expectGone("zapBar.bar", timeout: 10)
    }

    /// Opens Settings › Reminders from full-screen Live.
    func openReminders() {
        press(.menu)
        expectFocus("shell.tab.live")
        let settings = element("shell.settings")
        for _ in 0..<8 where !settings.hasFocus { press(.right) }
        expectFocus("shell.settings")
        press(.select)
        let row = element("settings.reminders")
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        press(.down, untilFocused: "Reminders")
        press(.select)
        XCTAssertTrue(element("reminders.leadTime").waitForExistence(timeout: 10))
    }

    /// Presses `button` one step at a time, waiting for focus to settle,
    /// until an element whose label contains `label` has focus. List rows
    /// on Apple TV report focus on the cell, not on the identified element.
    func press(
        _ button: XCUIRemote.Button, untilFocused label: String, limit: Int = 12, file: StaticString = #filePath, line: UInt = #line
    ) {
        let focused = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true AND label CONTAINS %@", label))
            .firstMatch
        for _ in 0..<limit {
            if focused.waitForExistence(timeout: 1) { return }
            press(button)
        }
        XCTAssertTrue(
            focused.waitForExistence(timeout: 2), "\(label) never took focus; focused: \(focusedElements())", file: file, line: line)
    }

    // programme-reminders/remind-me-appears-only-before-a-programme-starts
    // programme-reminders/set-a-reminder-in-one-tap
    func testRemindMeInTheGuideKeepsFocusAndPlaysNothing() {
        launchPlaying(reminders: nil)
        openGuide()
        expectHighlight("guide.block.\(homeKey(0)).")
        expect(element("guide.panel.title"), "label == 'Morning News'")
        XCTAssertFalse(element("guide.remind").exists, "a programme on now offers Remind me")

        press(.right)
        expect(element("guide.panel.title"), "label == 'Weather'")
        let remind = element("guide.remind")
        XCTAssertTrue(remind.waitForExistence(timeout: 5))
        press(.select)
        expectFocus("guide.watch")
        press(.right, toFocus: remind, from: element("guide.watch"))
        expect(remind, "label CONTAINS 'Remind me'")
        press(.select)
        expect(remind, "label CONTAINS 'Reminder set'")
        expectFocus("guide.remind")
        expectEngine("playing loads=1 file=a1.ts")

        // Menu goes back to the grid, as from Watch.
        press(.menu)
        expectFocus("guide.grid")
    }

    // programme-reminders/remind-me-appears-only-before-a-programme-starts, the overlay
    // programme-reminders/set-a-reminder-in-one-tap
    // tv-channel-overlay/now-and-next-for-the-highlighted-channel
    func testTheOverlaysNextProgrammesSetReminders() {
        launchPlaying(reminders: nil)
        openOverlay()
        press(.right, toFocus: element("overlay.watch"), from: row(named: "Channel a1"))
        let weather = element("overlay.panel.next.0")
        XCTAssertTrue(weather.waitForExistence(timeout: 5))
        press(.up, toFocus: element("overlay.panel.next.2"), from: element("overlay.watch"))
        press(.up, toFocus: element("overlay.panel.next.1"), from: element("overlay.panel.next.2"))
        press(.up, toFocus: weather, from: element("overlay.panel.next.1"))
        expect(weather, "value == 'Remind me'")
        press(.select)
        expect(weather, "value == 'Reminder set'")
        expectFocus("overlay.panel.next.0")
        XCTAssertTrue(element("overlay.root").exists, "the overlay closed")
        expectEngine("playing loads=1 file=a1.ts")
        press(.select)
        expect(weather, "value == 'Remind me'")
        // Left from a programme comes back to the channel it belongs to.
        press(.left)
        expectFocusedRow("Channel a1")
    }

    // programme-reminders/see-every-upcoming-reminder-in-one-list
    // programme-reminders/the-app-says-when-reminders-cannot-notify, Apple TV
    // programme-reminders/remove-a-reminder-anywhere, confirming on Apple TV
    func testTheRemindersPageListsAndRemovesWithConfirmation() {
        launchPlaying(reminders: "list")
        openReminders()
        XCTAssertTrue(element("reminders.permissionDenied").waitForExistence(timeout: 5))
        let notice = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Apple TV cannot show notifications'")).firstMatch
        XCTAssertTrue(notice.exists, "no Apple TV notice")
        expect(element("reminders.count"), "label == '3'")
        let row = element("reminders.row.0")
        expect(row, "label CONTAINS 'Weather'")
        expect(element("reminders.row.1"), "label CONTAINS 'No longer in the guide'")
        press(.down, untilFocused: "Weather")
        press(.select)
        let remove = app.alerts.buttons.matching(identifier: "Remove").firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        // Cancel and Remove sit side by side with Cancel focused.
        for _ in 0..<2 where !remove.hasFocus { press(.right) }
        expect(remove, "hasFocus == true")
        press(.select)
        expect(element("reminders.count"), "label == '2'")
        expect(element("reminders.row.0"), "label CONTAINS 'Harbour Talk'")
    }
}
