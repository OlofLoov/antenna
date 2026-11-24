import XCTest

/// The paywall on Apple TV, with the stand-in provider and scripted App Store
/// of `UITestingPaywall` over the shell's scripted sources.
@MainActor
final class PaywallTVUITests: XCTestCase {
    var app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(entitlement: String, store: String = "products") {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels", "-antenna.entitlement", entitlement, "-antenna.store", store]
        app.launchInEnglish()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func expect(_ element: XCUIElement, value contains: String, timeout: TimeInterval = 5, line: UInt = #line) {
        let predicate = NSPredicate(format: "value CONTAINS %@", contains)
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(element) never had a value containing \(contains)", line: line)
    }

    // tvos-shell/the-shell-waits-for-the-unlock
    // paywall-and-entitlement/honest-paywall-wording
    func testWithoutAPurchaseThePaywallShowsAndNoChannelIsTuned() {
        launch(entitlement: "locked")
        XCTAssertTrue(element("paywall.root").waitForExistence(timeout: 10))
        expect(element("paywall.product.lifetime"), value: "$29.99")
        XCTAssertTrue(element("paywall.legal").exists, "the addresses as text")
        XCTAssertFalse(element("paywall.redeem").exists, "no offer codes on Apple TV")
        XCTAssertFalse(element("shell.debug.engine").exists, "the shell did not open")
    }

    // design-system/apple-tv-content-stays-in-the-safe-area
    // The legal line sat 56 pt over the safe area's own 60; it ends at the 60 pt foot.
    func testThePaywallKeepsTheSafeEdges() {
        launch(entitlement: "locked")
        let legal = element("paywall.legal")
        XCTAssertTrue(legal.waitForExistence(timeout: 10))
        XCTAssertEqual(legal.frame.maxY, app.frame.height - 60, accuracy: 2, "the legal line ends at the safe foot")
        XCTAssertGreaterThanOrEqual(legal.frame.minX, 80, "the legal line stays inside the safe edge")
        XCTAssertGreaterThanOrEqual(element("paywall.title").frame.minY, 60)
    }

    // tvos-shell/the-shell-waits-for-the-unlock
    // paywall-and-entitlement/buy-once-and-you-re-in
    func testBuyingWithTheRemoteOpensTheShell() {
        launch(entitlement: "locked")
        XCTAssertTrue(element("paywall.product.lifetime").waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element("shell.debug.engine").waitForExistence(timeout: 10))
        XCTAssertFalse(element("paywall.root").exists)
    }

    // paywall-and-entitlement/restore-your-purchase
    // paywall-and-entitlement/a-restored-purchase-ends-with-got-it
    func testRestoreSaysWelcomeBackUntilContinue() {
        launch(entitlement: "revoked", store: "restoreShared")
        XCTAssertTrue(element("paywall.restore").waitForExistence(timeout: 10))
        expect(element("paywall.lapsedNote"), value: "lapsed.revoked")
        XCUIRemote.shared.press(.down)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element("paywall.continue").waitForExistence(timeout: 10))
        XCTAssertEqual(element("paywall.mark").value as? String, "gotIt")
        XCTAssertFalse(element("shell.debug.engine").exists, "the shell waits for Continue")
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element("shell.debug.engine").waitForExistence(timeout: 10))
    }
}
