import XCTest

/// The Subtitles preference and the subtitles a channel starts with on
/// iPhone, on the scripted launch of `LiveUITests`. The device's language is
/// fixed to English with `-AppleLanguages`.
@MainActor
final class SubtitlePreferenceUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(tracks: String? = nil, subtitles: String? = nil) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if let tracks { app.launchEnvironment["UITESTING_TRACKS"] = tracks }
        if let subtitles { app.launchEnvironment["UITESTING_SUBTITLES"] = subtitles }
        app.launch()
        return app
    }

    /// Plays the first channel and opens the audio and subtitle list.
    private func openTracks(_ app: XCUIApplication) {
        XCTAssertTrue(app.row(0).waitForExistence(timeout: 10), "the channel list never appeared")
        app.row(0).tap()
        app.waitForEngine("playing loads=1")
        app.element("browse.player.surface").tap()
        XCTAssertTrue(app.element("player.tracks").waitForExistence(timeout: 3), "no tracks button")
        app.element("player.tracks").tap()
        XCTAssertTrue(app.element("player.trackPicker").waitForExistence(timeout: 3), "no list")
    }

    private func expectSelected(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Selected'"), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [selected], timeout: 5), .completed, "\(element) is not selected", file: file, line: line)
    }

    // sources-and-settings/choose-when-subtitles-show
    // playback-engine/subtitles-start-by-the-subtitle-setting, Always
    func testSettingAlwaysStartsSubtitlesInTheUsersLanguage() throws {
        let app = try launch()
        let tab = app.tabBars.buttons["Settings"]
        let button = tab.waitForExistence(timeout: 10) ? tab : app.buttons["Settings"].firstMatch
        button.tap()
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

        app.tabBars.buttons["Live"].tap()
        openTracks(app)
        expectSelected(app.element("player.trackPicker.subtitles.0"))
    }

    // playback-engine/subtitles-start-by-the-subtitle-setting, Auto with sound the user understands
    func testAutoWithEnglishSoundStartsWithSubtitlesOff() throws {
        let app = try launch()
        openTracks(app)
        expectSelected(app.element("player.trackPicker.subtitles.off"))
    }

    // playback-engine/subtitles-start-by-the-subtitle-setting, Auto with sound in another language
    func testAutoWithGermanSoundStartsEnglishSubtitles() throws {
        let app = try launch(tracks: "foreign")
        openTracks(app)
        expectSelected(app.element("player.trackPicker.subtitles.1"))
        XCTAssertEqual(app.element("player.trackPicker.subtitles.2").label, "English (Forced)")
    }

    // playback-engine/forced-subtitles-in-your-language-show, forced subtitles with subtitles off
    func testOffStillShowsForcedSubtitles() throws {
        let app = try launch(tracks: "foreign", subtitles: "off")
        openTracks(app)
        expectSelected(app.element("player.trackPicker.subtitles.2"))
    }
}
