import XCTest

/// The profiles capability on iPhone, over the scripted Live store
/// (`UITestingLive`). `-ui-testing-profiles` adds Dad (Main) and Kids;
/// in the `favorites` scenario Sport One is Dad's favorite and Kids One
/// is Kids's.
@MainActor
final class ProfileUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func launch(profiles: Bool) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "favorites"] + (profiles ? ["-ui-testing-profiles"] : [])
        app.launch()
        return app
    }

    /// Opens Favorites and checks which of Sport One (Dad's) and Kids One (Kids's) it lists.
    func expectFavorites(dad: Bool, kids: Bool, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 10), "the channel list never appeared", file: file, line: line)
        app.element("browse.group.0").tap()
        let sportOne = app.row(2)
        let kidsOne = app.row(3)
        XCTAssertTrue((dad ? sportOne : kidsOne).waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(sportOne.exists, dad, "Sport One in Favorites", file: file, line: line)
        XCTAssertEqual(kidsOne.exists, kids, "Kids One in Favorites", file: file, line: line)
    }

    func openSettings(_ app: XCUIApplication) -> XCUIElement {
        app.tabBars.buttons["Settings"].tap()
        let row = app.element("settings.profile")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        return row
    }

    // profiles/who-s-watching-at-launch
    // favorites/favorites-belong-to-a-profile
    func testWhoIsWatchingAtLaunch() throws {
        let app = try launch(profiles: true)
        XCTAssertTrue(app.element("profiles.picker").waitForExistence(timeout: 10))
        XCTAssertEqual(app.element("profiles.tile.0").label, "Dad, profile")
        XCTAssertEqual(app.element("profiles.tile.1").label, "Kids, profile")
        XCTAssertFalse(app.element("browse.list").exists, "the tabs wait for a profile")
        XCTAssertFalse(app.tabBars.firstMatch.exists)

        app.element("profiles.tile.1").tap()
        expectFavorites(dad: false, kids: true, in: app)
    }

    // profiles/who-s-watching-at-launch, one profile
    func testOneProfileShowsNothingAboutProfiles() throws {
        let app = try launch(profiles: false)
        expectFavorites(dad: true, kids: false, in: app)
        XCTAssertFalse(app.element("profiles.picker").exists)
        let row = openSettings(app)
        XCTAssertEqual(row.value as? String, "Add a profile")
    }

    // profiles/adding-a-profile
    func testAddingTheSecondProfileFromSettings() throws {
        let app = try launch(profiles: false)
        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 10))
        openSettings(app).tap()

        let add = app.element("profiles.add")
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let name = app.textFields["profiles.edit.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let save = app.buttons["profiles.edit.save"]
        XCTAssertFalse(save.isEnabled, "a name is needed")
        name.tap()
        name.typeText("   ")
        XCTAssertFalse(save.isEnabled, "spaces are not a name")
        name.typeText("Kids")
        XCTAssertTrue(save.isEnabled)
        save.tap()

        XCTAssertTrue(app.element("profiles.tile.1").waitForExistence(timeout: 5))
        XCTAssertEqual(app.element("profiles.tile.0").label, "Edit Main")
        XCTAssertEqual(app.element("profiles.tile.1").label, "Edit Kids")
        app.buttons["profiles.done"].tap()
        XCTAssertEqual(app.element("settings.profile").value as? String, "Main")
    }

    // profiles/switching-profile
    func testSwitchingProfileFromSettings() throws {
        let app = try launch(profiles: true)
        XCTAssertTrue(app.element("profiles.tile.0").waitForExistence(timeout: 10))
        app.element("profiles.tile.0").tap()
        expectFavorites(dad: true, kids: false, in: app)

        let row = openSettings(app)
        XCTAssertEqual(row.value as? String, "Dad")
        row.tap()
        XCTAssertTrue(app.element("profiles.picker").waitForExistence(timeout: 5))
        app.element("profiles.tile.1").tap()
        expectFavorites(dad: false, kids: true, in: app)
        XCTAssertEqual(openSettings(app).value as? String, "Kids")
    }

    // profiles/editing-and-deleting-a-profile
    func testDeletingAProfile() throws {
        let app = try launch(profiles: true)
        XCTAssertTrue(app.element("profiles.manage").waitForExistence(timeout: 10))
        app.element("profiles.manage").tap()
        // The picker's tiles stay under the sheet, so pick the Manage row by its label.
        let kids = app.buttons.matching(NSPredicate(format: "identifier == 'profiles.tile.1' AND label == 'Edit Kids'")).firstMatch
        XCTAssertTrue(kids.waitForExistence(timeout: 5))
        kids.tap()

        let delete = app.buttons["profiles.edit.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        let alert = app.alerts["Delete Kids?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts["Its favorites, hidden groups and history go too. Sources stay."].exists)
        alert.buttons["Delete"].tap()

        // One profile is left, so Antenna opens straight on it.
        expectFavorites(dad: true, kids: false, in: app)
        XCTAssertFalse(app.element("profiles.picker").exists)

        // Dad is the last profile, so it can be renamed but not deleted.
        let row = openSettings(app)
        XCTAssertEqual(row.value as? String, "Add a profile")
        row.tap()
        XCTAssertTrue(app.element("profiles.tile.0").waitForExistence(timeout: 5))
        XCTAssertFalse(app.element("profiles.tile.1").exists)
        app.element("profiles.tile.0").tap()
        let name = app.textFields["profiles.edit.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Dad")
        XCTAssertFalse(app.buttons["profiles.edit.delete"].exists)
    }
}
