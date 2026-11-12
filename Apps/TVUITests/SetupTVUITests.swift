import XCTest

/// The Apple TV's "Set up from your iPhone" card on the details step. The
/// app stands in for the iPhone with `-ui-testing-setup-send`, saving a
/// source to the store as iCloud would.
@MainActor
final class SetupTVUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ scenario: String, send kind: String? = nil, hintSeconds: Int? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-onboarding", scenario]
        if let kind { app.launchArguments += ["-ui-testing-setup-send", kind] }
        if let hintSeconds { app.launchEnvironment["UITESTING_SETUP_HINT_SECONDS"] = "\(hintSeconds)" }
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Add a source, then the M3U playlist type, which opens the details step.
    private func openDetails(_ app: XCUIApplication) {
        XCTAssertTrue(element(app, "onboarding.addSource").waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.kind.m3u").waitForExistence(timeout: 5))
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.field.playlist").waitForExistence(timeout: 5))
    }

    // iphone-as-setup-device/the-apple-tv-offers-a-qr-code
    func testSignedInShowsTheQRCard() {
        let app = launch("signedIn")
        openDetails(app)
        XCTAssertTrue(element(app, "onboarding.qr").waitForExistence(timeout: 5))
        XCTAssertEqual(element(app, "onboarding.qr.code").label, "QR code. Scan it with your iPhone to set up this Apple TV from there.")
        XCTAssertTrue(element(app, "onboarding.qr.status").label.contains("Waiting for your iPhone"))
        XCTAssertFalse(element(app, "onboarding.keyboardCard").exists)
    }

    // iphone-as-setup-device/no-icloud-no-qr-code
    func testSignedOutShowsTheKeyboardCard() {
        let app = launch("signedOut")
        openDetails(app)
        XCTAssertTrue(element(app, "onboarding.keyboardCard").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "onboarding.qr").exists)
    }

    // iphone-as-setup-device/a-playlist-source-sent-from-the-iphone-starts-loading-on-the-tv
    func testAPlaylistFromThePhoneStartsLoading() {
        let app = launch("connect", send: "m3u")
        openDetails(app)
        // The scripted playlist loads at once, so the checklist goes straight to the summary.
        XCTAssertTrue(element(app, "onboarding.summary").waitForExistence(timeout: 15))
        XCTAssertFalse(element(app, "onboarding.qr").exists)
    }

    // iphone-as-setup-device/a-login-source-sent-from-the-iphone-needs-only-its-login-on-the-tv
    func testAnXtreamSourceFromThePhoneAsksForTheLogin() {
        let app = launch("signedIn", send: "xtream")
        openDetails(app)
        XCTAssertTrue(element(app, "onboarding.signIn").waitForExistence(timeout: 15))
        XCTAssertEqual(element(app, "onboarding.field.server").value as? String, "http://xtream.test")
        XCTAssertEqual(element(app, "onboarding.field.name").value as? String, "Home provider")
        XCTAssertTrue(element(app, "onboarding.qr.status").label.contains("Home provider arrived from your iPhone"))
        let signInHere = element(app, "onboarding.qr.signInHere")
        XCTAssertTrue(signInHere.waitForExistence(timeout: 5))
        XCTAssertTrue(signInHere.hasFocus)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(signInHere.waitForNonExistence(timeout: 5))
        XCTAssertTrue(element(app, "onboarding.field.username").hasFocus)
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(element(app, "onboarding.kind.m3u").waitForExistence(timeout: 5))
    }

    // iphone-as-setup-device/a-login-source-sent-from-the-iphone-needs-only-its-login-on-the-tv
    func testAStalkerPortalFromThePhoneAsksForTheMAC() {
        let app = launch("signedIn", send: "stalker")
        openDetails(app)
        XCTAssertTrue(element(app, "onboarding.signIn").waitForExistence(timeout: 15))
        XCTAssertEqual(element(app, "onboarding.field.portal").value as? String, "http://portal.test/c/")
        XCTAssertTrue(element(app, "onboarding.field.mac").exists)
    }

    // iphone-as-setup-device/nothing-arrives-and-the-tv-says-why-that-might-be
    func testTheHintAppearsWhenNothingArrives() {
        let app = launch("signedIn", hintSeconds: 2)
        openDetails(app)
        let hint = element(app, "onboarding.qr.hint")
        XCTAssertTrue(hint.waitForExistence(timeout: 10))
        XCTAssertTrue(hint.label.hasPrefix("Nothing yet? Your iPhone needs Antenna installed"))
    }

    // iphone-as-setup-device/nothing-arrives-and-the-tv-says-why-that-might-be
    func testASourceTheCardCannotSetUpAsksToUpdate() {
        let app = launch("signedIn", send: "plex", hintSeconds: 4)
        openDetails(app)
        let hint = element(app, "onboarding.qr.hint")
        XCTAssertTrue(hint.waitForExistence(timeout: 12))
        XCTAssertTrue(hint.label.contains("Update Antenna, or type the source here."))
    }
}
