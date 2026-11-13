import XCTest

/// The Apple TV welcome screen for a user with no source.
@MainActor
final class OnboardingTVUITests: XCTestCase {
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

    /// The element with focus whose label contains `label`. A row in a
    /// `Form` reports focus on its cell, so the label finds it where its
    /// identifier cannot.
    private func focused(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true AND label CONTAINS %@", label)).firstMatch
    }

    /// Presses `button` until the element whose label contains `label` has focus.
    private func press(
        _ button: XCUIRemote.Button, untilFocused label: String, in app: XCUIApplication, limit: Int = 10, file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for _ in 0..<limit where !focused(app, label).waitForExistence(timeout: 1) {
            XCUIRemote.shared.press(button)
        }
        XCTAssertTrue(focused(app, label).exists, "\(label) never took focus", file: file, line: line)
    }

    // first-run-onboarding/a-new-user-is-asked-for-a-provider
    func testNoSourceOpensOnTheWelcomeScreenWithAddASourceFocused() {
        let app = launch("signedIn")
        XCTAssertTrue(element(app, "onboarding.welcome").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "onboarding.iCloudNote").exists)
        XCTAssertTrue(element(app, "onboarding.addSource").hasFocus)
        XCTAssertFalse(element(app, "shell.player").exists, "the shell shows behind onboarding")
    }

    // first-run-onboarding/a-new-user-is-asked-for-a-provider
    func testNotSignedInToICloudHidesTheSyncLine() {
        let app = launch("signedOut")
        XCTAssertTrue(element(app, "onboarding.welcome").waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "onboarding.iCloudNote").exists)
    }

    // first-run-onboarding/a-new-user-is-asked-for-a-provider
    func testWhatIsASourceOpensAndDoneCloses() {
        let app = launch("signedIn")
        XCTAssertTrue(element(app, "onboarding.addSource").waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.down)
        XCTAssertTrue(element(app, "onboarding.help").hasFocus)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.helpSheet").waitForExistence(timeout: 5))
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.helpSheet").waitForNonExistence(timeout: 5))
        XCTAssertTrue(element(app, "onboarding.welcome").exists)
    }

    // first-run-onboarding/a-new-user-is-asked-for-a-provider: Menu sends the app to the background.
    func testMenuOnTheWelcomeScreenLeavesTheApp() {
        let app = launch("signedIn")
        XCTAssertTrue(element(app, "onboarding.welcome").waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10) || app.state == .runningBackgroundSuspended)
    }

    // first-run-onboarding/mistakes-in-the-form-are-caught-before-connecting
    func testPickXtreamAndConnectWithEmptyFields() {
        let app = launch("signedIn")
        XCTAssertTrue(element(app, "onboarding.addSource").waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.kind.m3u").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "onboarding.kind.stalker").exists)
        XCUIRemote.shared.press(.right)
        XCTAssertTrue(element(app, "onboarding.kind.xtream").hasFocus)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.field.server").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "onboarding.connect").exists)
        while !element(app, "onboarding.connect").hasFocus {
            XCUIRemote.shared.press(.down)
        }
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.error").waitForExistence(timeout: 5))
        XCTAssertEqual(element(app, "onboarding.error").label, "Enter the server address.")
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(element(app, "onboarding.kind.xtream").waitForExistence(timeout: 5))
    }

    // design-system/forms-use-the-platform-form-style
    // design-system/modals-are-system-presentations
    func testTypeGoesBackToTheKindsAndCancelToTheWelcome() {
        let app = launch("signedIn")
        XCTAssertTrue(element(app, "onboarding.addSource").waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.kind.m3u").waitForExistence(timeout: 5))
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.field.playlist").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "onboarding.kind").label.contains("M3U playlist"))
        press(.up, untilFocused: "Type", in: app)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.field.playlist").waitForNonExistence(timeout: 5))
        XCTAssertTrue(element(app, "onboarding.kind.m3u").hasFocus)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.connect").waitForExistence(timeout: 5))
        press(.down, untilFocused: "Connect", in: app)
        XCUIRemote.shared.press(.right)
        XCTAssertTrue(element(app, "onboarding.back").hasFocus)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.welcome").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "onboarding.addSource").hasFocus)
    }

    // design-system/modals-are-system-presentations
    // design-system/pages-cover-what-is-behind-them
    // design-system/apple-tv-content-stays-in-the-safe-area
    func testAddASourceFromSettingsOpensTheKindsThenTheFormInOneCover() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels"]
        app.launch()
        let picture = element(app, "shell.picture")
        XCTAssertTrue(picture.waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "zapBar.bar").waitForNonExistence(timeout: 15))
        XCUIRemote.shared.press(.menu)
        let settings = element(app, "shell.settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        for _ in 0..<8 where !settings.hasFocus {
            XCUIRemote.shared.press(.right)
        }
        XCUIRemote.shared.press(.select)
        press(.down, untilFocused: "Add a source", in: app)
        XCUIRemote.shared.press(.select)

        let m3u = element(app, "onboarding.kind.m3u")
        XCTAssertTrue(m3u.waitForExistence(timeout: 5))
        XCTAssertTrue(m3u.hasFocus)
        XCTAssertGreaterThanOrEqual(m3u.frame.minX, 80, "the first kind starts inside the safe area")
        XCTAssertTrue(element(app, "onboarding.back").exists, "no Cancel on the kinds")
        let behind = element(app, "settings.addSource")
        XCTAssertFalse(behind.exists && behind.isHittable, "Settings is still reachable behind the cover")

        XCUIRemote.shared.press(.right)
        XCTAssertTrue(element(app, "onboarding.kind.xtream").hasFocus)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.field.server").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "onboarding.kind").label.contains("Xtream login"))
        XCTAssertTrue(element(app, "onboarding.back").exists, "no Cancel on the form")

        // Menu goes back a page, then closes the cover onto Add a source.
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(element(app, "onboarding.field.server").waitForNonExistence(timeout: 5))
        XCTAssertTrue(element(app, "onboarding.kind.xtream").waitForExistence(timeout: 5))
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(element(app, "onboarding.kind.xtream").waitForNonExistence(timeout: 5))
        XCTAssertTrue(focused(app, "Add a source").waitForExistence(timeout: 5), "focus did not return to Add a source")
    }

    // first-run-onboarding/add-a-stalker-portal
    func testPickAStalkerPortal() {
        let app = launch("signedIn")
        XCTAssertTrue(element(app, "onboarding.addSource").waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.kind.m3u").waitForExistence(timeout: 5))
        while !element(app, "onboarding.kind.stalker").hasFocus {
            XCUIRemote.shared.press(.right)
        }
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.field.portal").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "onboarding.field.mac").exists)
        XCTAssertFalse(element(app, "onboarding.field.server").exists)
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(element(app, "onboarding.kind.stalker").waitForExistence(timeout: 5))
    }

    // first-run-onboarding/add-a-jellyfin-server
    func testPickAJellyfinServer() {
        let app = launch("signedIn")
        XCTAssertTrue(element(app, "onboarding.addSource").waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.kind.m3u").waitForExistence(timeout: 5))
        while !element(app, "onboarding.kind.jellyfin").hasFocus {
            XCUIRemote.shared.press(.right)
        }
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.field.server").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "onboarding.field.username").exists)
        XCTAssertFalse(element(app, "onboarding.field.mac").exists)
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(element(app, "onboarding.kind.jellyfin").waitForExistence(timeout: 5))
    }

    // first-run-onboarding/a-summary-when-everything-has-loaded
    // first-run-onboarding/start-watching-without-waiting-for-the-guide
    func testConnectShowsTheSummaryAndStartWatchingOpensLive() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-onboarding", "connect", "-ui-testing-playlist", "http://onboarding.test/tv.m3u"]
        app.launch()
        XCTAssertTrue(element(app, "onboarding.addSource").waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.kind.m3u").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "onboarding.kind.m3u").hasFocus)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.connect").waitForExistence(timeout: 5))
        while !element(app, "onboarding.connect").hasFocus {
            XCUIRemote.shared.press(.down)
        }
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.summary").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "onboarding.tile.channels").exists)
        XCTAssertFalse(element(app, "onboarding.tile.guide").exists, "a playlist without a guide has no guide tile")
        XCTAssertTrue(element(app, "onboarding.liveCaption").exists)
        XCTAssertTrue(element(app, "onboarding.primary").hasFocus)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(element(app, "onboarding.summary").waitForNonExistence(timeout: 10))
        XCTAssertTrue(element(app, "shell.player").waitForExistence(timeout: 10))
    }
}
