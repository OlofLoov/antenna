import XCTest

/// Playing from Movies and Series on iPhone (movies-and-series-browsing
/// capability), on the `watching` script of `UITestingShelf`. The scripted
/// player's probe, `shelf.debug.engine`, reads `"<state> <file> from <seconds>"`.
@MainActor
final class ShelfPlayerUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func launch() throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", "watching", "-ui-testing-reduce-motion"]
        app.launch()
        return app
    }

    func open(_ app: XCUIApplication, _ kind: String) {
        let tab = app.tabBars.buttons["Movies"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        if kind == "series" {
            app.element("movies.kind.series").tap()
        }
        XCTAssertTrue(app.element("\(kind).hero").waitForExistence(timeout: 10))
    }

    func card(_ app: XCUIApplication, _ prefix: String, in row: String, _ id: String) -> XCUIElement {
        app.element("\(prefix).row.\(row)").descendants(matching: .any)["\(prefix).card.\(id)"].firstMatch
    }

    func expectPlayer(_ app: XCUIApplication, _ summary: String, file: StaticString = #filePath, line: UInt = #line) {
        let probe = app.element("shelf.debug.engine")
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", summary), object: probe)
        let result = XCTWaiter().wait(for: [wait], timeout: 5)
        XCTAssertEqual(
            result, .completed, "the player read \(probe.exists ? probe.value as? String ?? "" : "nothing")", file: file, line: line)
    }

    // movies-and-series-browsing/resume-where-you-left-off
    func testAMovieResumesAndClosingReturnsToItsPoster() throws {
        let app = try launch()
        open(app, "movies")
        let poster = card(app, "movies", in: "continueWatching", "xtream#cabin#vod#2")
        XCTAssertTrue(poster.waitForExistence(timeout: 5))
        poster.tap()
        XCTAssertTrue(app.element("movies.player").waitForExistence(timeout: 5))
        expectPlayer(app, "playing 2.mp4 from 2160")

        app.element("movies.player.close").tap()
        XCTAssertFalse(app.element("movies.player").waitForExistence(timeout: 2))
        XCTAssertTrue(poster.isHittable, "back at the poster that started it")
    }

    // movies-and-series-browsing/resume-where-you-left-off, barely started or finished
    func testAFinishedMovieStartsFromTheBeginning() throws {
        let app = try launch()
        open(app, "movies")
        app.swipeUp()
        let poster = card(app, "movies", in: "action", "xtream#cabin#vod#3")
        XCTAssertTrue(poster.waitForExistence(timeout: 5))
        poster.tap()
        expectPlayer(app, "playing 3.mp4 from 0")
    }

    // movies-and-series-browsing/play-a-series-from-the-next-episode
    // title-detail-and-episode-picker/open-a-series-page, Continue watching plays straight away
    func testASeriesStartsItsFirstUnfinishedEpisode() throws {
        let app = try launch()
        open(app, "series")
        card(app, "series", in: "continueWatching", "xtream#cabin#series#1").tap()
        expectPlayer(app, "playing 12.mp4 from 0")
        app.element("series.player.close").tap()

        card(app, "series", in: "continueWatching", "xtream#cabin#series#2").tap()
        expectPlayer(app, "playing 21.mp4 from 810")
    }

    // movies-and-series-browsing/play-a-series-from-the-next-episode, no episodes or a failed list
    // title-detail-and-episode-picker/play-starts-the-right-episode, no episodes
    // title-detail-and-episode-picker/when-details-or-episodes-do-not-load
    func testNoEpisodesAndAFailedListSaySoOnThePage() throws {
        let app = try launch()
        open(app, "series")
        let small = app.element("series.card.xtream#cabin#series#3")
        for _ in 0..<3 where !small.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(small.isHittable)
        small.tap()
        let play = app.element("title.play")
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        XCTAssertTrue(app.element("episodes.empty").waitForExistence(timeout: 5))
        XCTAssertEqual(app.element("episodes.empty").label, "No episodes available")
        XCTAssertFalse(play.isEnabled, "nothing to play")
        app.element("title.back").tap()

        let office = app.element("series.card.xtream#office#series#1")
        XCTAssertTrue(office.waitForExistence(timeout: 5))
        office.tap()
        let error = app.element("episodes.error")
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertEqual(error.label, "Could not load episodes")
        app.element("episodes.retry").tap()
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: play)
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: 5), .completed)
        play.tap()
        expectPlayer(app, "playing 11.mp4 from 0")
    }

    // movies-and-series-browsing/resume-where-you-left-off, leaving a movie restarts the last channel in Live
    func testLiveStartsAgainAfterAMovie() throws {
        let app = try launch()
        app.element("browse.row.00000000-0000-0000-0000-0000000000E1.0").tap()
        app.waitForEngine("playing loads=1")
        open(app, "movies")
        card(app, "movies", in: "continueWatching", "xtream#cabin#vod#2").tap()
        expectPlayer(app, "playing 2.mp4 from 2160")
        app.element("movies.player.close").tap()
        app.tabBars.buttons["Live"].tap()
        app.waitForEngine("playing loads=2")
    }

    func expectPlace(_ app: XCUIApplication, _ place: String, file: StaticString = #filePath, line: UInt = #line) {
        let probe = app.element("shelf.debug.position")
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", place), object: probe)
        XCTAssertEqual(
            XCTWaiter().wait(for: [wait], timeout: 5), .completed, "the title is \(probe.value as? String ?? "nowhere")", file: file,
            line: line)
    }

    // player-controls-and-playback-errors/move-around-in-a-movie-or-episode
    // player-controls-and-playback-errors/the-movie-controls-show-and-hide
    func testSkipPauseAndScrubAMovie() throws {
        let app = try launch()
        open(app, "movies")
        let poster = card(app, "movies", in: "continueWatching", "xtream#cabin#vod#2")
        XCTAssertTrue(poster.waitForExistence(timeout: 5))
        poster.tap()
        expectPlayer(app, "playing 2.mp4 from 2160")
        XCTAssertTrue(app.element("title.transport").waitForExistence(timeout: 5), "the controls show when the movie starts")
        XCTAssertEqual(app.element("title.transport.elapsed").label, "36:00")
        XCTAssertEqual(app.element("title.transport.remaining").label, "-54:00")

        app.element("title.transport.skipForward").tap()
        expectPlace(app, "at 2170")
        app.element("title.transport.skipBack").tap()
        app.element("title.transport.skipBack").tap()
        expectPlace(app, "at 2150")
        XCTAssertEqual(app.element("title.transport.elapsed").label, "35:50")

        app.element("title.transport.playPause").tap()
        expectPlayer(app, "paused 2.mp4 from 2160")
        // A drag from the knob, at 2150 of 5400 seconds, to the middle of the bar.
        let scrubber = app.element("title.transport.scrubber")
        scrubber.coordinate(withNormalizedOffset: CGVector(dx: 2150.0 / 5400, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: scrubber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        let probe = app.element("shelf.debug.position")
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != 'at 2150'"), object: probe)
        XCTAssertEqual(
            XCTWaiter().wait(for: [moved], timeout: 5), .completed,
            "the drag moved nothing; the controls read \(app.element("title.transport.elapsed").label)")
        let landed = Int((probe.value as? String ?? "").dropFirst(3)) ?? 0
        XCTAssertTrue((2400...3300).contains(landed), "the drag landed at \(landed), not near the middle")
        expectPlayer(app, "paused 2.mp4 from 2160")

        let picture = app.element("movies.player")
        picture.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.element("title.transport"))
        XCTAssertEqual(XCTWaiter().wait(for: [hidden], timeout: 3), .completed, "a tap hides the controls")
        picture.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        XCTAssertTrue(app.element("title.transport").waitForExistence(timeout: 3), "a second tap shows them")
        XCTAssertTrue(app.element("movies.player.close").exists)
    }

    // player-controls-and-playback-errors/move-around-in-a-movie-or-episode, double tap
    func testDoubleTapSkips() throws {
        let app = try launch()
        open(app, "movies")
        let poster = card(app, "movies", in: "continueWatching", "xtream#cabin#vod#2")
        XCTAssertTrue(poster.waitForExistence(timeout: 5))
        poster.tap()
        expectPlayer(app, "playing 2.mp4 from 2160")
        let picture = app.element("movies.player")
        picture.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.25)).doubleTap()
        expectPlace(app, "at 2170")
        picture.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.25)).doubleTap()
        picture.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.25)).doubleTap()
        expectPlace(app, "at 2150")
    }

    // player-controls-and-playback-errors/choose-audio-and-subtitles-in-a-movie-or-episode
    func testAMovieOffersItsSoundAndSubtitleTracks() throws {
        let app = try launch()
        open(app, "movies")
        let poster = card(app, "movies", in: "continueWatching", "xtream#cabin#vod#2")
        XCTAssertTrue(poster.waitForExistence(timeout: 5))
        poster.tap()
        expectPlayer(app, "playing 2.mp4 from 2160")

        let tracks = app.element("player.tracks")
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: tracks)
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: 5), .completed, "the tracks button stays grayed out")
        tracks.tap()
        XCTAssertTrue(app.element("player.trackPicker").waitForExistence(timeout: 3), "no list")
        XCTAssertEqual(app.element("player.trackPicker.audio.1").label, "English (Commentary)")
        XCTAssertEqual(app.element("player.trackPicker.subtitles.off").value as? String, "Selected")

        app.element("player.trackPicker.audio.1").tap()
        let picked = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == 'Selected'"), object: app.element("player.trackPicker.audio.1"))
        XCTAssertEqual(XCTWaiter().wait(for: [picked], timeout: 3), .completed)
        XCTAssertTrue(app.element("player.trackPicker").exists, "the list stays open")
        app.element("player.trackPicker.done").tap()

        XCTAssertTrue(app.element("player.subtitles").isEnabled)
        app.element("player.subtitles").tap()
        let on = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'On'"), object: app.element("player.subtitles"))
        XCTAssertEqual(XCTWaiter().wait(for: [on], timeout: 3), .completed)
    }
}
