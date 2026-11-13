import XCTest

/// Movies and Series on Apple TV (movies-and-series-browsing capability).
/// Launches the shell's `channels` scenario, whose Xtream source answers with
/// the scripted titles of `UITestingShelf`: Night Ferry, Snow Day and Copper
/// Hills, newest first.
@MainActor
final class ShelfTVUITests: XCTestCase {
    let remote = XCUIRemote.shared
    var app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    func press(_ button: XCUIRemote.Button, times: Int = 1) {
        for _ in 0..<times { remote.press(button) }
    }

    func expect(
        _ element: XCUIElement, _ predicate: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    func expectFocus(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        expect(element(identifier), "hasFocus == true", file: file, line: line)
    }

    /// The shell's `channels` scenario with its first channel playing full screen.
    func launchPlaying() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels"]
        app.launch()
        expectFocus("shell.picture")
        expect(element("zapBar.bar"), "exists == false")
    }

    /// Movies open from the bar, with focus on the banner's Play button.
    func openMovies() {
        launchPlaying()
        press(.menu)
        press(.right, times: 2)
        expectFocus("shell.tab.movies")
        press(.select)
        expectFocus("movies.hero.play")
    }

    // movies-and-series-browsing/movies-and-series-appear-when-your-provider-has-them
    // tvos-shell/the-tabs-in-order
    func testMoviesAndSeriesOpenFromTheTabBar() {
        openMovies()
        XCTAssertTrue(element("movies.row.recentlyAdded").exists)
        press(.up)
        expectFocus("shell.tab.movies")
        press(.right)
        expectFocus("shell.tab.series")
        press(.select)
        expectFocus("series.hero.play")
    }

