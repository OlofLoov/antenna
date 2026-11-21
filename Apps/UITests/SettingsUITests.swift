import XCTest

/// Settings, About.
@MainActor
final class SettingsUITests: XCTestCase {
    // The FFmpeg notice that FFmpeg's LGPL license asks for (add-playback-engine task 6.2).
    func testAboutShowsTheFFmpegNotice() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"]
        app.launchInEnglish()

        app.openSettings(timeout: 10)

        let notice = app.descendants(matching: .any)["settings.ffmpegNotice"].firstMatch
        // About is the last section, below Appearance and the app icons.
        _ = notice.waitForExistence(timeout: 5)
        for _ in 0..<6 where !(notice.exists && notice.isHittable) { app.swipeUp() }
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        notice.tap()

        let text = app.staticTexts["ffmpegNotice.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertTrue(text.label.contains("GNU Lesser General Public License, version 2.1"))
        XCTAssertTrue(app.descendants(matching: .any)["ffmpegNotice.source"].firstMatch.exists)
    }

    // live-tv-on-iphone-ipad-mac/settings-from-the-profile-button
    func testTheProfileButtonOpensSettingsOverTheTabAndCloseGoesBack() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"]
        app.launchInEnglish()
        app.tabBars.buttons["Guide"].tap()
        XCTAssertTrue(element(app, "guide.groups").waitForExistence(timeout: 10), "the Guide never showed its group row")
        let button = try XCTUnwrap(app.profileButton, "no profile button on the Guide")
        XCTAssertEqual(button.label, "Settings", "with one profile the button opens Settings")
        XCTAssertEqual(button.frame.midY, element(app, "guide.groups").frame.midY, accuracy: 2, "on the group row")
        button.tap()

        XCTAssertTrue(element(app, "settings.profile").waitForExistence(timeout: 5), "Settings did not open")
        XCTAssertTrue(app.navigationBars["Sources & Settings"].exists)
        element(app, "settings.close").tap()
        XCTAssertTrue(app.tabBars.buttons["Guide"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Guide"].isSelected, "closing Settings goes back to the tab it opened over")
        XCTAssertFalse(element(app, "settings.profile").exists)
    }

    private static let home = "settings.source.00000000-0000-0000-0000-0000000000D1"
    private static let cabin = "settings.source.00000000-0000-0000-0000-0000000000D2"

    private func openSettings(_ scenario: String = "channels") -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", scenario]
        app.launchInEnglish()
        app.openSettings(timeout: 10)
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    // sources-and-settings/see-how-each-source-is-doing
    func testEachSourceShowsItsStatusAndNoLink() {
        let app = openSettings("error")
        let home = element(app, Self.home)
        let cabin = element(app, Self.cabin)
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        XCTAssertTrue(cabin.exists)
        let homeFailed = NSPredicate(format: "label CONTAINS[c] 'M3U' AND NOT (label CONTAINS[c] 'Loading')")
        expectation(for: homeFailed, evaluatedWith: home)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(cabin.label.contains("Waiting for login from iCloud"), cabin.label)
        XCTAssertFalse(home.label.contains("fixture"), "a row shows the link")
        XCTAssertFalse(cabin.label.contains("fixture"), "a row shows the link")
        XCTAssertTrue(element(app, "settings.iCloudFooter").exists)
        XCTAssertTrue(element(app, "settings.refreshAll").exists)
    }

    // sources-and-settings/see-how-each-source-is-doing
    func testALoadedSourceShowsItsChannelCount() {
        let app = openSettings()
        let home = element(app, Self.home)
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        let loaded = NSPredicate(format: "label CONTAINS '4 channels'")
        expectation(for: loaded, evaluatedWith: home)
        waitForExpectations(timeout: 10)
    }

    // sources-and-settings/your-password-stays-hidden
    func testDetailsShowAnEmptyPasswordField() {
        let app = openSettings()
        let cabin = element(app, Self.cabin)
        XCTAssertTrue(cabin.waitForExistence(timeout: 10))
        cabin.tap()
        let password = element(app, "settings.details.password")
        XCTAssertTrue(password.waitForExistence(timeout: 5))
        XCTAssertNotEqual(password.value as? String, "fixture")
        XCTAssertTrue(element(app, "settings.details.username").exists)
        let delete = element(app, "settings.details.delete")
        // Delete sits below the fields, past the bottom of an iPhone screen.
        if !delete.exists { app.swipeUp() }
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
    }

    // sources-and-settings/a-user-agent-per-source
    func testAPlaylistSourceTakesAUserAgent() {
        let app = openSettings()
        let home = element(app, Self.home)
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        home.tap()
        let agent = element(app, "settings.details.userAgent")
        XCTAssertTrue(agent.waitForExistence(timeout: 5))
        agent.tap()
        agent.typeText("Box/1")
        let save = element(app, "settings.details.save")
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertEqual(agent.value as? String, "Box/1")
    }

    // sources-and-settings/delete-a-source-and-everything-that-came-with-it
    func testDeletingEverySourceReturnsToOnboarding() {
        let app = openSettings()
        for id in [Self.home, Self.cabin] {
            let row = element(app, id)
            XCTAssertTrue(row.waitForExistence(timeout: 10))
            row.tap()
            let delete = element(app, "settings.details.delete")
            // A playlist's details are taller than the screen; Delete sits below the fields.
            if !delete.waitForExistence(timeout: 5) { app.swipeUp() }
            XCTAssertTrue(delete.waitForExistence(timeout: 5))
            delete.tap()
            let confirm = app.alerts.buttons["Delete"].firstMatch
            XCTAssertTrue(confirm.waitForExistence(timeout: 5))
            XCTAssertTrue(app.alerts.firstMatch.label.hasPrefix("Delete "))
            confirm.tap()
            if id == Self.home { XCTAssertTrue(row.waitForNonExistence(timeout: 5)) }
        }
        XCTAssertTrue(element(app, "onboarding.welcome").waitForExistence(timeout: 10))
    }

    // sources-and-settings/delete-a-source-and-everything-that-came-with-it
    func testCancellingADeleteChangesNothing() {
        let app = openSettings()
        let home = element(app, Self.home)
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        home.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        let cancel = app.alerts.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertTrue(home.exists)
    }
}
