import XCTest

/// The info panel over the playing picture on Apple TV
/// (player-controls-and-playback-errors capability), on
/// `-ui-testing-shell channels`. Every scripted stream has three sound
/// tracks and English subtitles unless `UITESTING_TRACKS=single`.
@MainActor
final class PlayerPanelTVUITests: XCTestCase {
    let remote = XCUIRemote.shared
    var app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
    }

    func launchPlaying(tracks: String? = nil) {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels"]
        if let tracks { app.launchEnvironment["UITESTING_TRACKS"] = tracks }
        app.launch()
        expectEngine("playing loads=1 file=a1.ts")
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    func expect(
        _ element: XCUIElement, _ predicate: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    func expectEngine(_ summary: String, file: StaticString = #filePath, line: UInt = #line) {
        expect(element("shell.debug.engine"), "value == '\(summary)'", timeout: 15, file: file, line: line)
    }

    func openPanel() {
        remote.press(.select, forDuration: 1)
        XCTAssertTrue(element("player.panel").waitForExistence(timeout: 5), "holding select opened no panel")
        expect(element("player.panel.segment.info"), "hasFocus == true")
    }

    // player-controls-and-playback-errors/see-what-s-on-without-stopping-the-picture-on-apple-tv
    func testHoldingSelectOpensThePanelOverThePlayingPicture() {
        launchPlaying()

        openPanel()

        XCTAssertTrue(element("player.panel.channel").label.contains("Channel a1"))
        XCTAssertTrue(element("player.panel.channel").label.contains("Home playlist"), "the panel names the source")
        XCTAssertEqual(element("player.panel.title").label, "Morning News")
        XCTAssertTrue(element("player.panel.times").label.hasSuffix("min left"))
        XCTAssertTrue(element("player.panel.progress").exists)
        XCTAssertEqual(element("player.panel.summary").label, "Headlines and weather.")
        XCTAssertEqual(element("player.panel.stream").label, "MPEG-TS · H.264 1080p · AAC 5.1 · Antenna player")
        XCTAssertFalse(element("overlay.root").exists, "holding select is not a press")
        expectEngine("playing loads=1 file=a1.ts")
    }

    // player-controls-and-playback-errors/see-what-s-on-without-stopping-the-picture-on-apple-tv, inside the panel
    func testSwipesStayInsidePlayPauseDoesNothingAndMenuCloses() {
        launchPlaying()
        openPanel()

        remote.press(.right)
        expect(element("player.panel.segment.audio"), "hasFocus == true")
        remote.press(.down)
        remote.press(.up)
        remote.press(.down)
        remote.press(.playPause)
        expectEngine("playing loads=1 file=a1.ts")
        XCTAssertTrue(element("player.panel").exists)

        remote.press(.menu)

        expect(element("player.panel"), "exists == false")
        expectEngine("playing loads=1 file=a1.ts")
        XCTAssertFalse(element("shell.tab.live").exists, "Menu only closed the panel")
    }

    // player-controls-and-playback-errors/choose-audio-and-subtitles
    func testPickingASoundTrackTicksItAndKeepsTheListOpen() {
        launchPlaying()
        openPanel()
        remote.press(.right)
        expect(element("player.panel.segment.audio"), "hasFocus == true")
        XCTAssertEqual(element("player.panel.track.0").value as? String, "Selected")
        XCTAssertEqual(element("player.panel.track.1").label, "English (Commentary)")
        XCTAssertEqual(element("player.panel.track.2").label, "Track 3")

        remote.press(.down)
        expect(element("player.panel.track.0"), "hasFocus == true")
        remote.press(.down)
        expect(element("player.panel.track.1"), "hasFocus == true")
        remote.press(.select)

        expect(element("player.panel.track.1"), "value == 'Selected'")
        XCTAssertTrue(element("player.panel").exists, "the list stays open")
    }

    // player-controls-and-playback-errors/choose-audio-and-subtitles, subtitles
    func testSubtitlesStartWithOffOrSayThereAreNone() {
        launchPlaying()
        openPanel()
        remote.press(.right)
        remote.press(.right)
        expect(element("player.panel.segment.subtitles"), "hasFocus == true")
        XCTAssertEqual(element("player.panel.track.0").label, "Off")
        XCTAssertEqual(element("player.panel.track.1").label, "English")

        app.terminate()
        launchPlaying(tracks: "single")
        openPanel()
        remote.press(.right)
        remote.press(.right)
        expect(element("player.panel.segment.subtitles"), "hasFocus == true")
        XCTAssertEqual(element("player.panel.empty").label, "No subtitles in this stream")
    }
}
