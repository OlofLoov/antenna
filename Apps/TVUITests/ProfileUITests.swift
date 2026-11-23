import XCTest

/// The profiles capability on Apple TV, over the scripted shell with two
/// profiles, Dad and Kids, from `-ui-testing-profiles`.
extension ShellUITests {
    func launchWithProfiles() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels", "-ui-testing-profiles"]
        app.launchInEnglish()
    }

    // profiles/who-s-watching-at-launch
    func testBackOnWhoIsWatchingGoesHome() {
        launchWithProfiles()
        XCTAssertTrue(element("profiles.picker").waitForExistence(timeout: 10))
        expectFocus("profiles.tile.0")
        press(.menu)
        expectHomeScreen()
    }

    // profiles/who-s-watching-at-launch
    func testWhoIsWatchingAtLaunch() {
        launchWithProfiles()
        XCTAssertTrue(element("profiles.picker").waitForExistence(timeout: 10))
        expect(element("profiles.tile.0"), "label == 'Dad, profile'")
        expect(element("profiles.tile.1"), "label == 'Kids, profile'")
        expectFocus("profiles.tile.0")
        XCTAssertFalse(element("shell.debug.engine").exists, "nothing plays before someone is chosen")

        press(.right, toFocus: element("profiles.tile.1"), from: element("profiles.tile.0"))
        press(.select)
        expectGone("profiles.picker")
        expectEngine("playing loads=1 file=a1.ts")
    }

    // profiles/who-s-watching-at-launch, the focused circle shows whole
    func testTheFocusedCircleShowsWhole() throws {
        launchWithProfiles()
        XCTAssertTrue(element("profiles.picker").waitForExistence(timeout: 10))
        expectFocus("profiles.tile.0")
        try expectWholeCircle(atTopOf: element("profiles.tile.0").frame)
    }

    // profiles/who-s-watching-at-launch, the focused circle shows whole
    // profiles/switching-profile
    func testTheFocusedProfileButtonShowsWhole() throws {
        launchAsDad()
        openSettingsOnProfiles()
        for _ in 0..<4 where !element("shell.profile").hasFocus { press(.up) }
        for _ in 0..<4 where !element("shell.profile").hasFocus { press(.left) }
        expectFocus("shell.profile")
        try expectWholeCircle(atTopOf: element("shell.profile").frame)
    }

    /// Once the lift settles, the focused circle at the top of `frame` is
    /// as tall as it is wide, and past it there is only the color found
    /// above and to the left of it, and its shadow below: no platter.
    func expectWholeCircle(atTopOf frame: CGRect, file: StaticString = #filePath, line: UInt = #line) throws {
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "the lift settles")], timeout: 1.5)
        let pixels = try ScreenPixels(app)
        let resting = CGPoint(x: frame.midX, y: frame.minY + frame.width / 2)
        let ground = try XCTUnwrap(pixels.color(at: CGPoint(x: resting.x - frame.width, y: resting.y - frame.width / 2)))
        let circle = try XCTUnwrap(circleFrame(frame, pixels))
        XCTAssertEqual(circle.width, circle.height, accuracy: 4, "a round circle, not cut at the sides: \(circle)", file: file, line: line)
        let radius = circle.width / 2
        let center = CGPoint(x: circle.midX, y: circle.midY)
        for degrees in stride(from: 0.0, to: 360, by: 15) where !(30...150).contains(degrees) {
            let angle = degrees * .pi / 180
            let point = CGPoint(x: center.x + cos(angle) * radius * 1.25, y: center.y + sin(angle) * radius * 1.25)
            let color = try XCTUnwrap(pixels.color(at: point))
            XCTAssertLessThanOrEqual(
                color.distance(to: ground), 16, "something drawn at \(degrees) degrees around the circle: \(color)", file: file,
                line: line)
        }
    }

    /// The bounding box of the circle's color around the tile's top. Its
    /// sides are found along the middle row from points either side of the
    /// initial, its top up the middle column from a point above it.
    func circleFrame(_ tile: CGRect, _ pixels: ScreenPixels) -> CGRect? {
        let center = CGPoint(x: tile.midX, y: tile.minY + tile.width / 2)
        let inset = tile.width * 0.35
        guard let fill = pixels.color(at: CGPoint(x: center.x, y: center.y - inset)) else { return nil }
        func edge(from start: CGPoint, _ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
            var point = start
            for _ in 0..<Int(tile.width) {
                let next = CGPoint(x: point.x + dx, y: point.y + dy)
                guard let color = pixels.color(at: next), color.distance(to: fill) <= 48 else { break }
                point = next
            }
            return point
        }
        let left = edge(from: CGPoint(x: center.x - inset, y: center.y), -1, 0).x
        let right = edge(from: CGPoint(x: center.x + inset, y: center.y), 1, 0).x
        let top = edge(from: CGPoint(x: center.x, y: center.y - inset), 0, -1).y
        return CGRect(x: left, y: top, width: right - left, height: (center.y - top) * 2)
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
    func testSwitchingProfileFromTheTopOfSettings() {
        launchAsDad()
        press(.menu)
        expectFocus("shell.tab.live")
        XCTAssertFalse(element("shell.profile").exists, "the bar holds the tabs alone")
        openSettingsOnProfiles()
        expect(element("shell.profile"), "label == 'Profile, Dad'")
        for _ in 0..<4 where !element("shell.profile").hasFocus { press(.up) }
        for _ in 0..<4 where !element("shell.profile").hasFocus { press(.left) }
        expectFocus("shell.profile")
        press(.select)
        XCTAssertTrue(element("profiles.picker").waitForExistence(timeout: 10))
        XCTAssertFalse(element("shell.debug.engine").exists, "playback stopped with the shell")
        press(.right, toFocus: element("profiles.tile.1"), from: element("profiles.tile.0"))
        press(.select)
        expectEngine("playing loads=1 file=a1.ts")
        expectGone("zapBar.bar", timeout: 10)
        openSettingsOnProfiles()
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
        // One profile is left, so Antuna opens straight on it.
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
        XCTAssertTrue(save.isEnabled, "Save is off with the name 'Mum'")
        // Down runs from the name through the colors and the accents to Save.
        for _ in 0..<6 where !save.hasFocus {
            press(.down)
            _ = XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasFocus == true"), object: save)], timeout: 2)
        }
        guard save.hasFocus else {
            return XCTFail("Save at \(save.frame) never took focus; focused: \(focusedElements())")
        }
        press(.select)
        XCTAssertTrue(element("profiles.tile.2").waitForExistence(timeout: 5))
        expect(element("profiles.tile.2"), "label == 'Edit Mum'")
    }
}

extension ShellUITests {
    /// Opens Settings from the tab bar; its first row is Profiles.
    func openSettingsOnProfiles() {
        if !(element("shell.tab.live").exists && element("shell.tab.live").hasFocus) { press(.menu) }
        expectFocus("shell.tab.live")
        let settings = element("shell.settings")
        for _ in 0..<8 where !settings.hasFocus { press(.right) }
        expectFocus("shell.settings")
        press(.select)
        XCTAssertTrue(element("settings.profile").waitForExistence(timeout: 10))
        // With two profiles the profile button at the top of the lead column can take the first highlight.
        let profile = element("shell.profile")
        if profile.exists, profile.hasFocus { press(.right) }
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
    // tvos-shell/open-settings: Settings holds the channel paused, so it is still paused back on the Profiles row.
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
        expectEngine("paused loads=1 file=a1.ts")
    }
}
