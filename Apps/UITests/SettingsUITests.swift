import XCTest

/// Settings, About.
@MainActor
final class SettingsUITests: XCTestCase {
    // The FFmpeg notice that FFmpeg's LGPL license asks for (add-playback-engine task 6.2).
    func testAboutShowsTheFFmpegNotice() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"]
        app.launch()

        let tab = app.tabBars.buttons["Settings"]
        let button = tab.waitForExistence(timeout: 10) ? tab : app.buttons["Settings"].firstMatch
        XCTAssertTrue(button.exists, "no Settings tab button")
        button.tap()

        let notice = app.descendants(matching: .any)["settings.ffmpegNotice"].firstMatch
        if !notice.waitForExistence(timeout: 5) { app.swipeUp() }
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        notice.tap()

        let text = app.staticTexts["ffmpegNotice.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertTrue(text.label.contains("GNU Lesser General Public License, version 2.1"))
        XCTAssertTrue(app.descendants(matching: .any)["ffmpegNotice.source"].firstMatch.exists)
    }

    private static let home = "settings.source.00000000-0000-0000-0000-0000000000D1"
    private static let cabin = "settings.source.00000000-0000-0000-0000-0000000000D2"

    private func openSettings(_ scenario: String = "channels") -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", scenario]
        app.launch()
        let tab = app.tabBars.buttons["Settings"]
        let button = tab.waitForExistence(timeout: 10) ? tab : app.buttons["Settings"].firstMatch
        button.tap()
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
        XCTAssertTrue(element(app, "settings.details.delete").exists)
    }

    // sources-and-settings/delete-a-source-and-everything-that-came-with-it
    func testDeletingEverySourceReturnsToOnboarding() {
        let app = openSettings()
        for id in [Self.home, Self.cabin] {
            let row = element(app, id)
            XCTAssertTrue(row.waitForExistence(timeout: 10))
            row.tap()
            let delete = element(app, "settings.details.delete")
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
