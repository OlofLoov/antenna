import XCTest

/// "Set up Apple TV" on iPhone: a setup link opened at launch with
/// `-ui-testing-setup-link`, as a scanned code would, and the upload
/// scripted with `-ui-testing-setup-delivery`. Connect answers from the
/// onboarding stub, where `http://onboarding.test/tv.m3u` holds two channels.
@MainActor
final class SetupUITests: XCTestCase {
    static let link = "https://antenna.codecrave.se/setup?v=1&t=AAAAAAAAAAAAAAAAAAAAAA"

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(
        link: String = SetupUITests.link, delivery: String = "silent", timeout: Int? = nil, extra: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments =
            ["-ui-testing-onboarding", "connect", "-ui-testing-setup-link", link, "-ui-testing-setup-delivery", delivery] + extra
        if let timeout { app.launchEnvironment["UITESTING_SETUP_SEND_TIMEOUT_SECONDS"] = "\(timeout)" }
        app.launch()
        return app
    }

    /// Fills in the playlist and taps Connect.
    private func connectPlaylist(_ app: XCUIApplication) {
        app.element("onboarding.kind.m3u").tap()
        let field = app.element("onboarding.field.playlist")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("http://onboarding.test/tv.m3u")
        app.element("onboarding.connect").tap()
    }

    // iphone-as-setup-device/scanning-opens-the-setup-form-on-the-iphone
    func testALinkOpensSetUpAppleTVAndCancelSavesNothing() {
        let app = launch()
        XCTAssertTrue(app.element("onboarding.fromTV.banner").waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["Set up Apple TV"].exists)
        XCTAssertTrue(app.element("onboarding.kind.xtream").isSelected)
        XCTAssertFalse(app.element("onboarding.fromTV.existing").exists)
        XCTAssertFalse(app.element("import.pickFile").exists)
        app.element("onboarding.fromTV.cancel").tap()
        XCTAssertTrue(app.element("onboarding.fromTV.banner").waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.element("onboarding.welcome").exists)
    }

    // iphone-as-setup-device/scanning-opens-the-setup-form-on-the-iphone
    func testADamagedLinkOpensThePlainForm() {
        let app = launch(link: "https://antenna.codecrave.se/setup?v=1&t=broken")
        XCTAssertTrue(app.navigationBars["Add a source"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.element("onboarding.fromTV.banner").exists)
        XCTAssertFalse(app.element("onboarding.fromTV.update").exists)
        XCTAssertFalse(app.element("onboarding.error").exists)
    }

    // iphone-as-setup-device/scanning-opens-the-setup-form-on-the-iphone
    func testANewerLinkAsksToUpdate() {
        let app = launch(link: "https://antenna.codecrave.se/setup?v=2&t=AAAAAAAAAAAAAAAAAAAAAA")
        XCTAssertTrue(app.element("onboarding.fromTV.update").waitForExistence(timeout: 10))
        let update = app.element("onboarding.fromTV.update").label
        XCTAssertTrue(update.hasPrefix("This code is from a newer Antenna. Update Antenna on this iPhone"))
        XCTAssertFalse(app.element("onboarding.fromTV.banner").exists)
    }

    // iphone-as-setup-device/scanning-opens-the-setup-form-on-the-iphone
    func testThePaywallHoldsTheLinkUntilThePurchase() {
        let app = launch(extra: ["-antenna.entitlement", "locked", "-antenna.store", "products"])
        XCTAssertTrue(app.element("paywall.root").waitForExistence(timeout: 10))
        XCTAssertFalse(app.element("onboarding.fromTV.banner").exists)
        app.element("paywall.product.lifetime").tap()
        XCTAssertTrue(app.element("onboarding.fromTV.banner").waitForExistence(timeout: 10))
    }

    // iphone-as-setup-device/the-iphone-shows-the-source-on-its-way
    // iphone-as-setup-device/the-iphone-says-what-to-check-when-sending-stalls
    func testConnectShowsSendingThatCannotBeSwipedAwayThenNotSentYet() {
        let app = launch(timeout: 3)
        XCTAssertTrue(app.element("onboarding.fromTV.banner").waitForExistence(timeout: 10))
        connectPlaylist(app)
        let sending = app.element("onboarding.sending")
        XCTAssertTrue(sending.waitForExistence(timeout: 10))
        XCTAssertTrue(app.element("onboarding.sending.row.saved").label.hasPrefix("Done. Saved on this iPhone."))
        XCTAssertTrue(app.element("onboarding.sending.row.tv").label.hasPrefix("In progress. Sending to your Apple TV…"))
        XCTAssertFalse(app.element("onboarding.fromTV.cancel").exists)
        sending.swipeDown(velocity: .fast)
        XCTAssertTrue(sending.exists, "the sending screen was swiped away")
        let notSent = NSPredicate(format: "label BEGINSWITH %@", "Not done. Not sent yet. Check that this iPhone is online")
        expectation(for: notSent, evaluatedWith: app.element("onboarding.sending.row.tv"))
        waitForExpectations(timeout: 10)
        app.element("onboarding.sending.continue").tap()
        XCTAssertTrue(app.element("onboarding.checklist").waitForExistence(timeout: 10))
    }

    // iphone-as-setup-device/the-iphone-confirms-the-hand-off-to-icloud
    func testAConfirmedUploadReadsHandedToICloud() {
        let app = launch(delivery: "confirm")
        XCTAssertTrue(app.element("onboarding.fromTV.banner").waitForExistence(timeout: 10))
        connectPlaylist(app)
        let sent = NSPredicate(format: "label == %@", "Done. Handed to iCloud. Open Antenna on your Apple TV.")
        expectation(for: sent, evaluatedWith: app.element("onboarding.sending.row.tv"))
        waitForExpectations(timeout: 10)
    }

    // iphone-as-setup-device/the-iphone-says-what-to-check-when-sending-stalls
    func testNotSignedInReadsNotSentAtOnce() {
        let app = launch(delivery: "signedOut")
        XCTAssertTrue(app.element("onboarding.fromTV.banner").waitForExistence(timeout: 10))
        connectPlaylist(app)
        let row = app.element("onboarding.sending.row.tv")
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let notSignedIn = NSPredicate(format: "label CONTAINS %@", "isn't signed in to iCloud")
        expectation(for: notSignedIn, evaluatedWith: row)
        waitForExpectations(timeout: 5)
    }
}
