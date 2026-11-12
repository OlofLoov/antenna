import XCTest

/// The subtitles switch next to the audio-and-subtitles button and the
/// subtitles over the picture, on the scripted launch of `LiveUITests`. The
/// device's language is fixed to English with `-AppleLanguages`.
@MainActor
final class SubtitleSwitchUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launchPlaying(tracks: String? = nil, subtitles: String? = nil) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["UITESTING_CONTROLS_SECONDS"] = "600"
        if let tracks { app.launchEnvironment["UITESTING_TRACKS"] = tracks }
        if let subtitles { app.launchEnvironment["UITESTING_SUBTITLES"] = subtitles }
        app.launch()
        XCTAssertTrue(app.row(0).waitForExistence(timeout: 10), "the channel list never appeared")
        app.row(0).tap()
        app.waitForEngine("playing loads=1")
        return app
    }

    /// Turns the iPhone sideways, which fills the screen with the picture,
    /// and shows the controls.
    private func fullScreenSubtitlesButton(_ app: XCUIApplication) -> XCUIElement {
        XCUIDevice.shared.orientation = .landscapeLeft
        expect(app.element("browse.list"), "exists == false")
        let button = app.element("player.subtitles")
        if !button.waitForExistence(timeout: 2) { app.element("browse.player.surface").tap() }
        XCTAssertTrue(button.waitForExistence(timeout: 3), "no subtitles button in full screen")
        return button
    }

    private func expect(_ element: XCUIElement, _ predicate: String, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: 5)
        XCTAssertEqual(result, .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    // player-controls-and-playback-errors/turn-subtitles-on-or-off-in-one-step, the narrow player on iPhone
    func testTheNarrowPlayerHasNoSubtitlesButton() throws {
        let app = try launchPlaying()
        app.element("browse.player.surface").tap()
        XCTAssertTrue(app.element("player.tracks").waitForExistence(timeout: 3), "no tracks button")
        XCTAssertFalse(app.element("player.subtitles").exists)
    }

    // player-controls-and-playback-errors/turn-subtitles-on-or-off-in-one-step, turning subtitles on on iPhone in full screen
    func testOnePressTurnsSubtitlesOnAndOffInFullScreen() throws {
        let app = try launchPlaying()
        let button = fullScreenSubtitlesButton(app)
        XCTAssertEqual(button.label, "Subtitles")
        XCTAssertEqual(button.value as? String, "Off")
        XCTAssertFalse(app.element("player.subtitles.cue").exists)

        button.tap()

        expect(button, "value == 'On'")
        expect(app.element("player.subtitles.cue"), "exists == true")
        XCTAssertEqual(app.element("player.subtitles.cue").label, "Subtitle subtitle-0")
        XCTAssertFalse(app.element("player.trackPicker").exists, "no list opens")

        button.tap()

        expect(button, "value == 'Off'")
        expect(app.element("player.subtitles.cue"), "exists == false")
    }

    // player-controls-and-playback-errors/turn-subtitles-on-or-off-in-one-step, only forced subtitles on
    func testForcedSubtitlesAloneReadAsOff() throws {
        let app = try launchPlaying(tracks: "foreign", subtitles: "off")
        let button = fullScreenSubtitlesButton(app)
        XCTAssertEqual(app.element("player.subtitles.cue").label, "Subtitle subtitle-2", "forced English shows")
        XCTAssertEqual(button.value as? String, "Off")

        button.tap()

        expect(button, "value == 'On'")
        expect(app.element("player.subtitles.cue"), "label == 'Subtitle subtitle-1'")
    }

    // player-controls-and-playback-errors/turn-subtitles-on-or-off-in-one-step, no subtitles in the stream
    func testNoSubtitlesGraysTheButtonOut() throws {
        let app = try launchPlaying(tracks: "single")
        let button = fullScreenSubtitlesButton(app)
        XCTAssertFalse(button.isEnabled)
    }
}
