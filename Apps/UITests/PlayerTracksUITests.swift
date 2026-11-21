import XCTest

/// The one audio-and-subtitles button and its menu on iPhone and iPad
/// (player-controls-and-playback-errors capability), on the scripted launch
/// of `LiveUITests`. Every scripted stream has three sound tracks and
/// English subtitles unless `UITESTING_TRACKS=single`. The menu's checks
/// come from the track list the scripted engine reports.
@MainActor
final class PlayerTracksUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Plays the first channel in portrait on iPhone or in landscape on
    /// iPad, and shows the controls.
    private func launchPlaying(tracks: String? = nil) -> XCUIApplication {
        XCUIDevice.shared.orientation = UIDevice.current.userInterfaceIdiom == .pad ? .landscapeLeft : .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"]
        if let tracks { app.launchEnvironment["UITESTING_TRACKS"] = tracks }
        app.launchInEnglish()
        XCTAssertTrue(app.row(0).waitForExistence(timeout: 10), "the channel list never appeared")
        app.row(0).tap()
        app.waitForEngine("playing loads=1")
        if !app.element("player.tracks").exists { app.element("browse.player.surface").tap() }
        XCTAssertTrue(app.element("player.tracks").waitForExistence(timeout: 3), "no tracks button")
        return app
    }

    // player-controls-and-playback-errors/one-button-for-audio-and-subtitles, one button in the controls
    // player-controls-and-playback-errors/one-button-for-audio-and-subtitles, what the menu shows
    func testOneButtonOpensAMenuWithSoundAndSubtitles() {
        let app = launchPlaying()
        let button = app.element("player.tracks")
        XCTAssertEqual(button.label, "Audio and Subtitles")
        XCTAssertEqual(button.value as? String, "Subtitles Off")
        XCTAssertFalse(app.element("player.subtitles").exists, "no second subtitles button")

        app.openTracksMenu()

        XCTAssertTrue(app.tracksMenu.staticTexts["Audio"].exists)
        XCTAssertTrue(app.tracksMenu.staticTexts["Subtitles"].exists)
        app.expectChecked("English")
        XCTAssertTrue(app.tracksRow("English (Commentary)").exists)
        XCTAssertTrue(app.tracksRow("Track 3").exists)
        app.expectChecked("Off")
        XCTAssertTrue(app.tracksRow("English", in: .subtitles).exists)
        let stream = app.tracksMenu.buttons.matching(NSPredicate(format: "label BEGINSWITH 'MPEG-TS · H.264 1080p · AAC 5.1'")).firstMatch
        XCTAssertTrue(stream.exists, "no stream line")
        XCTAssertFalse(stream.isEnabled, "the stream line does nothing")
    }

    // player-controls-and-playback-errors/choose-audio-and-subtitles, picking a track
    func testPickingASoundTrackSwitchesTheEngineAndClosesTheMenu() {
        let app = launchPlaying()
        app.openTracksMenu()

        app.pickTrack("English (Commentary)")

        app.openTracksMenu()
        app.expectChecked("English (Commentary)")
        XCTAssertFalse(app.tracksRow("English").isSelected)
    }

    // player-controls-and-playback-errors/one-button-for-audio-and-subtitles, turning subtitles off
    // player-controls-and-playback-errors/choose-audio-and-subtitles, subtitles
    func testPickingASubtitleTurnsItOnAndFillsTheButton() {
        let app = launchPlaying()
        let button = app.element("player.tracks")
        XCTAssertFalse(app.element("player.subtitles.cue").exists)
        app.openTracksMenu()

        app.pickTrack("English", in: .subtitles)

        app.expectTracks(button, "value == 'Subtitles On'", "the bubble is not filled")
        app.expectTracks(app.element("player.subtitles.cue"), "label == 'Subtitle subtitle-0'", "no subtitles")

        app.openTracksMenu()
        app.expectChecked("English", in: .subtitles)
        app.pickTrack("Off")

        app.expectTracks(button, "value == 'Subtitles Off'", "the bubble stays filled")
        app.expectTracks(app.element("player.subtitles.cue"), "exists == false", "the subtitles stay")
    }

    // player-controls-and-playback-errors/choose-audio-and-subtitles, grayed-out button
    func testOneSoundAndNoSubtitlesGraysTheButtonOut() {
        let app = launchPlaying(tracks: "single")
        XCTAssertFalse(app.element("player.tracks").isEnabled)
    }

    // player-controls-and-playback-errors/one-button-for-audio-and-subtitles
    // The controls hide three seconds after a tap, but not while the menu hangs from them.
    func testTheControlsStayWhileTheMenuIsOpen() {
        let app = launchPlaying()
        app.openTracksMenu()

        let stays = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.element("player.tracks"))
        XCTAssertEqual(XCTWaiter().wait(for: [stays], timeout: 6), .timedOut, "the controls hid behind the menu")
        XCTAssertTrue(app.tracksMenu.exists, "the menu closed on its own")
    }
}
