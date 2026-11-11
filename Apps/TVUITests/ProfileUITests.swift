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

extension ShellUITests {
    /// Launches with Dad and Kids and chooses Dad.
    func launchAsDad() {
        launchWithProfiles()
        XCTAssertTrue(element("profiles.picker").waitForExistence(timeout: 10))
        expectFocus("profiles.tile.0")
        press(.select)
        expectEngine("playing loads=1 file=a1.ts")
        expectGone("zapBar.bar", timeout: 10)
    }

    // profiles/switching-profile
    // tvos-shell/the-tabs-in-order
    func testSwitchingProfileFromTheTabBar() {
        launchAsDad()
        press(.menu)
        expectFocus("shell.tab.live")
        expect(element("shell.profile"), "label == 'Profile, Dad'")
        for _ in 0..<8 where !element("shell.profile").hasFocus { press(.right) }
        expectFocus("shell.profile")
        press(.select)
        XCTAssertTrue(element("profiles.picker").waitForExistence(timeout: 10))
        XCTAssertFalse(element("shell.debug.engine").exists, "playback stopped with the shell")
        press(.right, toFocus: element("profiles.tile.1"), from: element("profiles.tile.0"))
        press(.select)
        expectEngine("playing loads=1 file=a1.ts")
        expectGone("zapBar.bar", timeout: 10)
        press(.menu)
        expect(element("shell.profile"), "label == 'Profile, Kids'")
    }

    // profiles/editing-and-deleting-a-profile
    func testDeletingAProfile() {
        launchWithProfiles()
        XCTAssertTrue(element("profiles.picker").waitForExistence(timeout: 10))
        press(.down, toFocus: element("profiles.manage"), from: element("profiles.tile.0"))
        press(.select)
        XCTAssertTrue(element("profiles.add").waitForExistence(timeout: 5))
        press(.right, toFocus: element("profiles.tile.1"), from: element("profiles.tile.0"))
        press(.select)
        XCTAssertTrue(element("profiles.edit.delete").waitForExistence(timeout: 5))
        let delete = element("profiles.edit.delete")
        for _ in 0..<4 where !delete.hasFocus {
            press(.down)
            _ = XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasFocus == true"), object: delete)], timeout: 1)
        }
        for _ in 0..<2 where !delete.hasFocus { press(.right) }
        expectFocus("profiles.edit.delete")
        press(.select)
        let confirm = app.alerts.buttons.matching(identifier: "Delete").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        // Cancel and Delete sit side by side with Cancel focused.
        for _ in 0..<2 where !confirm.hasFocus { press(.right) }
        expect(confirm, "hasFocus == true")
        press(.select)
        // One profile is left, so Antenna opens straight on it.
        expectEngine("playing loads=1 file=a1.ts")
        XCTAssertFalse(element("profiles.picker").exists)
        XCTAssertFalse(element("shell.profile").exists, "no profile button with one profile")
    }

    // profiles/adding-a-profile
    func testAddingAProfile() {
        launchWithProfiles()
        XCTAssertTrue(element("profiles.picker").waitForExistence(timeout: 10))
        press(.down, toFocus: element("profiles.manage"), from: element("profiles.tile.0"))
        press(.select)
        let add = element("profiles.add")
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        press(.right, toFocus: element("profiles.tile.1"), from: element("profiles.tile.0"))
        press(.right, toFocus: add, from: element("profiles.tile.1"))
        press(.select)
        let name = app.textFields["profiles.edit.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        expectFocus("profiles.edit.name")
        press(.select)
        name.typeText("Mum")
        press(.menu)
        let save = element("profiles.edit.save")
        expect(name, "value == 'Mum'")
        for _ in 0..<4 where !save.hasFocus {
            press(.down)
            _ = XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasFocus == true"), object: save)], timeout: 1)
        }
        expectFocus("profiles.edit.save")
        press(.select)
        XCTAssertTrue(element("profiles.tile.2").waitForExistence(timeout: 5))
        expect(element("profiles.tile.2"), "label == 'Edit Mum'")
    }
}

extension ShellUITests {
    /// Opens Settings from the tab bar; its first row is Profiles.
    func openSettingsOnProfiles() {
        press(.menu)
        expectFocus("shell.tab.live")
        let settings = element("shell.settings")
        for _ in 0..<8 where !settings.hasFocus { press(.right) }
        expectFocus("shell.settings")
        press(.select)
        XCTAssertTrue(element("settings.profile").waitForExistence(timeout: 10))
        expectProfilesRowFocused()
    }

    /// Focus lands on the Form cell around the row, which carries the row's label.
    func expectProfilesRowFocused(file: StaticString = #filePath, line: UInt = #line) {
        let focused = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true AND label == 'Profiles'"))
        XCTAssertTrue(focused.firstMatch.waitForExistence(timeout: 5), "the Profiles row never took focus", file: file, line: line)
    }

    // profiles/switching-profile
    func testSwitchingProfileFromSettings() {
        launchAsDad()
        openSettingsOnProfiles()
        expect(element("settings.profile"), "value == 'Dad'")
        press(.select)
        XCTAssertTrue(element("profiles.picker").waitForExistence(timeout: 10))
        XCTAssertFalse(element("shell.debug.engine").exists, "playback stopped with the shell")
        press(.right, toFocus: element("profiles.tile.1"), from: element("profiles.tile.0"))
        press(.select)
        expectEngine("playing loads=1 file=a1.ts")
        expectGone("zapBar.bar", timeout: 10)
        openSettingsOnProfiles()
        expect(element("settings.profile"), "value == 'Kids'")
    }

    // profiles/adding-a-profile
    func testOneProfileAddsFromSettings() {
        launch("channels")
        expectEngine("playing loads=1 file=a1.ts")
        expectGone("zapBar.bar", timeout: 10)
        openSettingsOnProfiles()
        expect(element("settings.profile"), "value == 'Add a profile'")
        press(.select)
        XCTAssertTrue(element("profiles.add").waitForExistence(timeout: 5))
        expectFocus("profiles.tile.0")
        press(.menu)
        expectProfilesRowFocused()
        expectEngine("playing loads=1 file=a1.ts")
    }
}
