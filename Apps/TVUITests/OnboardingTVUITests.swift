import XCTest

/// The Apple TV welcome screen for a user with no source.
@MainActor
final class OnboardingTVUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-onboarding", scenario]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    // first-run-onboarding/a-new-user-is-asked-for-a-provider
    func testNoSourceOpensOnTheWelcomeScreenWithAddASourceFocused() {
        let app = launch("signedIn")
        XCTAssertTrue(element(app, "onboarding.welcome").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "onboarding.iCloudNote").exists)
        XCTAssertTrue(element(app, "onboarding.addSource").hasFocus)
        XCTAssertFalse(element(app, "shell.player").exists, "the shell shows behind onboarding")
    }

    // first-run-onboarding/a-new-user-is-asked-for-a-provider
    func testNotSignedInToICloudHidesTheSyncLine() {
        let app = launch("signedOut")
        XCTAssertTrue(element(app, "onboarding.welcome").waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "onboarding.iCloudNote").exists)
    }

    // first-run-onboarding/a-new-user-is-asked-for-a-provider
    func testWhatIsASourceOpensAndDoneCloses() {
        let app = launch("signedIn")
        XCTAssertTrue(element(app, "onboarding.addSource").waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.down)
        XCTAssertTrue(element(app, "onboarding.help").hasFocus)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.helpSheet").waitForExistence(timeout: 5))
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.helpSheet").waitForNonExistence(timeout: 5))
        XCTAssertTrue(element(app, "onboarding.welcome").exists)
    }

    // first-run-onboarding/a-new-user-is-asked-for-a-provider: Menu sends the app to the background.
    func testMenuOnTheWelcomeScreenLeavesTheApp() {
        let app = launch("signedIn")
        XCTAssertTrue(element(app, "onboarding.welcome").waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10) || app.state == .runningBackgroundSuspended)
    }
}