    // movies-and-series-browsing/movies-and-series-appear-when-your-provider-has-them, no Xtream source
    // tvos-shell/the-tabs-in-order
    func testNoXtreamSourceHasNoMoviesTab() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", "noXtream"]
        app.launch()
        press(.menu)
        XCTAssertTrue(element("shell.tab.live").waitForExistence(timeout: 10))
        XCTAssertTrue(element("shell.tab.search").exists)
        XCTAssertFalse(element("shell.tab.movies").exists)
        XCTAssertFalse(element("shell.tab.series").exists)
    }

    // m3u-playlists/movies-and-series-show-by-what-the-sources-offer, episodes only on Apple TV
    // m3u-playlists/what-a-playlist-offered-is-remembered
    func testAPlaylistOfEpisodesShowsSeriesWithoutMovies() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", "playlistSeries"]
        app.launch()
        press(.menu)
        XCTAssertTrue(element("shell.tab.series").waitForExistence(timeout: 10))
        XCTAssertFalse(element("shell.tab.movies").exists)
        expectFocus("shell.tab.live")
        press(.right, times: 2)
        expectFocus("shell.tab.series")
        press(.select)
        expectFocus("series.hero.play")
    }

    // m3u-playlists/playlist-titles-show-on-every-platform, Search on Apple TV
    func testSearchFindsAPlaylistSeries() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", "playlistSeries"]
        app.launch()
        press(.menu)
        XCTAssertTrue(element("shell.tab.search").waitForExistence(timeout: 10))
        expectFocus("shell.tab.live")
        press(.right, times: 3)
        expectFocus("shell.tab.search")
        press(.select)
        XCTAssertTrue(element("search.results").waitForExistence(timeout: 10))
        expectFocus("shell.tab.search")
        press(.down)
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.typeText("pier")
        let result = element("search.result.title.0")
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        XCTAssertTrue(result.label.contains("Pier Stories"), result.label)
    }

    // movies-and-series-browsing/new-titles-up-front
    func testSwipingPastTheButtonsPagesTheBanner() {
        openMovies()
        let pager = element("movies.hero.pager")
        expect(pager, "value == '1 of 3'")
        XCTAssertEqual(element("movies.hero.title").label, "Night Ferry")
        press(.right, times: 2)
        expectFocus("movies.hero.myList")
        page(.right, pager, to: "2 of 3")
        XCTAssertEqual(element("movies.hero.title").label, "Snow Day")
        press(.left, times: 2)
        expectFocus("movies.hero.play")
        page(.left, pager, to: "1 of 3")
        page(.left, pager, to: "3 of 3")
    }

    /// Presses `button` until the pager reads `value`, at most twice: tvOS
    /// can drop a press while the banner settles, and a press that landed
    /// changes the value, so this never pages twice.
    func page(_ button: XCUIRemote.Button, _ pager: XCUIElement, to value: String, file: StaticString = #filePath, line: UInt = #line) {
        press(button)
        let paged = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: pager)
        if XCTWaiter().wait(for: [paged], timeout: 3) == .completed { return }
        press(button)
        expect(pager, "value == '\(value)'", file: file, line: line)
    }

    // movies-and-series-browsing/browse-a-genre-or-sort-the-lot, on Apple TV
    func testAGenreOpensItsOwnScreenThatMenuCloses() {
        openMovies()
        let chips = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'movies.genres.' AND hasFocus == true"))
        for _ in 0..<10 where !chips.firstMatch.exists {
            press(.down)
            Thread.sleep(forTimeInterval: 1)
        }
        let first = element("movies.genres.myList")
        for _ in 0..<4 where !first.hasFocus {
            press(.left)
            Thread.sleep(forTimeInterval: 0.5)
        }
        expectFocus("movies.genres.myList")
        press(.right)
        expectFocus("movies.genres.all")
        press(.right)
        expectFocus("movies.genres.drama")
        press(.select)
        let grid = element("movies.grid")
        XCTAssertTrue(grid.waitForExistence(timeout: 5))
        XCTAssertFalse(element("movies.hero").exists)
        XCTAssertTrue(grid.staticTexts["2 titles"].exists)

        press(.menu)
        expect(grid, "exists == false")
        expectFocus("movies.hero.play")
        XCTAssertTrue(element("shell.tab.movies").isSelected)
    }

    // movies-and-series-browsing/recently-watched, on Apple TV
    func testRecentlyWatchedShowsAFinishedMovie() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", "watching", "-ui-testing-reduce-motion"]
        app.launch()
        press(.menu)
        let tab = element("shell.tab.movies")
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        for _ in 0..<4 where !tab.hasFocus {
            press(.right)
            Thread.sleep(forTimeInterval: 0.5)
        }
        expectFocus("shell.tab.movies")
        press(.select)
        expectFocus("movies.hero.play")
        let row = element("movies.row.recentlyWatched")
        let finished = row.descendants(matching: .any)["movies.card.xtream#cabin#vod#3"].firstMatch
        for _ in 0..<5 where !(finished.exists && finished.hasFocus) {
            press(.down)
            Thread.sleep(forTimeInterval: 1)
        }
        expect(finished, "hasFocus == true")
        XCTAssertTrue(row.staticTexts["2 titles"].exists)
    }

    // movies-and-series-browsing/see-everything-new, on Apple TV
    func testSeeAllOpensRecentlyAddedThatMenuCloses() {
        openMovies()
        press(.down)
        let row = element("movies.row.recentlyAdded")
        expect(row.buttons.matching(NSPredicate(format: "hasFocus == true")).firstMatch, "exists == true")
        let seeAll = element("movies.row.recentlyAdded.seeAll")
        for _ in 0..<6 where !seeAll.hasFocus {
            press(.right)
            Thread.sleep(forTimeInterval: 0.5)
        }
        expectFocus("movies.row.recentlyAdded.seeAll")
        press(.select)
        let grid = element("movies.grid")
        XCTAssertTrue(grid.waitForExistence(timeout: 5))
        XCTAssertTrue(grid.staticTexts["Recently added"].exists)
        XCTAssertFalse(element("movies.hero").exists)

        press(.menu)
        expect(grid, "exists == false")
        expectFocus("movies.hero.play")
    }

    // movies-and-series-browsing/keep-a-list-for-later, on Apple TV
    func testTheBannerAddsToMyList() {
        openMovies()
        press(.right, times: 2)
        expectFocus("movies.hero.myList")
        let button = element("movies.hero.myList")
        expect(button, "value == 'Not on My list'")
        press(.select)
        expect(button, "value == 'On My list'")
        XCTAssertTrue(element("movies.row.myList").waitForExistence(timeout: 5))
        press(.select)
        expect(button, "value == 'Not on My list'")
        expect(element("movies.row.myList"), "exists == false")
    }

    // movies-and-series-browsing/resume-where-you-left-off, on Apple TV
    func testPlayStartsTheMovieAndMenuGoesBack() {
        openMovies()
        press(.select)
        expect(element("shelf.debug.engine"), "value == 'playing 1.mp4 from 0'")
        expect(element("shell.debug.engine"), "value BEGINSWITH 'idle'")
        press(.menu)
        expect(element("movies.player"), "exists == false")
        expectFocus("movies.hero.play")
        press(.menu)
        expectFocus("shell.tab.movies")
        press(.left, times: 2)
        expectFocus("shell.tab.live")
        press(.select)
        expect(element("shell.debug.engine"), "value BEGINSWITH 'playing loads=2'")
    }

    // player-controls-and-playback-errors/move-around-in-a-movie-or-episode, on Apple TV
    // player-controls-and-playback-errors/the-movie-controls-show-and-hide, on Apple TV
    func testClicksSkipAndSelectPausesAMovie() {
        openMovies()
        press(.select)
        expect(element("shelf.debug.engine"), "value == 'playing 1.mp4 from 0'")
        XCTAssertTrue(element("title.transport").waitForExistence(timeout: 5), "the bar shows when the movie starts")

        press(.right, times: 2)
        expect(element("shelf.debug.position"), "value == 'at 20'")
        press(.left)
        expect(element("shelf.debug.position"), "value == 'at 10'")
        expect(element("title.transport.elapsed"), "label == '0:10'")
        expect(element("title.transport.remaining"), "label == '-1:29:50'")

        press(.select)
        expect(element("shelf.debug.engine"), "value == 'paused 1.mp4 from 0'")
        expect(element("title.transport.stateGlyph"), "label == 'Paused'")
        press(.playPause)
        expect(element("shelf.debug.engine"), "value == 'playing 1.mp4 from 0'")
        press(.menu)
        expect(element("movies.player"), "exists == false")
    }

    // player-controls-and-playback-errors/choose-audio-and-subtitles-in-a-movie-or-episode, on Apple TV
    func testHoldingSelectInAMovieOpensAudioAndSubtitles() {
        openMovies()
        press(.select)
        expect(element("shelf.debug.engine"), "value == 'playing 1.mp4 from 0'")

        XCUIRemote.shared.press(.select, forDuration: 1)
        XCTAssertTrue(element("player.panel").waitForExistence(timeout: 5), "holding select opened no panel")
        expectFocus("player.panel.segment.audio")
        XCTAssertFalse(element("player.panel.segment.info").exists, "a title has no Info tab")
        XCTAssertEqual(element("player.panel.track.1").label, "English (Commentary)")

        press(.down)
        expectFocus("player.panel.track.0")
        press(.down)
        expectFocus("player.panel.track.1")
        press(.select)
        expect(element("player.panel.track.1"), "value == 'Selected'")

        press(.menu)
        expect(element("player.panel"), "exists == false")
        expect(element("shelf.debug.engine"), "value == 'playing 1.mp4 from 0'")
        press(.menu)
        expect(element("movies.player"), "exists == false")
    }
}
