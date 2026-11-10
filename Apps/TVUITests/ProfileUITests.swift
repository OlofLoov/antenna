import XCTest

/// The profiles capability on Apple TV, over the scripted shell with two
/// profiles, Dad and Kids, from `-ui-testing-profiles`.
extension ShellUITests {
    func launchWithProfiles() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels", "-ui-testing-profiles"]
        app.launch()
    }

    // profiles/who-s-watching-at-launch
    func testWhoIsWatchingAtLaunch() {
        launchWithProfiles()
        XCTAssertTrue(element("profiles.picker").waitForExistence(timeout: 10))
        expect(element("profiles.tile.0"), "label == 'Dad, profile'")
        expect(element("profiles.tile.1"), "label == 'Kids, profile'")
        expectFocus("profiles.tile.0")
        XCTAssertFalse(element("shell.debug.engine").exists, "nothing plays before someone is chosen")

        press(.menu)
        XCTAssertTrue(element("profiles.picker").exists, "Menu stays on the picker")

        press(.right, toFocus: element("profiles.tile.1"), from: element("profiles.tile.0"))
        press(.select)
        expectGone("profiles.picker")
        expectEngine("playing loads=1 file=a1.ts")
    }

    // profiles/who-s-watching-at-launch
    func testOneProfileOpensStraightAway() {
        launch("channels")
        expectEngine("playing loads=1 file=a1.ts")
        XCTAssertFalse(element("profiles.picker").exists)
    }
}
