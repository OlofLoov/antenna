import XCTest

/// "Sign in your Apple TV" on iPhone: a sign-in code opened at launch with
/// `-ui-testing-setup-link`, sources seeded with `-ui-testing-signin-sources 3`
/// (Home provider with its login here, Holiday flat and Cabin without),
/// and iCloud scripted with `-ui-testing-login-drops`.
@MainActor
final class SendLoginsUITests: XCTestCase {
    /// The public half of a fixed test key, safe to publish.
    static let key = "E75P6uryBMf9M1j8nAByGIHRdCeBKCJ-xnTzf3_pe20"  // gitleaks:allow
    static let home = "AAAAAAAAAAAAAAAAAAAAoQ"
    static let flat = "AAAAAAAAAAAAAAAAAAAAog"
    static let cabin = "AAAAAAAAAAAAAAAAAAAAow"
    static let elsewhere = "AAAAAAAAAAAAAAAAAAAApA"

    override func setUp() {
        continueAfterFailure = false
    }

    private static func link(_ sources: [String]) -> String {
        "https://antenna.codecrave.se/setup?v=2&t=AAAAAAAAAAAAAAAAAAAAAA&k=\(key)&s=\(sources.joined(separator: ","))"
    }

    private func launch(
        _ sources: [String], drops: String = "silent", link: String? = nil, environment: [String: String] = [:], extra: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments =
            [
                "-ui-testing-onboarding", "connect", "-ui-testing-signin-sources", "3", "-ui-testing-login-drops", drops,
                "-ui-testing-setup-link", link ?? Self.link(sources),
            ] + extra
        app.launchEnvironment = environment
        app.launch()
        return app
    }

