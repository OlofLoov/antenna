import XCTest

/// The in-place player's controls and full screen on iPhone
/// (live-tv-on-iphone-ipad-mac capability), on the scripted launch of `LiveUITests`.
@MainActor
final class LivePlayerUITests: XCTestCase {
    nonisolated let log = FileManager.default.temporaryDirectory.appending(path: "live-engine-\(UUID().uuidString).log")
    nonisolated let lastChannel = FileManager.default.temporaryDirectory.appending(path: "live-last-\(UUID().uuidString).txt")

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        try? FileManager.default.removeItem(at: log)
        try? FileManager.default.removeItem(at: lastChannel)
    }

    /// Launches, plays News One and waits until it plays. A tap keeps the
    /// controls up for `controlsSeconds`, a minute unless a test says otherwise.
    private func launchPlaying(controlsSeconds: Int? = nil, orientation: UIDeviceOrientation = .portrait) throws -> XCUIApplication {
        let app = try launch(controlsSeconds: controlsSeconds, orientation: orientation)
        XCTAssertTrue(app.row(0).waitForExistence(timeout: 10), "the channel list never appeared")
        app.row(0).tap()
        app.waitForEngine("playing loads=1")
        return app
    }

    /// Launches on the channel list. `keep` reads the last session's
    /// channel, as after quitting.
    private func launch(
        controlsSeconds: Int? = nil, orientation: UIDeviceOrientation = .portrait, keep: Bool = false
    ) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        XCUIDevice.shared.orientation = orientation
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"] + (keep ? ["-ui-testing-keep-session"] : [])
        app.launchEnvironment["UITESTING_ENGINE_LOG"] = log.path
        app.launchEnvironment["UITESTING_LAST_CHANNEL_FILE"] = lastChannel.path
        if let controlsSeconds { app.launchEnvironment["UITESTING_CONTROLS_SECONDS"] = String(controlsSeconds) }
        app.launch()
        return app
    }

    /// The picture fills the screen: no list, no tab bar, no line under the picture.
    private func assertFullScreen(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waitUntilGone(app.element("browse.list"), timeout: 5), "the list stayed on screen", file: file, line: line)
        XCTAssertFalse(app.element("browse.nowPlaying").exists, "the line under the picture stayed", file: file, line: line)
        let tabBar = app.tabBars.firstMatch
        XCTAssertFalse(tabBar.exists && tabBar.isHittable, "the tab bar stayed on screen", file: file, line: line)
        let player = app.element("browse.player").frame
        let window = app.windows.firstMatch.frame
        XCTAssertEqual(player.height, window.height, accuracy: 1, "the picture fills the screen's height", file: file, line: line)
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
        assertFullScreen(app)

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.firstMatch.isHittable, "the tab bar did not come back")
        app.waitForEngine("playing loads=1")
    }

    // live-tv-on-iphone-ipad-mac/sideways-on-iphone-fills-the-screen, turn sideways then pick a channel
    // live-tv-on-iphone-ipad-mac/every-iphone-keeps-the-phone-layout, run on iPhone 17 and iPhone 17 Pro Max
    func testPickingAChannelWhileSidewaysFillsTheScreen() throws {
        let app = try launch(orientation: .landscapeLeft)
        XCTAssertTrue(app.row(0).waitForExistence(timeout: 10), "the phone layout's list never appeared sideways")
        XCTAssertFalse(app.element("browse.sidebar").exists, "a sideways iPhone got the iPad sidebar")

        app.row(0).tap()
        app.waitForEngine("playing loads=1")

        assertFullScreen(app)
    }

    // live-tv-on-iphone-ipad-mac/sideways-on-iphone-fills-the-screen, launch sideways
    func testLaunchingSidewaysWithTheLastChannelFillsTheScreen() throws {
        var app = try launchPlaying()
        let mirror = lastChannel
        let stored = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in (try? String(contentsOf: mirror, encoding: .utf8))?.hasSuffix("news-one") == true },
            object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [stored], timeout: 15), .completed, "News One never became the last channel")
        app.terminate()

        app = try launch(orientation: .landscapeLeft, keep: true)
        app.waitForEngine("playing loads=1")

        assertFullScreen(app)
    }

    // live-tv-on-iphone-ipad-mac/sideways-on-iphone-fills-the-screen, exit sideways and back to Live sideways
    func testExitingSidewaysShowsTheListUntilLiveOpensAgain() throws {
        let app = try launchPlaying()
        XCUIDevice.shared.orientation = .landscapeLeft
        assertFullScreen(app)

        control(app, "fullscreen").tap()
        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 3), "Exit full screen kept the picture")
        app.tabBars.buttons["Guide"].tap()
        app.tabBars.buttons["Live"].tap()

        assertFullScreen(app)
        app.waitForEngine("playing loads=1")
    }

    // live-tv-on-iphone-ipad-mac/the-full-screen-channel-line-fades-with-the-controls
    func testTheFullScreenChannelLineGoesWithTheControls() throws {
        let app = try launchPlaying(controlsSeconds: 3)
        XCUIDevice.shared.orientation = .landscapeLeft
        assertFullScreen(app)
        let title = app.element("browse.player.title")
        let controls = app.element("browse.player.controls")
        XCTAssertTrue(waitUntilGone(controls, timeout: 10), "the controls stayed up")
        XCTAssertFalse(title.exists, "the channel line stayed without the controls")

        app.element("browse.player.surface").tap()

        XCTAssertTrue(controls.waitForExistence(timeout: 2))
        XCTAssertTrue(title.exists, "the channel line did not come back with the controls")
        XCTAssertTrue(waitUntilGone(title, timeout: 10), "the channel line stayed after the controls went")
        XCTAssertFalse(controls.exists)
    }

    /// The streams the fake engine loaded, in order.
    private nonisolated static func loaded(_ log: URL) -> [String] {
        ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    private var loaded: [String] { Self.loaded(log) }

    private func waitForLoaded(_ expected: [String], file: StaticString = #filePath, line: UInt = #line) {
        let log = log
        let done = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in Self.loaded(log) == expected }, object: nil)
        XCTAssertEqual(
            XCTWaiter().wait(for: [done], timeout: 10), .completed, "loaded \(loaded), expected \(expected)", file: file, line: line)
    }

    // live-tv-on-iphone-ipad-mac/swipe-on-the-picture-to-change-channel
    func testSwipingOnTheFullScreenPictureChangesChannel() throws {
        let app = try launchPlaying()
        XCUIDevice.shared.orientation = .landscapeLeft
        assertFullScreen(app)
        let surface = app.element("browse.player.surface")

        surface.swipeUp()
        waitForLoaded(["news-one.ts", "news-two.ts"])
        assertFullScreen(app)

        surface.swipeDown()
        waitForLoaded(["news-one.ts", "news-two.ts", "news-one.ts"])
        app.waitForEngine("playing loads=3")
    }

    // live-tv-on-iphone-ipad-mac/go-back-to-the-previous-channel
    func testPreviousChannelFlipsBetweenTwoChannels() throws {
        let app = try launchPlaying()
        XCTAssertFalse(control(app, "previous").isEnabled, "nothing to go back to yet")
        app.row(1).tap()
        waitForLoaded(["news-one.ts", "news-two.ts"])

        control(app, "previous").tap()
        waitForLoaded(["news-one.ts", "news-two.ts", "news-one.ts"])
        control(app, "previous").tap()
        waitForLoaded(["news-one.ts", "news-two.ts", "news-one.ts", "news-two.ts"])
    }

    // live-tv-on-iphone-ipad-mac/double-tap-to-skip, nothing to skip
    func testDoubleTappingAChannelThatCannotRewindSaysSo() throws {
        let app = try launchPlaying()
        app.element("browse.player.surface").coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.3)).doubleTap()

        let notice = app.element("timeshift.notice")
        XCTAssertTrue(notice.waitForExistence(timeout: 3), "no note for a channel that cannot rewind")
        XCTAssertEqual(notice.label, "Rewind isn't available on this channel")
        XCTAssertEqual(loaded, ["news-one.ts"])
    }
}
