import XCTest

/// Subtitles on and off from the one audio-and-subtitles button on iPhone,
/// in the small player and in full screen, on the scripted launch of
/// `LiveUITests`. The device's language is fixed to English by
/// `launchInEnglish()`.
@MainActor
final class SubtitleSwitchUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launchPlaying(tracks: String? = nil, subtitles: String? = nil) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"]
        app.launchEnvironment["UITESTING_CONTROLS_SECONDS"] = "600"
        if let tracks { app.launchEnvironment["UITESTING_TRACKS"] = tracks }
        if let subtitles { app.launchEnvironment["UITESTING_SUBTITLES"] = subtitles }
        app.launchInEnglish()
        XCTAssertTrue(app.row(0).waitForExistence(timeout: 10), "the channel list never appeared")
        app.row(0).tap()
        app.waitForEngine("playing loads=1")
        return app
    }

    /// Turns the iPhone sideways, which fills the screen with the picture,
    /// and shows the controls.
    private func fullScreenTracksButton(_ app: XCUIApplication) -> XCUIElement {
        XCUIDevice.shared.orientation = .landscapeLeft
        app.expectTracks(app.element("browse.list"), "exists == false", "the picture did not fill the screen")
        let button = app.element("player.tracks")
        if !button.waitForExistence(timeout: 2) { app.element("browse.player.surface").tap() }
        XCTAssertTrue(button.waitForExistence(timeout: 3), "no tracks button in full screen")
        return button
    }

    // player-controls-and-playback-errors/turn-subtitles-on-or-off-in-one-step, the narrow player on iPhone
    func testTheNarrowPlayerHasOneTracksButton() throws {
        let app = try launchPlaying()
        app.element("browse.player.surface").tap()
        XCTAssertTrue(app.element("player.tracks").waitForExistence(timeout: 3), "no tracks button")
        XCTAssertFalse(app.element("player.subtitles").exists)
    }

    // player-controls-and-playback-errors/one-button-for-audio-and-subtitles, turning subtitles on in full screen on iphone
    // player-controls-and-playback-errors/turn-subtitles-on-or-off-in-one-step, turning subtitles on on iPhone in full screen
    func testTheMenuTurnsSubtitlesOnAndOffInFullScreen() throws {
        let app = try launchPlaying()
        let button = fullScreenTracksButton(app)
        XCTAssertEqual(button.label, "Audio and Subtitles")
        XCTAssertEqual(button.value as? String, "Subtitles Off")
        XCTAssertFalse(app.element("player.subtitles").exists, "no second subtitles button")
        XCTAssertFalse(app.element("player.subtitles.cue").exists)

        app.openTracksMenu()
        // Opened from the bottom edge, the menu keeps Audio above Subtitles.
        let audio = app.tracksMenu.staticTexts["Audio"].frame
        let subtitles = app.tracksMenu.staticTexts["Subtitles"].frame
        XCTAssertLessThan(audio.minY, subtitles.minY, "the sounds come first")
        XCTAssertLessThan(app.tracksRow("Off").frame.minY, app.tracksRow("English", in: .subtitles).frame.minY, "Off comes first")
        app.pickTrack("English", in: .subtitles)

        app.expectTracks(button, "value == 'Subtitles On'", "the bubble is not filled")
        app.expectTracks(app.element("player.subtitles.cue"), "label == 'Subtitle subtitle-0'", "no subtitles")

        app.openTracksMenu()
        app.pickTrack("Off")

        app.expectTracks(button, "value == 'Subtitles Off'", "the bubble stays filled")
        app.expectTracks(app.element("player.subtitles.cue"), "exists == false", "the subtitles stay")
    }

    // player-controls-and-playback-errors/one-button-for-audio-and-subtitles, only forced subtitles on
    func testForcedSubtitlesAloneReadAsOff() throws {
        let app = try launchPlaying(tracks: "foreign", subtitles: "off")
        let button = fullScreenTracksButton(app)
        XCTAssertEqual(app.element("player.subtitles.cue").label, "Subtitle subtitle-2", "forced English shows")
        XCTAssertEqual(button.value as? String, "Subtitles Off")

        app.openTracksMenu()
        app.expectChecked("English (Forced)")
        app.pickTrack("English", in: .subtitles)

        app.expectTracks(button, "value == 'Subtitles On'", "the bubble is not filled")
        app.expectTracks(app.element("player.subtitles.cue"), "label == 'Subtitle subtitle-1'", "no full subtitles")
    }
}
