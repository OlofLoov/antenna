import XCTest

/// The Groups screen on Apple TV, over the scripted shell with its
/// Xtream source's Ungrouped group locked by `-ui-testing-groups locked`.
extension ShellUITests {
    // group-management/unlock-with-the-passcode
    // group-management/reset-a-forgotten-passcode
    func testGroupsAsksForThePasscodeAndOffersNoResetOnAppleTV() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels", "-ui-testing-groups", "locked"]
        app.launch()
        expectEngine("playing loads=1 file=a1.ts")
        expectGone("zapBar.bar", timeout: 10)
        openSettingsOnProfiles()
        let groups = element("settings.groups")
        XCTAssertTrue(groups.waitForExistence(timeout: 5))
        press(.down)
        let focused = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true AND label == 'Groups'"))
        XCTAssertTrue(focused.firstMatch.waitForExistence(timeout: 5), "the Groups row never took focus")
        press(.select)
        XCTAssertTrue(element("groups.passcode").waitForExistence(timeout: 10))
        let forgot = element("groups.passcode.forgot")
        XCTAssertTrue(forgot.exists)
        XCTAssertTrue(forgot.label.contains("iPhone, iPad or Mac"), forgot.label)
        XCTAssertFalse(app.buttons["groups.passcode.forgot"].exists)
        XCTAssertFalse(element("groups.row.all").exists)
    }
}
