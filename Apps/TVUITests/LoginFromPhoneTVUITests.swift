import XCTest

/// The Apple TV's "Send the login from your iPhone" card on onboarding's
/// sign-in step, and the login that follows a source sent from the setup
/// card. `-ui-testing-signin-sources` seeds sources without logins and
/// `-ui-testing-login-drops` stands in for the iPhone, sealing logins to
/// the code on screen into an in-memory drop store.
@MainActor
final class LoginFromPhoneTVUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(
        _ scenario: String, sources: Int? = nil, drops mode: String, send kind: String? = nil, environment: [String: String] = [:]
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-onboarding", scenario, "-ui-testing-login-drops", mode]
        if let sources { app.launchArguments += ["-ui-testing-signin-sources", "\(sources)"] }
        if let kind { app.launchArguments += ["-ui-testing-setup-send", kind] }
        app.launchEnvironment = environment
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// The loading checklist, or the summary when the scripted source loads at once.
    private func waitForLoading(_ app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if element(app, "onboarding.checklist").exists || element(app, "onboarding.summary").exists { return true }
            _ = element(app, "onboarding.summary").waitForExistence(timeout: 1)
        }
        return false
    }

    // apple-tv-login-from-iphone/the-apple-tv-sign-in-offers-a-qr-code
    // apple-tv-login-from-iphone/the-sign-in-reads-well-without-sight-or-motion
    func testTheSignInShowsTheQRCardAndFocusSkipsTheCode() {
        let app = launch("connect", sources: 2, drops: "silent")
        XCTAssertTrue(element(app, "onboarding.signIn").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "signIn.qr").waitForExistence(timeout: 5))
        let code = element(app, "signIn.qr.code")
        XCTAssertEqual(code.label, "QR code. Scan it with your iPhone to send the login to this Apple TV.")
        XCTAssertTrue(element(app, "signIn.qr.status").label.contains("Waiting for your iPhone · 2 logins"))
        XCTAssertFalse(element(app, "onboarding.keyboardCard").exists)
        for direction in [XCUIRemote.Button.right, .right, .down, .down, .right, .up] {
            XCUIRemote.shared.press(direction)
            XCTAssertFalse(code.hasFocus)
        }
    }

    // apple-tv-login-from-iphone/the-apple-tv-sign-in-offers-a-qr-code
    func testSignedOutShowsTheKeyboardCard() {
        let app = launch("signedOut", sources: 1, drops: "silent")
        XCTAssertTrue(element(app, "onboarding.signIn").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "onboarding.keyboardCard").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "signIn.qr").exists)
    }

    // apple-tv-login-from-iphone/the-apple-tv-checks-a-login-before-keeping-it
    func testADeliveredLoginSignsInWithoutTheRemote() {
        let app = launch("connect", sources: 1, drops: "deliver")
        XCTAssertTrue(waitForLoading(app, timeout: 15))
        XCTAssertFalse(element(app, "onboarding.signIn").exists)
    }

    // apple-tv-login-from-iphone/the-apple-tv-checks-a-login-before-keeping-it
    func testALoginThatDoesNotWorkAsksOnTheTV() {
        let app = launch("connect", sources: 2, drops: "deliver")
        let error = element(app, "onboarding.error")
        XCTAssertTrue(error.waitForExistence(timeout: 15))
        XCTAssertTrue(error.label.hasPrefix("The login from your iPhone didn't work here."))
        // The failing source is the one on screen: its server could not be reached.
        XCTAssertTrue(error.label.contains("refuse.test"))
        XCTAssertTrue(element(app, "signIn.qr.status").label.contains("Waiting for your iPhone"))
    }

    // apple-tv-login-from-iphone/the-apple-tv-checks-a-login-before-keeping-it
    func testADeliveryTheTVCannotRead() {
        let app = launch("connect", sources: 1, drops: "unreadable")
        let status = element(app, "signIn.qr.status")
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        let unreadable = NSPredicate(format: "label CONTAINS %@", "can't read")
        expectation(for: unreadable, evaluatedWith: status)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(element(app, "signIn.qr.hint").label.contains("Update Antenna on both"))
    }

    // apple-tv-login-from-iphone/the-apple-tv-checks-a-login-before-keeping-it
    func testTheHintAppearsWhenNothingArrives() {
        let app = launch("connect", sources: 1, drops: "silent", environment: ["UITESTING_SETUP_HINT_SECONDS": "2"])
        let hint = element(app, "signIn.qr.hint")
        XCTAssertTrue(hint.waitForExistence(timeout: 10))
        XCTAssertTrue(hint.label.hasPrefix("Nothing yet? Your iPhone needs Antenna installed"))
    }

    // iphone-as-setup-device/a-login-source-sent-from-the-iphone-needs-only-its-login-on-the-tv
    func testTheLoginFollowsASourceFromTheSetupCard() {
        let app = launch("connect", drops: "deliver", send: "xtream")
        XCTAssertTrue(element(app, "onboarding.addSource").waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.kind.m3u").waitForExistence(timeout: 5))
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(waitForLoading(app, timeout: 20))
    }
}
