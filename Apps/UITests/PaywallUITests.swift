import XCTest

/// The paywall-and-entitlement capability on iPhone. Each test launches with
/// `-antenna.entitlement <verdict>` and `-antenna.store <scenario>`
/// (`UITestingPaywall`): a stand-in provider and a scripted App Store.
/// Copy is matched by key, which debug builds expose as the accessibility value.
@MainActor
final class PaywallUITests: XCTestCase {
    nonisolated let log = FileManager.default.temporaryDirectory.appending(path: "paywall-engine-\(UUID().uuidString).log")

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: log)
    }

    private func launch(_ base: [String], entitlement: String = "locked", store: String = "products") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = base + ["-antenna.entitlement", entitlement, "-antenna.store", store]
        app.launchEnvironment["UITESTING_ENGINE_LOG"] = log.path
        app.launch()
        return app
    }

    private func onboarding(_ entitlement: String = "locked", store: String = "products") -> XCUIApplication {
        launch(["-ui-testing-onboarding", "signedIn"], entitlement: entitlement, store: store)
    }

    private var loaded: String { (try? String(contentsOf: log, encoding: .utf8)) ?? "" }

    private func waitForPaywall(_ app: XCUIApplication) {
        XCTAssertTrue(app.element("paywall.root").waitForExistence(timeout: 10), "the paywall never appeared")
    }

    private func expect(_ element: XCUIElement, value contains: String, timeout: TimeInterval = 5, line: UInt = #line) {
        let predicate = NSPredicate(format: "value CONTAINS %@", contains)
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(element) never had a value containing \(contains)", line: line)
    }

    // paywall-and-entitlement/nothing-works-before-the-app-is-unlocked
    // design-system/nothing-shows-before-the-paywall
    func testWithoutAPurchaseOnlyThePaywallShowsAndNoSourceIsContacted() {
        let app = launch(["-ui-testing-live", "channels"])
        waitForPaywall(app)
        XCTAssertTrue(app.element("paywall.title").exists)
        expect(app.element("paywall.title"), value: "title.default")
        XCTAssertFalse(app.element("browse.list").exists, "the app shows behind the paywall")
        XCTAssertFalse(app.tabBars.buttons["Live"].exists)
        XCTAssertFalse(app.element("onboarding.welcome").exists)
        XCTAssertTrue(app.element("paywall.restore").exists)
        XCTAssertEqual(loaded, "", "nothing played before the unlock")
    }

    // paywall-and-entitlement/nothing-works-before-the-app-is-unlocked
    func testASourceWaitingForItsLoginSeesTheSamePaywall() {
        let app = launch(["-ui-testing-live", "error"])
        waitForPaywall(app)
        expect(app.element("paywall.title"), value: "title.default")
        XCTAssertFalse(app.element("paywall.lapsedNote").exists)
    }

    // paywall-and-entitlement/prices-come-from-the-app-store
    // paywall-and-entitlement/honest-paywall-wording
    func testPricesRenewalOfferAndLegalShow() {
        let app = onboarding(store: "offer")
        waitForPaywall(app)
        expect(app.element("paywall.product.lifetime"), value: "$29.99 one time")
        expect(app.element("paywall.product.yearly"), value: "$9.99 per year")
        expect(app.element("paywall.product.yearly"), value: "line.freeTrial")
        XCTAssertTrue(app.element("paywall.familyNote").exists)
        XCTAssertTrue(app.element("paywall.legal").exists)
        XCTAssertTrue(app.element("paywall.redeem").exists, "offer codes on iPhone")
    }

    // paywall-and-entitlement/buy-once-and-you-re-in
    func testABuyerGoesStraightToOnboarding() {
        let app = onboarding()
        waitForPaywall(app)
        app.element("paywall.product.lifetime").tap()
        XCTAssertTrue(app.element("onboarding.welcome").waitForExistence(timeout: 10))
        XCTAssertFalse(app.element("paywall.root").exists)
    }

    // paywall-and-entitlement/buy-once-and-you-re-in
    func testAFailedPurchaseAsksToTryAgainAndACancelChangesNothing() {
        let app = onboarding(store: "failed")
        waitForPaywall(app)
        app.element("paywall.product.yearly").tap()
        expect(app.element("paywall.status"), value: "status.failed")

        let cancel = onboarding(store: "cancel")
        waitForPaywall(cancel)
        cancel.element("paywall.product.yearly").tap()
        XCTAssertTrue(cancel.element("paywall.product.yearly").waitForExistence(timeout: 5))
        XCTAssertFalse(cancel.element("paywall.status").exists)
    }

    // paywall-and-entitlement/buy-once-and-you-re-in
    func testPurchasesTurnedOffLeaveOnlyRestore() {
        let app = onboarding(store: "notAllowed")
        waitForPaywall(app)
        expect(app.element("paywall.status"), value: "status.notAllowed")
        XCTAssertFalse(app.element("paywall.product.lifetime").isEnabled)
        XCTAssertTrue(app.element("paywall.restore").isEnabled)
    }

    // paywall-and-entitlement/waiting-for-a-parent-s-approval
    func testAskToBuySaysItIsWaiting() {
        let app = onboarding(store: "pending")
        waitForPaywall(app)
        app.element("paywall.product.lifetime").tap()
        expect(app.element("paywall.status"), value: "status.pending")
        XCTAssertTrue(app.element("paywall.root").exists)
    }

    // paywall-and-entitlement/restore-your-purchase
    // paywall-and-entitlement/when-access-ends-the-app-locks-and-keeps-your-data
    func testRestoreAfterALapseBringsBackFavorites() {
        let app = launch(["-ui-testing-live", "favorites"], entitlement: "expired", store: "restoreShared")
        waitForPaywall(app)
        expect(app.element("paywall.title"), value: "title.lapsed")
        expect(app.element("paywall.lapsedNote"), value: "lapsed.expired")
        app.element("paywall.restore").tap()
        XCTAssertTrue(app.element("paywall.restored").waitForExistence(timeout: 5))
        expect(app.element("paywall.title"), value: "restored.title")
        XCTAssertTrue(app.element("paywall.restored.kind").exists)
        app.element("paywall.continue").tap()
        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 10), "the sources and favorites are back")
        XCTAssertFalse(app.element("paywall.root").exists)
    }

    // paywall-and-entitlement/restore-your-purchase
    func testRestoreFindsNothingOrAnEndedSubscription() {
        let app = onboarding()
        waitForPaywall(app)
        app.element("paywall.restore").tap()
        expect(app.element("paywall.status"), value: "status.nothingFound")

        let ended = onboarding(store: "restoreExpired")
        waitForPaywall(ended)
        ended.element("paywall.restore").tap()
        expect(ended.element("paywall.lapsedNote"), value: "lapsed.expired")
        XCTAssertTrue(ended.element("paywall.product.yearly").exists, "the products stay")
    }

    // paywall-and-entitlement/the-app-store-cannot-be-reached
    func testTryAgainReplacesThePanelWithTheProducts() {
        let app = onboarding(store: "retry")
        XCTAssertTrue(app.element("paywall.unavailable").waitForExistence(timeout: 10))
        XCTAssertTrue(app.element("paywall.restore").exists)
        app.element("paywall.retry").tap()
        expect(app.element("paywall.product.lifetime"), value: "$29.99")
        XCTAssertFalse(app.element("paywall.unavailable").exists)
    }

    // paywall-and-entitlement/the-app-store-cannot-be-reached
    func testNotSoldHereOffersNoTryAgain() {
        let app = onboarding(store: "notSold")
        XCTAssertTrue(app.element("paywall.unavailable").waitForExistence(timeout: 10))
        expect(app.element("paywall.unavailable.body"), value: "status.notInStorefront")
        XCTAssertFalse(app.element("paywall.retry").exists)
    }

    // paywall-and-entitlement/a-buyer-goes-straight-in
    func testAnUnlockedLaunchNeverShowsThePaywall() {
        let app = onboarding("yearly")
        XCTAssertTrue(app.element("onboarding.welcome").waitForExistence(timeout: 10))
        XCTAssertFalse(app.element("paywall.root").exists)
    }

    // paywall-and-entitlement/when-access-ends-the-app-locks-and-keeps-your-data
    func testAccessEndingLocksAtTheNextReturn() {
        let app = launch(["-ui-testing-live", "channels"], entitlement: "lapsing")
        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 10))
        XCTAssertFalse(app.element("paywall.root").exists, "never while the app is open")
        XCUIDevice.shared.press(.home)
        app.activate()
        waitForPaywall(app)
        expect(app.element("paywall.lapsedNote"), value: "lapsed.revoked")
        XCTAssertFalse(app.element("browse.list").exists)
    }
}
