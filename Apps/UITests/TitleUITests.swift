import XCTest

/// Movie and series pages on iPhone (title-detail-and-episode-picker
/// capability), on the scripted sources of `UITestingShelf`. The Long Harbor
/// has every detail and a trailer, Salt Road only a length.
@MainActor
final class TitleUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func launch(_ scenario: String = "titles") throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", scenario, "-ui-testing-reduce-motion"]
        app.launch()
        return app
    }

    func openSection(_ app: XCUIApplication, _ kind: String) {
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

    func expect(_ element: XCUIElement, _ predicate: String, file: StaticString = #filePath, line: UInt = #line) {
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [wait], timeout: 5), .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    // title-detail-and-episode-picker/open-a-movie-s-page
    // title-detail-and-episode-picker/what-the-title-is-about
    func testMoreInfoOnTheBannerOpensTheMoviePageWithItsDetails() throws {
        let app = try launch()
        openSection(app, "movies")
        expect(app.element("movies.hero.title"), "label == 'The Long Harbor'")
        app.element("movies.hero.info").tap()

        XCTAssertTrue(app.element("title.name").waitForExistence(timeout: 5))
        XCTAssertEqual(app.element("title.name").label, "The Long Harbor")
        XCTAssertEqual(app.element("title.eyebrow").label, "Movie · Action")
        expect(app.element("title.meta"), "label CONTAINS '2024, 2 h 08 min, Thriller, rating 7.4, 15'")
        XCTAssertTrue(app.element("title.plot").exists)
        XCTAssertTrue(app.element("title.more").exists, "a long description is cut with More")
        XCTAssertTrue(app.element("title.cast").label.contains("Mira Holt"))
        XCTAssertTrue(app.element("title.director").label.contains("Sanna Weiss"))
        XCTAssertFalse(app.element("movies.hero").isHittable, "the page covers the section")
        XCTAssertTrue(app.tabBars.buttons["Movies"].exists, "the tab bar stays on iPhone")

        app.element("title.more").tap()
        expect(app.element("title.more"), "exists == false")

        app.element("title.back").tap()
        expect(app.element("title.name"), "exists == false")
        XCTAssertTrue(app.element("movies.hero.info").isHittable)
    }

    // title-detail-and-episode-picker/open-a-movie-s-page, from the poster's menu
    // title-detail-and-episode-picker/what-the-title-is-about, missing fields
    func testThePosterMenuOpensAMovieWithFieldsMissing() throws {
        let app = try launch()
        openSection(app, "movies")
        app.swipeUp()
        let poster = card(app, "movies", in: "action", "xtream#cabin#vod#3")
        XCTAssertTrue(poster.waitForExistence(timeout: 5))
        poster.press(forDuration: 1.2)
        let info = app.element("movies.menu.info")
        XCTAssertTrue(info.waitForExistence(timeout: 5))
        info.tap()

        XCTAssertTrue(app.element("title.name").waitForExistence(timeout: 5))
        XCTAssertEqual(app.element("title.name").label, "Salt Road")
        expect(app.element("title.meta"), "label == '1 h 32 min'")
        XCTAssertFalse(app.element("title.plot").exists)
        XCTAssertFalse(app.element("title.cast").exists)
        XCTAssertFalse(app.element("title.director").exists)
        XCTAssertFalse(app.element("title.trailer").exists)
        XCTAssertFalse(app.staticTexts["Unknown"].exists)
    }

    // title-detail-and-episode-picker/trailer
    func testTrailerOpensTheLinkOutsideThePage() throws {
        let app = try launch()
        openSection(app, "movies")
        expect(app.element("movies.hero.title"), "label == 'The Long Harbor'")
        app.element("movies.hero.info").tap()
        let trailer = app.element("title.trailer")
        XCTAssertTrue(trailer.waitForExistence(timeout: 5))
        trailer.tap()
        expect(app.element("shelf.debug.opened"), "value == 'https://trailers.example/long-harbor'")
    }

    // title-detail-and-episode-picker/open-a-series-page
    func testSelectingASeriesOpensItsPageWithoutPlaying() throws {
        let app = try launch()
        openSection(app, "series")
        let poster = card(app, "series", in: "recentlyAdded", "xtream#cabin#series#1")
        XCTAssertTrue(poster.waitForExistence(timeout: 5))
        poster.tap()

        XCTAssertTrue(app.element("title.name").waitForExistence(timeout: 5))
        XCTAssertEqual(app.element("title.name").label, "Northern Lights")
        XCTAssertEqual(app.element("title.eyebrow").label, "Series · Drama")
        expect(app.element("title.play"), "label == 'Play S1 E1'")
        expect(app.element("title.meta"), "label CONTAINS '3 seasons'")
        XCTAssertFalse(app.element("series.player").exists, "nothing plays")

        app.element("title.back").tap()
        XCTAssertTrue(app.element("series.hero.info").waitForExistence(timeout: 5))
        app.element("series.hero.info").tap()
        XCTAssertTrue(app.element("title.name").waitForExistence(timeout: 5))
    }

    func openNorthernLights(_ app: XCUIApplication) {
        openSection(app, "series")
        let poster = card(app, "series", in: "recentlyAdded", "xtream#cabin#series#1")
        XCTAssertTrue(poster.waitForExistence(timeout: 5))
        poster.tap()
        XCTAssertTrue(app.element("episodes.list").waitForExistence(timeout: 5))
    }

    func row(_ app: XCUIApplication, _ id: Int) -> XCUIElement {
        app.element("episodes.row.xtream#cabin#episode#\(id)")
    }

    // title-detail-and-episode-picker/pick-a-season
    // title-detail-and-episode-picker/play-starts-the-right-episode
    func testThePickerOpensOnTheUpNextSeasonAndShowsOnlyThePickedOne() throws {
        let app = try launch("watching")
        openNorthernLights(app)
        for id in ["season-1", "season-2", "season-3", "specials", "other"] {
            XCTAssertTrue(app.element("episodes.season.\(id)").exists, "no chip \(id)")
        }
        XCTAssertTrue(app.element("episodes.season.season-2").isSelected, "opens on the season Play would start")
        XCTAssertEqual(app.element("title.play").label, "Play S2 E2")
        XCTAssertTrue(row(app, 12).label.hasSuffix("up next"), "the episode Play starts carries UP NEXT")
        XCTAssertEqual(app.element("episodes.count").label, "3 episodes")
        XCTAssertTrue(row(app, 11).exists && row(app, 12).exists && row(app, 13).exists)

        app.element("episodes.season.season-3").tap()
        expect(row(app, 301), "exists == true")
        XCTAssertFalse(row(app, 11).exists)
        XCTAssertEqual(app.element("episodes.count").label, "1 episode")
        XCTAssertTrue(app.element("episodes.season.season-3").isSelected)
    }

    // title-detail-and-episode-picker/what-each-episode-shows
    func testEachEpisodeShowsItsStateAndVoiceOverReadsIt() throws {
        let app = try launch("watching")
        openNorthernLights(app)
        XCTAssertEqual(row(app, 11).label, "Episode 1, The Weir, 45 min, watched")
        XCTAssertEqual(row(app, 12).label, "Episode 2, Low Water, 45 min, up next")
        XCTAssertEqual(row(app, 13).label, "Episode 3, Ice Road, 45 min")

        app.element("episodes.season.season-1").tap()
        expect(row(app, 102), "exists == true")
        XCTAssertEqual(row(app, 102).label, "Episode 2, Static, 45 min", "barely started looks unwatched")

        app.element("episodes.season.other").tap()
        expect(row(app, 2), "exists == true")
        XCTAssertEqual(row(app, 2).label, "Episode, 45 min", "no number, nothing invented")
        app.swipeUp()
        XCTAssertTrue(app.element("episodes.skipped").exists)
        XCTAssertEqual(app.element("episodes.skipped").label, "1 episode could not be read from the provider's list.")
    }

    // title-detail-and-episode-picker/what-each-episode-shows, in progress
    func testAnEpisodeInProgressShowsItsBarAndMinutesLeft() throws {
        let app = try launch("watching")
        openSection(app, "series")
        let poster = card(app, "series", in: "recentlyAdded", "xtream#cabin#series#2")
        XCTAssertTrue(poster.waitForExistence(timeout: 5))
        poster.tap()
        let episode = app.element("episodes.row.xtream#cabin#episode#21")
        XCTAssertTrue(episode.waitForExistence(timeout: 5))
        XCTAssertEqual(episode.label, "Episode 1, 45 min, 32 min left, up next")
        XCTAssertEqual(app.element("title.play").label, "Resume S1 E1")
        XCTAssertTrue(app.element("title.progress").exists)
        XCTAssertEqual(app.element("title.remaining").label, "32 min left")
        XCTAssertFalse(app.element("episodes.seasons").exists, "one season, no picker")
    }

    func expectPlayer(_ app: XCUIApplication, _ summary: String, file: StaticString = #filePath, line: UInt = #line) {
        expect(app.element("shelf.debug.engine"), "value == '\(summary)'", file: file, line: line)
    }

    // title-detail-and-episode-picker/play-or-resume-a-movie
    func testResumeAMovieAndComeBackToItsPage() throws {
        let app = try launch("watching")
        openSection(app, "movies")
        let poster = card(app, "movies", in: "recentlyAdded", "xtream#cabin#vod#2")
        XCTAssertTrue(poster.waitForExistence(timeout: 5))
        poster.press(forDuration: 1.2)
        app.element("movies.menu.info").tap()
        let play = app.element("title.play")
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        XCTAssertEqual(play.label, "Resume")
        XCTAssertEqual(app.element("title.remaining").label, "54 min left")

        play.tap()
        expectPlayer(app, "playing 2.mp4 from 2160")
        app.element("movies.player.close").tap()
        expect(app.element("movies.player"), "exists == false")
        XCTAssertTrue(app.element("title.name").exists, "back on the page")
        XCTAssertEqual(play.label, "Resume")
        XCTAssertTrue(app.element("title.progress").exists)
    }

    // title-detail-and-episode-picker/play-an-episode-and-come-back
    func testPlayAnEpisodeAndComeBackWithItInView() throws {
        let app = try launch("watching")
        openNorthernLights(app)
        row(app, 13).tap()
        expectPlayer(app, "playing 13.mp4 from 0")
        app.element("series.player.close").tap()
        expect(app.element("series.player"), "exists == false")
        XCTAssertTrue(app.element("episodes.season.season-2").isSelected, "its season shows")
        XCTAssertTrue(row(app, 13).isHittable, "the episode is in view")

        app.element("title.play").tap()
        expectPlayer(app, "playing 12.mp4 from 0")
    }

    // title-detail-and-episode-picker/my-list-from-the-page
    func testMyListOnThePageAgreesWithTheBanner() throws {
        let app = try launch()
        openSection(app, "movies")
        expect(app.element("movies.hero.title"), "label == 'The Long Harbor'")
        XCTAssertEqual(app.element("movies.hero.myList").label, "Add to My list")
        app.element("movies.hero.info").tap()
        let button = app.element("title.myList")
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertEqual(button.label, "Add to my list")
        button.tap()
        expect(button, "label == 'Remove from my list'")

        app.element("title.back").tap()
        expect(app.element("movies.hero.myList"), "label == 'Remove from My list'")
        app.element("movies.hero.info").tap()
        expect(button, "label == 'Remove from my list'")
        button.tap()
        expect(button, "label == 'Add to my list'")
        app.element("title.back").tap()
        expect(app.element("movies.hero.myList"), "label == 'Add to My list'")
    }

    // title-detail-and-episode-picker/back-to-where-you-were
    func testBackAndAnEdgeSwipeReturnToTheSamePlace() throws {
        let app = try launch()
        openSection(app, "series")
        app.swipeUp()
        let poster = card(app, "series", in: "drama", "xtream#cabin#series#3")
        XCTAssertTrue(poster.waitForExistence(timeout: 5))
        XCTAssertTrue(poster.isHittable)
        let before = poster.frame
        poster.tap()
        XCTAssertTrue(app.element("title.name").waitForExistence(timeout: 5))

        app.element("title.back").tap()
        expect(app.element("title.name"), "exists == false")
        XCTAssertEqual(poster.frame, before, "the same rows at the same scroll position")
        XCTAssertTrue(poster.isHittable)

        poster.tap()
        XCTAssertTrue(app.element("title.name").waitForExistence(timeout: 5))
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.5))
        edge.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
        expect(app.element("title.name"), "exists == false")
        XCTAssertEqual(poster.frame, before)
    }
}
