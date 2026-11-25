import XCTest

/// The Audio and Subtitles button on the Apple TV movie player's bar
/// (player-controls-and-playback-errors/audio-and-subtitles-from-the-bar-on-apple-tv).
/// The shelf's UI testing script holds the bar for 60 seconds, so these
/// tests never wait for it to hide.
extension ShelfTVUITests {
    // player-controls-and-playback-errors/audio-and-subtitles-from-the-bar-on-apple-tv
    // player-controls-and-playback-errors/choose-audio-and-subtitles-in-a-movie-or-episode, on Apple TV
    func testSwipingDownReachesAudioAndSubtitlesThatOpensOnSubtitles() {
        openMovies()
        press(.select)
        expect(element("shelf.debug.engine"), "value == 'playing 1.mp4 from 0'")
        XCTAssertTrue(element("title.transport.tracks").waitForExistence(timeout: 5), "the bar has no Audio and Subtitles button")
        // The button never takes focus on its own as the bar shows.
        Thread.sleep(forTimeInterval: 1)
        XCTAssertFalse(element("title.transport.tracks").hasFocus, "the bar's button took focus without a press")

        press(.down)
        expectFocus("title.transport.tracks")
        XCTAssertEqual(element("title.transport.tracks").label, "Audio and Subtitles")

        press(.select)
        XCTAssertTrue(element("player.panel").waitForExistence(timeout: 5), "the button opened no panel")
        expectFocus("player.panel.segment.subtitles")
        XCTAssertTrue(element("player.panel.segment.subtitles").isSelected, "the panel opened on another tab")
        expect(element("shelf.debug.engine"), "value == 'playing 1.mp4 from 0'")

        press(.menu)
        expect(element("player.panel"), "exists == false")
        press(.menu)
        expect(element("movies.player"), "exists == false")
    }

    // player-controls-and-playback-errors/audio-and-subtitles-from-the-bar-on-apple-tv, Back from the button
    func testBackFromTheTracksButtonKeepsTheMovie() {
        openMovies()
        press(.select)
        expect(element("shelf.debug.engine"), "value == 'playing 1.mp4 from 0'")
        XCTAssertTrue(element("title.transport.tracks").waitForExistence(timeout: 5))

        press(.down)
        expectFocus("title.transport.tracks")
        press(.menu)
        expect(element("title.transport.tracks"), "hasFocus == false")
        XCTAssertTrue(element("movies.player").exists, "Back on the button keeps the movie")

        press(.down)
        expectFocus("title.transport.tracks")
        press(.up)
        expect(element("title.transport.tracks"), "hasFocus == false")
        press(.right)
        expect(element("shelf.debug.position"), "value == 'at 10'")
        press(.menu)
        expect(element("movies.player"), "exists == false")
    }

    // up-next/up-next-on-the-siri-remote, past the button to audio and subtitles
    func testDownPastNextEpisodeReachesAudioAndSubtitles() {
        openSeriesNearTheEnd()
        press(.select)
        expect(element("shelf.debug.engine"), "value BEGINSWITH 'playing '")
        XCTAssertTrue(element("upNext.button").waitForExistence(timeout: 5))

        press(.down)
        expectFocus("upNext.button")
        press(.down)
        expectFocus("title.transport.tracks")
        press(.up)
        expectFocus("upNext.button")
    }
}
