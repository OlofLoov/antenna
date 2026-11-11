import XCTest

/// The welcome screen for a user with no source.
@MainActor
final class OnboardingUITests: XCTestCase {
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
    func testNoSourceOpensOnTheWelcomeScreen() {
        let app = launch("signedIn")
        XCTAssertTrue(element(app, "onboarding.welcome").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "onboarding.addSource").exists)
        XCTAssertTrue(element(app, "onboarding.iCloudNote").exists)
        XCTAssertFalse(app.tabBars.buttons["Live"].exists, "the app shows behind onboarding")
        XCTAssertFalse(element(app, "channels.emptyState").exists)
    }

    // first-run-onboarding/a-new-user-is-asked-for-a-provider
    func testNotSignedInToICloudHidesTheSyncNote() {
        let app = launch("signedOut")
        XCTAssertTrue(element(app, "onboarding.welcome").waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "onboarding.iCloudNote").exists)
    }

    // first-run-onboarding/a-new-user-is-asked-for-a-provider
    func testWhatIsASourceOpensAndCloses() {
        let app = launch("signedIn")
        XCTAssertTrue(element(app, "onboarding.help").waitForExistence(timeout: 10))
        element(app, "onboarding.help").tap()
        XCTAssertTrue(element(app, "onboarding.helpSheet").waitForExistence(timeout: 5))
        element(app, "onboarding.helpDone").tap()
        XCTAssertTrue(element(app, "onboarding.helpSheet").waitForNonExistence(timeout: 5))
        XCTAssertTrue(element(app, "onboarding.welcome").exists)
    }
}
