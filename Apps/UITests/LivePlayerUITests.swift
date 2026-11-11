import XCTest

/// The in-place player's controls and full screen on iPhone
/// (live-tv-on-iphone-ipad-mac capability), on the scripted launch of `LiveUITests`.
@MainActor
final class LivePlayerUITests: XCTestCase {
    nonisolated let log = FileManager.default.temporaryDirectory.appending(path: "live-engine-\(UUID().uuidString).log")

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        try? FileManager.default.removeItem(at: log)
    }

    /// Launches, plays News One and waits until it plays. A tap keeps the
    /// controls up for `controlsSeconds`, a minute unless a test says otherwise.
    private func launchPlaying(controlsSeconds: Int? = nil) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"]
        app.launchEnvironment["UITESTING_ENGINE_LOG"] = log.path
        if let controlsSeconds { app.launchEnvironment["UITESTING_CONTROLS_SECONDS"] = String(controlsSeconds) }
        app.launch()
        XCTAssertTrue(app.row(0).waitForExistence(timeout: 10), "the channel list never appeared")
        app.row(0).tap()
        app.waitForEngine("playing loads=1")
        return app
    }

    /// One of the controls, after tapping the picture if they timed out,
    /// which a slow runner can take longer than three seconds to notice.
    private func control(_ app: XCUIApplication, _ part: String) -> XCUIElement {
        let element = app.element("browse.player.\(part)")
        for _ in 0..<3 {
            if element.exists { return element }
            if !app.element("browse.player.controls").exists { app.element("browse.player.surface").tap() }
            if element.waitForExistence(timeout: 2) { return element }
        }
        XCTFail("no \(part)")
        return element
    }

    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    // live-tv-on-iphone-ipad-mac/player-controls-when-you-want-them
    func testTappingThePictureShowsTheControls() throws {
        let app = try launchPlaying()
        XCTAssertFalse(app.element("browse.player.controls").exists)

        app.element("browse.player.surface").tap()

        XCTAssertTrue(app.element("browse.player.controls").waitForExistence(timeout: 2))
        XCTAssertEqual(control(app, "playPause").label, "Pause")
        // Paused, the controls stay, so reading each part cannot race the
        // three-second timer on a slow runner.
        control(app, "playPause").tap()
        app.waitForEngine("paused loads=1")
        for part in ["playPause", "progress", "clock", "live", "fullscreen", "pip"] {
            XCTAssertTrue(app.element("browse.player.\(part)").exists, "no \(part)")
        }
        XCTAssertFalse(app.element("browse.player.pip").isEnabled, "the fake engine cannot do Picture in Picture")
    }

    // live-tv-on-iphone-ipad-mac/player-controls-when-you-want-them, controls go away
    func testTheControlsGoAwayAfterAFewSeconds() throws {
        let app = try launchPlaying(controlsSeconds: 3)
        app.element("browse.player.surface").tap()
        let controls = app.element("browse.player.controls")
        XCTAssertTrue(controls.waitForExistence(timeout: 2))

        XCTAssertTrue(waitUntilGone(controls, timeout: 10), "the controls stayed up")
    }

    // live-tv-on-iphone-ipad-mac/player-controls-when-you-want-them, paused
    func testPausedTheControlsStay() throws {
        let app = try launchPlaying()
        control(app, "playPause").tap()
        app.waitForEngine("paused loads=1")
        XCTAssertEqual(app.element("browse.player.playPause").label, "Play")

        XCTAssertFalse(waitUntilGone(app.element("browse.player.controls"), timeout: 5), "the controls went away while paused")

        app.element("browse.player.playPause").tap()
        app.waitForEngine("playing loads=1")
    }

    // live-tv-on-iphone-ipad-mac/full-screen
    func testTheFullScreenButtonFillsTheScreenAndComesBack() throws {
        let app = try launchPlaying()
        control(app, "fullscreen").tap()

        XCTAssertTrue(waitUntilGone(app.element("browse.list"), timeout: 3), "the list stayed on screen")
        XCTAssertFalse(app.tabBars.firstMatch.isHittable)
        let exit = control(app, "fullscreen")
        XCTAssertEqual(exit.label, "Exit full screen")

        exit.tap()

        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 3))
        app.waitForEngine("playing loads=1")
        XCTAssertEqual(try String(contentsOf: log, encoding: .utf8), "news-one.ts\n")
    }

    // live-tv-on-iphone-ipad-mac/full-screen, turning an iPhone sideways
    func testTurningThePhoneSidewaysFillsTheScreen() throws {
        let app = try launchPlaying()

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(waitUntilGone(app.element("browse.list"), timeout: 3), "the list stayed on screen")
        let player = app.element("browse.player").frame
        let window = app.windows.firstMatch.frame
        XCTAssertEqual(player.height, window.height, accuracy: 1, "the picture fills the screen's height")

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 3))
        app.waitForEngine("playing loads=1")
    }
}
