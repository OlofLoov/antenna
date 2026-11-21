import XCTest

/// The Subtitles preference and the subtitles a channel starts with on
/// iPhone, on the scripted launch of `LiveUITests`. The device's language is
/// fixed to English by `launchInEnglish()`.
@MainActor
final class SubtitlePreferenceUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(tracks: String? = nil, subtitles: String? = nil) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"]
        if let tracks { app.launchEnvironment["UITESTING_TRACKS"] = tracks }
        if let subtitles { app.launchEnvironment["UITESTING_SUBTITLES"] = subtitles }
        app.launchInEnglish()
        return app
    }

    /// Plays the first channel and opens the audio-and-subtitles menu.
    private func openTracks(_ app: XCUIApplication) {
        XCTAssertTrue(app.row(0).waitForExistence(timeout: 10), "the channel list never appeared")
        app.row(0).tap()
        app.waitForEngine("playing loads=1")
        app.element("browse.player.surface").tap()
        XCTAssertTrue(app.element("player.tracks").waitForExistence(timeout: 3), "no tracks button")
        app.openTracksMenu()
    }

    // sources-and-settings/choose-when-subtitles-show
    // playback-engine/subtitles-start-by-the-subtitle-setting, Always
    func testSettingAlwaysStartsSubtitlesInTheUsersLanguage() throws {
        let app = try launch()
        app.openSettings(timeout: 10)
        let row = app.element("settings.subtitles")
        for _ in 0..<4 where !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 5), "no Subtitles row")
        XCTAssertTrue(app.element("settings.subtitles.footer").label.contains("not in one of your languages"))

        row.tap()
        let always = app.buttons["Always"].firstMatch
        XCTAssertTrue(always.waitForExistence(timeout: 5), "no Always choice")
        always.tap()
        let footer = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS 'whenever the stream has them'"),
            object: app.element("settings.subtitles.footer"))
        XCTAssertEqual(XCTWaiter().wait(for: [footer], timeout: 5), .completed, "the footer did not follow the choice")

        app.closeSettings()
        app.tabBars.buttons["Live"].tap()
        openTracks(app)
        app.expectChecked("English", in: .subtitles)
    }

    // playback-engine/subtitles-start-by-the-subtitle-setting, Auto with sound the user understands
    func testAutoWithEnglishSoundStartsWithSubtitlesOff() throws {
        let app = try launch()
        openTracks(app)
        app.expectChecked("Off")
    }

    // playback-engine/subtitles-start-by-the-subtitle-setting, Auto with sound in another language
    func testAutoWithGermanSoundStartsEnglishSubtitles() throws {
        let app = try launch(tracks: "foreign")
        openTracks(app)
        app.expectChecked("English", in: .subtitles)
        XCTAssertTrue(app.tracksRow("English (Forced)").exists)
    }

    // playback-engine/forced-subtitles-in-your-language-show, forced subtitles with subtitles off
    func testOffStillShowsForcedSubtitles() throws {
        let app = try launch(tracks: "foreign", subtitles: "off")
        openTracks(app)
        app.expectChecked("English (Forced)")
    }
}
