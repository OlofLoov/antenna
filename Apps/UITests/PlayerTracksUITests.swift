import XCTest

/// The audio-and-subtitles button and its list on iPhone
/// (player-controls-and-playback-errors capability), on the scripted launch
/// of `LiveUITests`. Every scripted stream has three sound tracks and
/// English subtitles unless `UITESTING_TRACKS=single`.
@MainActor
final class PlayerTracksUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launchPlaying(tracks: String? = nil) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"]
        if let tracks { app.launchEnvironment["UITESTING_TRACKS"] = tracks }
        app.launch()
        XCTAssertTrue(app.row(0).waitForExistence(timeout: 10), "the channel list never appeared")
        app.row(0).tap()
        app.waitForEngine("playing loads=1")
        app.element("browse.player.surface").tap()
        XCTAssertTrue(app.element("player.tracks").waitForExistence(timeout: 3), "no tracks button")
        return app
    }

    // player-controls-and-playback-errors/choose-audio-and-subtitles
    func testPickingASoundTrackTicksItAndKeepsTheListOpen() throws {
        let app = try launchPlaying()
        XCTAssertEqual(app.element("player.tracks").label, "Audio and subtitles")
        app.element("player.tracks").tap()
        XCTAssertTrue(app.element("player.trackPicker").waitForExistence(timeout: 3), "no list")
        XCTAssertEqual(app.element("player.trackPicker.audio.0").value as? String, "Selected")
        XCTAssertEqual(app.element("player.trackPicker.audio.1").label, "English (Commentary)")
        XCTAssertEqual(app.element("player.trackPicker.audio.2").label, "Track 3")
        XCTAssertTrue(app.element("player.trackPicker.stream").label.contains("MPEG-TS · H.264 1080p · AAC 5.1"))

        app.element("player.trackPicker.audio.1").tap()

        let picked = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == 'Selected'"), object: app.element("player.trackPicker.audio.1"))
        XCTAssertEqual(XCTWaiter().wait(for: [picked], timeout: 3), .completed)
        XCTAssertTrue(app.element("player.trackPicker").exists, "the list stays open")

        app.element("player.trackPicker.done").tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.element("player.trackPicker"))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 3), .completed, "Done closes the list")
    }

    // player-controls-and-playback-errors/choose-audio-and-subtitles, subtitles
    func testSubtitlesStartWithOff() throws {
        let app = try launchPlaying()
        app.element("player.tracks").tap()
        XCTAssertTrue(app.element("player.trackPicker").waitForExistence(timeout: 3))
        XCTAssertEqual(app.element("player.trackPicker.subtitles.off").value as? String, "Selected")

        app.element("player.trackPicker.subtitles.0").tap()

        let picked = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == 'Selected'"), object: app.element("player.trackPicker.subtitles.0"))
        XCTAssertEqual(XCTWaiter().wait(for: [picked], timeout: 3), .completed)
    }

    // player-controls-and-playback-errors/choose-audio-and-subtitles, grayed-out button
    func testOneSoundAndNoSubtitlesGraysTheButtonOut() throws {
        let app = try launchPlaying(tracks: "single")
        XCTAssertFalse(app.element("player.tracks").isEnabled)
    }
}