    private func rows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "sendLogins.row")
    }

    private func expectLabel(_ element: XCUIElement, contains text: String, timeout: TimeInterval = 10) {
        expectation(for: NSPredicate(format: "label CONTAINS %@", text), evaluatedWith: element)
        waitForExpectations(timeout: timeout)
    }

    // apple-tv-login-from-iphone/the-iphone-asks-before-it-sends
    // apple-tv-login-from-iphone/sources-the-iphone-does-not-have
    // apple-tv-login-from-iphone/the-sign-in-reads-well-without-sight-or-motion
    func testTheSheetListsReadyMissingAndAbsentSources() {
        let app = launch([Self.home, Self.flat, Self.elsewhere])
        XCTAssertTrue(app.element("sendLogins.list").waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["Sign in Apple TV"].exists)
        XCTAssertEqual(rows(app).count, 2)
        XCTAssertEqual(rows(app).element(boundBy: 0).label, "Ready to send. Home provider. Xtream")
        XCTAssertEqual(rows(app).element(boundBy: 1).label, "Not on this iPhone. Holiday flat. Xtream")
        XCTAssertTrue(app.element("sendLogins.enter").exists)
        XCTAssertTrue(app.element("sendLogins.missing").label.hasPrefix("1 source the Apple TV asked for isn't on this iPhone yet."))
        XCTAssertTrue(app.element("sendLogins.send").isEnabled)
        app.element("sendLogins.cancel").tap()
        XCTAssertTrue(app.element("sendLogins.list").waitForNonExistence(timeout: 5))
    }

    // apple-tv-login-from-iphone/sources-the-iphone-does-not-have
    func testNoneOfTheSourcesOffersOnlyDone() {
        let app = launch([Self.elsewhere])
        let missing = app.element("sendLogins.missing")
        XCTAssertTrue(missing.waitForExistence(timeout: 10))
        XCTAssertTrue(missing.label.hasPrefix("None of the sources this Apple TV asked for are on this iPhone."))
        XCTAssertTrue(app.element("sendLogins.done").exists)
        XCTAssertFalse(app.element("sendLogins.send").exists)
    }

    // apple-tv-login-from-iphone/the-iphone-asks-before-it-sends
    func testADamagedSignInLinkSendsNothing() {
        let app = launch([], link: "https://antenna.codecrave.se/setup?v=2&t=AAAAAAAAAAAAAAAAAAAAAA&k=short&s=\(Self.home)")
        XCTAssertTrue(app.navigationBars["Add a source"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.element("sendLogins").exists)
    }

    // apple-tv-login-from-iphone/the-iphone-asks-before-it-sends
    func testThePaywallHoldsTheSheetUntilThePurchase() {
        let app = launch([Self.home], extra: ["-antenna.entitlement", "locked", "-antenna.store", "products"])
        XCTAssertTrue(app.element("paywall.root").waitForExistence(timeout: 10))
        XCTAssertFalse(app.element("sendLogins.list").exists)
        app.element("paywall.product.lifetime").tap()
        XCTAssertTrue(app.element("sendLogins.list").waitForExistence(timeout: 10))
    }

    // apple-tv-login-from-iphone/the-iphone-says-whether-the-tv-picked-it-up
    func testSendThenPickedUp() {
        let app = launch([Self.home], drops: "pickup")
        XCTAssertTrue(app.element("sendLogins.send").waitForExistence(timeout: 10))
        app.element("sendLogins.send").tap()
        expectLabel(app.element("sendLogins.status"), contains: "Your Apple TV picked up the logins.")
        XCTAssertFalse(app.element("sendLogins.cancel").exists)
        app.element("sendLogins.done").tap()
        XCTAssertTrue(app.element("sendLogins.list").waitForNonExistence(timeout: 5))
    }

    // apple-tv-login-from-iphone/the-iphone-says-whether-the-tv-picked-it-up
    func testNotPickedUpYet() {
        let app = launch([Self.home], environment: ["UITESTING_PICKUP_WAIT_SECONDS": "2"])
        XCTAssertTrue(app.element("sendLogins.send").waitForExistence(timeout: 10))
        app.element("sendLogins.send").tap()
        expectLabel(app.element("sendLogins.status"), contains: "Sending to your Apple TV")
        expectLabel(app.element("sendLogins.status"), contains: "Not picked up yet")
        XCTAssertTrue(app.element("sendLogins.done").exists)
    }

    // apple-tv-login-from-iphone/the-iphone-says-whether-the-tv-picked-it-up
    func testOfflineOffersTryAgain() {
        let app = launch([Self.home], drops: "offline")
        XCTAssertTrue(app.element("sendLogins.send").waitForExistence(timeout: 10))
        app.element("sendLogins.send").tap()
        expectLabel(app.element("sendLogins.status"), contains: "Couldn't send. Check that this iPhone is online")
        XCTAssertTrue(app.element("sendLogins.retry").exists)
    }

    // apple-tv-login-from-iphone/the-iphone-says-whether-the-tv-picked-it-up
    func testNotSignedInToICloud() {
        let app = launch([Self.home], drops: "signedOut")
        XCTAssertTrue(app.element("sendLogins.send").waitForExistence(timeout: 10))
        app.element("sendLogins.send").tap()
        expectLabel(app.element("sendLogins.status"), contains: "isn't signed in to iCloud")
        XCTAssertFalse(app.element("sendLogins.send").isEnabled)
        XCTAssertFalse(app.element("sendLogins.retry").exists)
    }

    // apple-tv-login-from-iphone/the-iphone-takes-a-login-it-does-not-have
    func testEnterAnAcceptedLogin() {
        let app = launch([Self.home, Self.cabin])
        XCTAssertTrue(app.element("sendLogins.enter").waitForExistence(timeout: 10))
        app.element("sendLogins.enter").tap()
        let username = app.element("sendLogins.enter.username")
        XCTAssertTrue(username.waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Cabin"].exists)
        username.tap()
        username.typeText("anna")
        app.element("sendLogins.enter.password").tap()
        app.element("sendLogins.enter.password").typeText("cabin")
        app.element("sendLogins.enter.check").tap()
        XCTAssertTrue(username.waitForNonExistence(timeout: 10))
        expectLabel(rows(app).element(boundBy: 1), contains: "Ready to send. Cabin")
        XCTAssertFalse(app.element("sendLogins.enter").exists)
    }

    // apple-tv-login-from-iphone/the-iphone-takes-a-login-it-does-not-have
    func testEnterARefusedLogin() {
        let app = launch([Self.flat])
        XCTAssertTrue(app.element("sendLogins.enter").waitForExistence(timeout: 10))
        app.element("sendLogins.enter").tap()
        let username = app.element("sendLogins.enter.username")
        XCTAssertTrue(username.waitForExistence(timeout: 5))
        username.tap()
        username.typeText("anna")
        app.element("sendLogins.enter.password").tap()
        app.element("sendLogins.enter.password").typeText("wrong")
        app.element("sendLogins.enter.check").tap()
        XCTAssertTrue(app.element("sendLogins.enter.error").waitForExistence(timeout: 10))
        app.element("sendLogins.enter.cancel").tap()
        expectLabel(rows(app).element(boundBy: 0), contains: "Not on this iPhone. Holiday flat")
        XCTAssertFalse(app.element("sendLogins.send").isEnabled)
    }
}
