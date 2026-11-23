import XCTest

/// Settings, Appearance on iPhone, over the scripted Live store with Dad
/// (Main) and Kids from `-ui-testing-profiles`. The Accent row's value is
/// the accent the environment holds, so it changes only when the tint does.
@MainActor
final class AppearanceUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "favorites", "-ui-testing-profiles"]
        app.launchInEnglish()
        return app
    }

    private func pick(_ tile: String, in app: XCUIApplication) {
        XCTAssertTrue(app.element(tile).waitForExistence(timeout: 10))
        app.element(tile).tap()
        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 10), "the channel list never appeared")
    }

    /// Opens Settings from the profile button.
    private func openSettings(_ app: XCUIApplication) {
        app.openSettings()
        XCTAssertTrue(app.element("settings.profile").waitForExistence(timeout: 10), "Settings never opened")
    }

    /// Swipes until `element` is on screen, at most `limit` times. A `for … where`
    /// loop would query the element on every pass even once it shows, and each
    /// query of Settings takes seconds on a CI runner.
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, limit: Int, swipe: (XCUIApplication) -> Void) {
        var swipes = 0
        while swipes < limit, !(element.exists && element.isHittable) {
            swipe(app)
            swipes += 1
        }
    }

    /// The Accent row, scrolled into view.
    private func accentRow(_ app: XCUIApplication) -> XCUIElement {
        let row = app.element("settings.appearance.accent")
        reveal(row, in: app, limit: 8) { $0.swipeUp() }
        XCTAssertTrue(row.isHittable, "no Accent row")
        return row
    }

    // sources-and-settings/pick-the-accent-for-your-profile
    // design-system/one-accent-color-per-profile
    func testPickingAnAccentChangesTheTintForThatProfileOnly() throws {
        let app = try launch()
        pick("profiles.tile.0", in: app)
        openSettings(app)
        let row = accentRow(app)
        XCTAssertEqual(row.value as? String, "Blue", "the default")

        row.tap()
        let teal = app.element("settings.choice.teal")
        XCTAssertTrue(teal.waitForExistence(timeout: 5), "the accent choices never opened")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "settings.choices").count, 1)
        for id in ["blue", "teal", "amber", "pink", "violet"] {
            XCTAssertTrue(app.element("settings.choice.\(id)").exists, "no \(id)")
        }
        teal.tap()
        let picked = NSPredicate(format: "value == 'Teal'")
        expectation(for: picked, evaluatedWith: accentRow(app))
        // One query of the row has taken over 5 s on a CI runner.
        waitForExpectations(timeout: 30)

        // Kids keeps Blue.
        let profiles = app.element("settings.profile")
        reveal(profiles, in: app, limit: 8) { $0.swipeDown() }
        profiles.tap()
        pick("profiles.tile.1", in: app)
        openSettings(app)
        XCTAssertEqual(accentRow(app).value as? String, "Blue")
    }

    // profiles/editing-and-deleting-a-profile
    func testTheProfileEditorPicksTheAccent() throws {
        let app = try launch()
        XCTAssertTrue(app.element("profiles.manage").waitForExistence(timeout: 10))
        app.element("profiles.manage").tap()
        let kids = app.buttons["Edit Kids"]
        XCTAssertTrue(kids.waitForExistence(timeout: 5))
        kids.tap()
        let amber = app.buttons["profiles.edit.accent.amber"]
        XCTAssertTrue(amber.waitForExistence(timeout: 5), "no accent swatches")
        XCTAssertTrue(app.buttons["profiles.edit.accent.blue"].isSelected, "Blue until picked")
        amber.tap()
        XCTAssertTrue(amber.isSelected)
        app.buttons["profiles.edit.save"].tap()
        app.buttons["profiles.done"].tap()

        pick("profiles.tile.1", in: app)
        openSettings(app)
        XCTAssertEqual(accentRow(app).value as? String, "Amber")
    }

    // sources-and-settings/pick-the-app-icon-on-this-device
    // app-release/alternate-icons-keep-the-mark
    func testTheAppIconPageListsTheIconsAndPicksOne() throws {
        let app = try launch()
        pick("profiles.tile.0", in: app)
        openSettings(app)
        _ = accentRow(app)
        let row = app.element("settings.appearance.icon")
        reveal(row, in: app, limit: 4) { $0.swipeUp() }
        // The simulator keeps the icon a run before picked, so pick another one.
        let (target, name) = row.value as? String == "Mono" ? ("teal", "Teal") : ("mono", "Mono")
        row.tap()
        for id in ["standard", "mono", "light", "teal", "amber", "pink", "violet"] {
            XCTAssertTrue(app.element("settings.choice.\(id)").waitForExistence(timeout: 5), "no \(id) icon")
        }
        app.element("settings.choice.\(target)").tap()
        // The system tells the user the icon changed, in an alert of its own.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<10 {
            if let alert = [app.alerts.firstMatch, springboard.alerts.firstMatch].first(where: \.exists) {
                alert.buttons.firstMatch.tap()
                break
            }
            _ = app.alerts.firstMatch.waitForExistence(timeout: 1)
        }
        expectation(for: NSPredicate(format: "value == %@", name), evaluatedWith: row)
        waitForExpectations(timeout: 10)
    }
}
