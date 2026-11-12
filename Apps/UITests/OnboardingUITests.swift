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

    // first-run-onboarding/a-new-user-is-asked-for-a-provider, after a lapse
    // design-system/nothing-shows-before-the-paywall
    func testALapsedPurchaseShowsThePaywallInPlaceOfOnboarding() {
        let app = launch("signedIn", ["-antenna.entitlement", "expired"])
        XCTAssertTrue(element(app, "paywall.root").waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "onboarding.welcome").exists, "onboarding shows behind the paywall")
        element(app, "paywall.product.lifetime").tap()
        XCTAssertTrue(element(app, "onboarding.welcome").waitForExistence(timeout: 10))
    }

    // first-run-onboarding/a-returning-user-goes-straight-to-their-channels, after a lapse
    func testALapsedPurchaseKeepsTheSavedProvider() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels", "-antenna.entitlement", "revoked", "-antenna.store", "restoreShared"]
        app.launch()
        XCTAssertTrue(element(app, "paywall.root").waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "onboarding.welcome").exists)
        element(app, "paywall.restore").tap()
        XCTAssertTrue(element(app, "paywall.continue").waitForExistence(timeout: 5))
        element(app, "paywall.continue").tap()
        XCTAssertTrue(app.tabBars.buttons["Live"].waitForExistence(timeout: 10), "the saved provider opens the app")
        XCTAssertFalse(element(app, "onboarding.welcome").exists)
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

    // first-run-onboarding/add-a-stalker-portal
    // first-run-onboarding/mistakes-in-the-form-are-caught-before-connecting
    func testPickAStalkerPortalAndConnectWithoutAMAC() {
        let app = launch("signedIn")
        XCTAssertTrue(element(app, "onboarding.addSource").waitForExistence(timeout: 10))
        element(app, "onboarding.addSource").tap()
        XCTAssertTrue(element(app, "onboarding.kind.stalker").waitForExistence(timeout: 5))
        element(app, "onboarding.kind.stalker").tap()
        XCTAssertTrue(element(app, "onboarding.field.portal").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "onboarding.field.mac").exists)
        XCTAssertTrue(element(app, "onboarding.field.username").exists)
        XCTAssertFalse(element(app, "onboarding.field.server").exists)
        element(app, "onboarding.field.portal").tap()
        element(app, "onboarding.field.portal").typeText("http://portal.example.test/c/")
        element(app, "onboarding.connect").tap()
        XCTAssertTrue(element(app, "onboarding.error").waitForExistence(timeout: 5))
        XCTAssertEqual(element(app, "onboarding.error").label, "Enter the MAC address.")
    }

    // first-run-onboarding/add-a-jellyfin-server
    func testPickAJellyfinServerAndConnectWithoutAUsername() {
        let app = launch("signedIn")
        XCTAssertTrue(element(app, "onboarding.addSource").waitForExistence(timeout: 10))
        element(app, "onboarding.addSource").tap()
        XCTAssertTrue(element(app, "onboarding.kind.jellyfin").waitForExistence(timeout: 5))
        element(app, "onboarding.kind.jellyfin").tap()
        XCTAssertTrue(element(app, "onboarding.field.server").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "onboarding.field.username").exists)
        XCTAssertFalse(element(app, "onboarding.field.mac").exists)
        element(app, "onboarding.field.server").tap()
        element(app, "onboarding.field.server").typeText("http://jellyfin.example.test:8096")
        element(app, "onboarding.connect").tap()
        XCTAssertTrue(element(app, "onboarding.error").waitForExistence(timeout: 5))
        XCTAssertEqual(element(app, "onboarding.error").label, "Enter the username.")
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

    private func connect(_ app: XCUIApplication, playlist: String) {
        XCTAssertTrue(element(app, "onboarding.addSource").waitForExistence(timeout: 10))
        element(app, "onboarding.addSource").tap()
        XCTAssertTrue(element(app, "onboarding.kind.m3u").waitForExistence(timeout: 5))
        element(app, "onboarding.kind.m3u").tap()
        let field = element(app, "onboarding.field.playlist")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(playlist)
        element(app, "onboarding.connect").tap()
    }

    // first-run-onboarding/start-watching-without-waiting-for-the-guide
    func testStartWatchingClosesOnboardingAndPlaysTheFirstChannel() throws {
        let log = FileManager.default.temporaryDirectory.appending(path: "onboarding-\(UUID().uuidString).log")
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-onboarding", "connect"]
        app.launchEnvironment["UITESTING_ENGINE_LOG"] = log.path
        app.launch()
        connect(app, playlist: "http://onboarding.test/tv.m3u")
        XCTAssertTrue(element(app, "onboarding.checklist").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "onboarding.line.channels").waitForExistence(timeout: 10))
        let start = app.buttons["onboarding.primary"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "onboarding.addAnother").exists)
        start.tap()
        XCTAssertTrue(element(app, "onboarding.checklist").waitForNonExistence(timeout: 10), "onboarding stayed open")
        XCTAssertTrue(element(app, "browse.debug.engine").waitForExistence(timeout: 10))
        let played = { ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init) }
        let deadline = Date.now.addingTimeInterval(10)
        while played().isEmpty, Date.now < deadline { _ = element(app, "browse.debug.engine").waitForExistence(timeout: 0.5) }
        XCTAssertEqual(played().first, "news-one.ts")
    }

    // first-run-onboarding/a-provider-with-no-live-channels
    func testNothingToWatchGoesBackToTheForm() {
        let app = launch("connect")
        connect(app, playlist: "http://empty.test/tv.m3u")
        XCTAssertTrue(element(app, "onboarding.headline").waitForExistence(timeout: 10))
        XCTAssertEqual(element(app, "onboarding.headline").label, "Nothing to watch yet")
        XCTAssertFalse(app.buttons["onboarding.primary"].isEnabled)
        XCTAssertFalse(element(app, "onboarding.addAnother").exists)
        element(app, "onboarding.back").tap()
        XCTAssertTrue(element(app, "onboarding.field.playlist").waitForExistence(timeout: 5))
        XCTAssertEqual(element(app, "onboarding.field.playlist").value as? String, "http://empty.test/tv.m3u")
    }
}
