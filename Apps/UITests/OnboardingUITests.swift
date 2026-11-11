import XCTest

/// The welcome screen for a user with no source.
@MainActor
final class OnboardingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ scenario: String, _ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-onboarding", scenario] + extra
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

    // first-run-onboarding/mistakes-in-the-form-are-caught-before-connecting
    func testConnectWithAnEmptyFieldSaysWhatToFix() {
        let app = launch("signedIn")
        XCTAssertTrue(element(app, "onboarding.addSource").waitForExistence(timeout: 10))
        element(app, "onboarding.addSource").tap()
        XCTAssertTrue(element(app, "onboarding.connect").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding.kind.stalker"].isEnabled, "Stalker cannot be picked")
        XCTAssertFalse(element(app, "onboarding.clipboard").exists, "no banner without a link")
        element(app, "onboarding.connect").tap()
        XCTAssertTrue(element(app, "onboarding.error").waitForExistence(timeout: 5))
        XCTAssertEqual(element(app, "onboarding.error").label, "Enter the server address.")
        element(app, "onboarding.kind.m3u").tap()
        XCTAssertTrue(element(app, "onboarding.field.playlist").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "onboarding.field.guide").exists)
        element(app, "onboarding.back").tap()
        XCTAssertTrue(element(app, "onboarding.welcome").waitForExistence(timeout: 5))
    }

    // first-run-onboarding/fill-the-form-from-a-copied-link
    func testFillInFromACopiedLink() {
        let app = launch("signedIn", ["-ui-testing-clipboard", "http://tv.example.test:8080/get.php?username=anna&password=pw"])
        XCTAssertTrue(element(app, "onboarding.addSource").waitForExistence(timeout: 10))
        element(app, "onboarding.addSource").tap()
        XCTAssertTrue(element(app, "onboarding.fillIn").waitForExistence(timeout: 5))
        element(app, "onboarding.fillIn").tap()
        XCTAssertEqual(element(app, "onboarding.field.server").value as? String, "http://tv.example.test:8080")
        XCTAssertEqual(element(app, "onboarding.field.username").value as? String, "anna")
        XCTAssertFalse(element(app, "onboarding.clipboard").exists)
    }
}
