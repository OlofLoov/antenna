import XCTest

/// The Subtitles On/Off switch in the Apple TV info panel and the subtitles
/// over the picture, over the shell's scripted `channels` scenario.
extension ShellUITests {
    // player-controls-and-playback-errors/turn-subtitles-on-or-off-in-one-step, turning subtitles off on Apple TV
    func testTheSwitchTurnsSubtitlesOnAndOffOnAppleTV() {
        launchSubtitles(environment: [:])
        openSubtitlesTab()
        let toggle = element("player.panel.subtitles")
        expect(toggle, "value == 'Off'")
        XCTAssertFalse(element("player.subtitles.cue").exists)

        press(.right)
        expectFocus("player.panel.subtitles")
        press(.select)

        expect(toggle, "value == 'On'")
        expect(element("player.panel.track.1"), "value == 'Selected'")
        expect(element("player.subtitles.cue"), "label == 'Subtitle subtitle-0'")
        XCTAssertTrue(element("player.panel").exists, "the panel stays open")

        press(.select)

        expect(toggle, "value == 'Off'")
        expect(element("player.panel.track.0"), "value == 'Selected'")
        expectGone("player.subtitles.cue")
    }

    // player-controls-and-playback-errors/turn-subtitles-on-or-off-in-one-step, no subtitles in the stream
    func testNoSubtitlesHidesTheSwitchOnAppleTV() {
        launchSubtitles(environment: ["UITESTING_TRACKS": "single"])
        openSubtitlesTab()
        XCTAssertFalse(element("player.panel.subtitles").exists)
    }
}
