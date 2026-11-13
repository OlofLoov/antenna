import XCTest

/// Signing in an Xtream source from its details in Settings on Apple TV.
/// `-ui-testing-signin-playlist` puts a playlist that loads before
/// `Home provider`, an Xtream source at `xtream.test` with no login on this
/// TV, so the app opens on Live and the source waits in Settings.
/// `-ui-testing-login-drops` stands in for the iPhone behind the QR card.
@MainActor
final class SourceSignInTVUITests: XCTestCase {
    let remote = XCUIRemote.shared
    var app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(drops mode: String) {
        app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-onboarding", "connect", "-ui-testing-login-drops", mode, "-ui-testing-signin-sources", "1",
            "-ui-testing-signin-playlist",
        ]
        app.launch()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func expect(
        _ element: XCUIElement, _ predicate: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: timeout), .completed, "\(element) never matched \(predicate)", file: file,
            line: line)
    }

    /// Presses `button` one step at a time until `target` has focus.
    private func press(
        _ button: XCUIRemote.Button, toFocus target: XCUIElement, limit: Int = 12, file: StaticString = #filePath, line: UInt = #line
    ) {
        for _ in 0..<limit where !target.hasFocus {
            remote.press(button)
            _ = target.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(target.hasFocus, "\(target) never took focus", file: file, line: line)
    }

    /// Presses `button` until an element whose label contains `label` has focus.
    private func press(
        _ button: XCUIRemote.Button, untilFocused label: String, limit: Int = 12, file: StaticString = #filePath, line: UInt = #line
    ) {
        let focused = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true AND label CONTAINS %@", label))
            .firstMatch
        for _ in 0..<limit {
            if focused.waitForExistence(timeout: 1) { return }
            remote.press(button)
        }
        XCTAssertTrue(focused.waitForExistence(timeout: 2), "\(label) never took focus", file: file, line: line)
    }

    /// From Live, opens `Home provider`'s details in Settings.
    private func openHomeProvider() {
        // The playlist loads but its stream cannot play here, so Live shows the player error.
        XCTAssertTrue(element("player.error").waitForExistence(timeout: 20), "Live never opened")
        let settings = element("shell.settings")
        for _ in 0..<3 where !settings.exists {
            remote.press(.menu)
            _ = settings.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(settings.exists, "the tab bar never opened")
        press(.right, toFocus: settings)
        remote.press(.select)
        press(.down, untilFocused: "Home provider")
        remote.press(.select)
        XCTAssertTrue(element("settings.details.status").waitForExistence(timeout: 10))
        expect(element("settings.details.status"), "label CONTAINS 'Not signed in on this Apple TV'")
    }

    /// Selects `field`, types `text` on the TV keyboard and closes it.
    private func type(_ text: String, into field: XCUIElement) {
        press(.down, toFocus: field)
        remote.press(.select)
        app.typeText(text)
        remote.press(.menu)
        expect(app.keyboards.firstMatch, "exists == false")
    }

    // sources-and-settings/sign-in-on-this-apple-tv
    func testSignInOnThisAppleTVLoadsTheSource() {
        launch(drops: "silent")
        openHomeProvider()
        type("anna", into: element("settings.details.username"))
        type("secret", into: element("settings.details.password"))
        // A button in a Form reports focus on its cell, so focus is found by label.
        press(.up, untilFocused: "Sign in on this Apple TV")
        remote.press(.select)

        expect(element("settings.details.status"), "label CONTAINS '1 channel'", timeout: 20)
        XCTAssertFalse(element("settings.details.signIn").exists)
    }

    // apple-tv-login-from-iphone/the-apple-tv-sign-in-offers-a-qr-code, from a source's details
    // apple-tv-login-from-iphone/the-apple-tv-checks-a-login-before-keeping-it
    func testALoginFromTheIPhoneLoadsTheSourceFromItsDetails() {
        launch(drops: "deliver")
        // The playlist loads but its stream cannot play here, so Live shows the player error.
        XCTAssertTrue(element("player.error").waitForExistence(timeout: 20), "Live never opened")
        let settings = element("shell.settings")
        for _ in 0..<3 where !settings.exists {
            remote.press(.menu)
            _ = settings.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(settings.exists, "the tab bar never opened")
        press(.right, toFocus: settings)
        remote.press(.select)
        press(.down, untilFocused: "Home provider")
        remote.press(.select)

        XCTAssertTrue(element("signIn.qr").waitForExistence(timeout: 10), "the QR card never showed")
        expect(element("settings.details.status"), "label CONTAINS '1 channel'", timeout: 30)
        XCTAssertFalse(element("signIn.qr").exists)
    }
}
