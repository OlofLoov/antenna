import XCTest

/// The reminder banner on Apple TV (programme-reminders capability): Kick-off
/// on Channel a2, two minutes after launch, is due at once while a1 plays.
extension ShellUITests {
    func launchWithDueReminder() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels", "-ui-testing-reminders", "due"]
        app.launch()
        expectEngine("playing loads=1 file=a1.ts")
        XCTAssertTrue(element("reminders.banner").waitForExistence(timeout: 10), "no banner")
    }

    // programme-reminders/a-banner-while-antenna-is-open
    // programme-reminders/a-banner-while-antenna-is-open, close the banner with Menu
    func testTheBannerTakesFocusAndMenuPutsItBack() {
        launchWithDueReminder()
        expect(element("reminders.banner.title"), "label == 'Kick-off'")
        XCTAssertTrue(element("reminders.banner.body").label.hasSuffix("Channel a2"), element("reminders.banner.body").label)
        expectFocus("reminders.banner.watch")
        press(.menu)
        expectGone("reminders.banner")
        expectFocus("shell.picture")
        expectEngine("playing loads=1 file=a1.ts")
    }

    // programme-reminders/watch-plays-the-channel
    func testWatchOnTheBannerPlaysTheChannelFullScreen() {
        launchWithDueReminder()
        expectFocus("reminders.banner.watch")
        press(.select)
        expectGone("reminders.banner")
        expectEngine("playing loads=2 file=a2.ts")
        expectFocus("shell.picture")
    }
}
