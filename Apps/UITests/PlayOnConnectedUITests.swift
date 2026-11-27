import XCTest

/// iPhone and iPad connected to an Apple TV (play-on-apple-tv capability),
/// against the scripted TV of `UITestingPlayOn`: it plays what it is sent,
/// pauses and plays on request, and stops at 1 h 12 min on a hand-off.
@MainActor
final class PlayOnConnectedUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(live: Bool = false, extra: [String] = [], environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments =
            (live ? ["-ui-testing-live", "channels"] : ["-ui-testing-shelf", "titles", "-ui-testing-reduce-motion"])
            + ["-ui-testing-play-on", "one"] + extra
        app.launchEnvironment = environment
        app.launchInEnglish()
        return app
    }

    private func openMovie(_ app: XCUIApplication) {
        let tab = app.tabBars.buttons["Movies"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        let info = app.element("movies.hero.info")
        XCTAssertTrue(info.waitForExistence(timeout: 10))
        info.tap()
        XCTAssertTrue(app.element("title.name").waitForExistence(timeout: 10))
    }

    private func expect(_ element: XCUIElement, _ predicate: String, file: StaticString = #filePath, line: UInt = #line) {
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [wait], timeout: 10), .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    /// Sends the film on the title page and waits for the bar.
    private func connectFromTitle(_ app: XCUIApplication) {
        openMovie(app)
        let button = app.element("title.playOn")
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
        XCTAssertTrue(app.element("playOn.bar").waitForExistence(timeout: 10), "no Playing on bar after the send")
    }

    // play-on-apple-tv/connected-to-a-tv
    // play-on-apple-tv/play-goes-to-the-tv-while-connected
    func testTheBarShowsAndPlayReadsPlayOnTheTV() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        let app = launch()
        connectFromTitle(app)
        expect(app.element("playOn.bar"), "label CONTAINS 'Playing on Living Room' AND label CONTAINS 'The Long Harbor'")
        expect(app.element("title.play"), "label CONTAINS 'on Living Room'")
        XCTAssertFalse(app.element("title.playOn").exists, "Play already sends, so Play on goes")
    }

    // play-on-apple-tv/connected-to-a-tv (VoiceOver)
    func testVoiceOverReadsTheBarAndItsAction() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        let app = launch()
        connectFromTitle(app)
        let bar = app.element("playOn.bar")
        expect(bar, "label BEGINSWITH 'Playing on Living Room'")
        XCTAssertTrue(bar.label.contains("The Long Harbor"), bar.label)
        XCTAssertEqual(app.buttons["playOn.bar.playPause"].label, "Pause")
    }

    // play-on-apple-tv/connected-to-a-tv
    func testPauseFromThePhone() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        let app = launch()
        connectFromTitle(app)
        let playPause = app.buttons["playOn.bar.playPause"]
        expect(playPause, "label == 'Pause'")
        playPause.tap()
        expect(playPause, "label == 'Play'")
        playPause.tap()
        expect(playPause, "label == 'Pause'")
    }

    // play-on-apple-tv/play-on-this-iphone
    func testHandTheFilmBackToThePhone() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        let app = launch()
        connectFromTitle(app)
        app.element("playOn.bar").tap()
        let playHere = app.buttons["playOn.sheet.playHere"]
        XCTAssertTrue(playHere.waitForExistence(timeout: 5))
        XCTAssertEqual(playHere.label, "Play on this iPhone")
        playHere.tap()
        XCTAssertTrue(app.element("title.transport").waitForExistence(timeout: 15), "the film plays on the iPhone")
        XCTAssertFalse(app.element("playOn.bar").exists, "the phone is no longer connected")
    }

    // play-on-apple-tv/the-connection-ends-cleanly
    func testDisconnectLeavesThePhoneFree() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        let app = launch()
        connectFromTitle(app)
        app.element("playOn.bar").tap()
        let disconnect = app.buttons["playOn.sheet.disconnect"]
        XCTAssertTrue(disconnect.waitForExistence(timeout: 5))
        disconnect.tap()
        expect(app.element("playOn.bar"), "exists == false")
        expect(app.element("title.play"), "NOT (label CONTAINS 'Living Room')")
    }

    // play-on-apple-tv/the-phone-opens-no-stream-while-connected
    func testLiveShowsTheConnectedPictureAndPlaysNothing() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        let log = FileManager.default.temporaryDirectory.appending(path: "playon-engine-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: log) }
        let app = launch(live: true, environment: ["UITESTING_ENGINE_LOG": log.path])
        XCTAssertTrue(app.row(1).waitForExistence(timeout: 10), "the channel list never appeared")
        app.row(1).press(forDuration: 1.2)
        let item = app.buttons["channel.menu.playOn"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.tap()
        XCTAssertTrue(app.element("playOn.live").waitForExistence(timeout: 10), "no connected picture")
        // Tapping another channel sends it to the TV and opens nothing here.
        app.row(2).tap()
        XCTAssertTrue(app.element("playOn.live").exists)
        let loads = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        XCTAssertTrue(loads.isEmpty, "the phone opened a stream: \(loads)")
    }

    // play-on-apple-tv/the-phone-opens-no-stream-while-connected
    func testMultiViewIsNotOfferedWhileConnectedOnIPad() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "multi-view needs an iPad")
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launch(live: true, environment: ["UITESTING_MULTIVIEW": "1"])
        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 10))
        // With a channel playing here, another row's menu offers multi-view.
        app.row(0).tap()
        app.waitForEngine("playing loads=1")
        app.row(1).press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["browse.menu.multiView"].firstMatch.waitForExistence(timeout: 5), "offered before connecting")
        let item = app.buttons["channel.menu.playOn"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.tap()
        XCTAssertTrue(app.element("playOn.live").waitForExistence(timeout: 10))
        app.row(2).press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["browse.menu.favorite"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["browse.menu.multiView"].exists)
    }
}
