import XCTest

/// Search on iPhone (search capability), on the scripted sources of
/// `UITestingShelf`: Home's News One, News Two, Sport One and Kids One, News
/// One's Morning News on now with Weather, Business, Sport Tonight and Late
/// Film after it, and Cabin's and Office's movies and series.
@MainActor
final class SearchUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func launch(_ scenario: String = "titles", _ extra: [String] = []) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", scenario, "-ui-testing-reduce-motion"] + extra
        app.launch()
        return app
    }

    /// Opens the Search tab and types `text` into the field.
    func search(_ app: XCUIApplication, _ text: String) {
        let tab = app.tabBars.buttons["Search"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        let field = app.element("search.field")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        expect(field, "hasKeyboardFocus == true")
        field.typeText(text)
    }

    func expect(
        _ element: XCUIElement, _ predicate: String, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line
    ) {
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [wait], timeout: timeout), .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    // search/results-grouped-best-first
    func testResultsComeInSectionsWithCountsAndTheBestFirst() throws {
        let app = try launch()
        search(app, "news")

        XCTAssertTrue(app.element("search.section.channels").waitForExistence(timeout: 5))
        expect(app.element("search.result.channel.0"), "label BEGINSWITH 'Channels, News One, 1 · Now: Morning News'")
        expect(app.element("search.result.channel.1"), "label BEGINSWITH 'Channels, News Two'")
        expect(app.element("search.result.programme.0"), "label BEGINSWITH 'In the guide, Morning News, Now News One'")
        XCTAssertFalse(app.element("search.section.titles").exists, "an empty section is left out")
        XCTAssertEqual(app.element("search.chip.all").label, "All · 3")
        XCTAssertEqual(app.element("search.chip.channels").label, "Channels · 2")
        XCTAssertEqual(app.element("search.chip.guide").label, "Guide · 1")
    }

    // search/find-things-the-way-you-type-them
    func testOneLetterShowsNothingAndTheSecondSearches() throws {
        let app = try launch()
        search(app, "N")
        XCTAssertFalse(app.element("search.result.channel.0").waitForExistence(timeout: 2))
        XCTAssertFalse(app.element("search.chips").exists, "no chips without results")
        app.element("search.field").typeText("Ë")
        expect(app.element("search.result.channel.0"), "label BEGINSWITH 'Channels, News One'")
    }

    // search/narrow-to-one-kind
    func testChipsNarrowToOneKindAndAnEmptyKindIsGrayedOut() throws {
        let app = try launch()
        search(app, "harbor")

        XCTAssertTrue(app.element("search.result.title.0").waitForExistence(timeout: 10))
        expect(app.element("search.chip.channels"), "label == 'Channels · 0'")
        XCTAssertFalse(app.element("search.chip.channels").isEnabled, "an empty kind is grayed out")
        expect(app.element("search.chip.movies"), "label == 'Movies · 1'")
        expect(app.element("search.chip.series"), "label == 'Series · 1'")

        app.element("search.chip.series").tap()
        expect(app.element("search.result.title.0"), "label == 'Movies & series, Harbor Watch, series'")
        XCTAssertFalse(app.element("search.result.title.1").exists, "only series")
        app.element("search.chip.all").tap()
        XCTAssertTrue(app.element("search.result.title.1").waitForExistence(timeout: 5))
    }

    // search/narrow-to-one-kind, no Movies or Series sections
    func testNoMoviesOrSeriesChipsWithoutThoseSections() throws {
        let app = try launch("noXtream")
        search(app, "news")
        XCTAssertTrue(app.element("search.chip.channels").waitForExistence(timeout: 5))
        XCTAssertFalse(app.element("search.chip.movies").exists)
        XCTAssertFalse(app.element("search.chip.series").exists)
    }

    // search/clear-the-field
    func testClearEmptiesTheFieldAndKeepsItReady() throws {
        let app = try launch()
        search(app, "sport")
        XCTAssertTrue(app.element("search.result.channel.0").waitForExistence(timeout: 5))

        app.element("search.clear").tap()
        let field = app.element("search.field")
        expect(field, "value == '' OR value == placeholderValue")
        expect(field, "hasKeyboardFocus == true")
        XCTAssertFalse(app.element("search.result.channel.0").exists)
        field.typeText("ki")
        expect(app.element("search.result.channel.0"), "label BEGINSWITH 'Channels, Kids One'")
    }

    // search/nothing-found
    func testNothingFoundNamesTheQueryWithAHint() throws {
        let app = try launch()
        search(app, "norhtern")
        let empty = app.element("search.empty")
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        XCTAssertTrue(empty.label.contains("No results for “norhtern”"), empty.label)
        XCTAssertTrue(empty.label.contains("Check the spelling or try a channel number."), empty.label)
        XCTAssertFalse(empty.label.contains("still loading"), "every source has loaded")
    }

    // search/nothing-found, a source still loading
    func testNothingFoundSaysWhenASourceIsStillLoading() throws {
        let app = try launch("loading")
        search(app, "norhtern")
        let empty = app.element("search.empty")
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        XCTAssertTrue(empty.label.contains("Some sources are still loading."), empty.label)
    }

    // search/pick-a-channel-or-title-to-watch
    func testPickingAChannelPlaysItInLiveAndKeepsTheSearch() throws {
        let app = try launch()
        let news = app.element("browse.group.2")
        XCTAssertTrue(news.waitForExistence(timeout: 10))
        news.tap()
        search(app, "sport")
        let result = app.element("search.result.channel.0")
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()

        XCTAssertTrue(app.tabBars.buttons["Live"].isSelected)
        expect(app.element("browse.debug.engine"), "value == 'playing loads=1'")
        expect(app.element("browse.nowPlaying"), "label CONTAINS 'Sport One'")
        XCTAssertTrue(app.element("browse.group.1").isSelected, "Sport One is not in News, so All channels shows")
        app.tabBars.buttons["Search"].tap()
        expect(app.element("search.field"), "value == 'sport'")
        XCTAssertTrue(app.element("search.result.channel.0").exists)
    }

    // search/pick-a-channel-or-title-to-watch, a movie
    func testPickingAMoviePlaysIt() throws {
        let app = try launch()
        search(app, "long harbor")
        let result = app.element("search.result.title.0")
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        result.tap()
        XCTAssertTrue(app.element("movies.player").waitForExistence(timeout: 5))
        app.element("movies.player.close").tap()
        XCTAssertTrue(app.element("search.result.title.0").waitForExistence(timeout: 5), "back at Search")
    }

    // title-detail-and-episode-picker/open-a-series-page
    func testPickingASeriesOpensItsPageOverSearch() throws {
        let app = try launch()
        search(app, "harbor watch")
        let result = app.element("search.result.title.0")
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        result.tap()
        XCTAssertTrue(app.element("title.name").waitForExistence(timeout: 5))
        XCTAssertEqual(app.element("title.name").label, "Harbor Watch")
        XCTAssertTrue(app.tabBars.buttons["Search"].isSelected, "the page shows over Search")
        XCTAssertFalse(
            app.element("shelf.debug.engine").exists && (app.element("shelf.debug.engine").value as? String ?? "").hasPrefix("playing"))
    }

    // search/very-long-result-lists
    func testLongListsAreCappedWithTheFullCount() throws {
        let app = try launch("titles", ["-ui-testing-many-channels"])
        search(app, "harbour")

        XCTAssertTrue(app.element("search.result.channel.0").waitForExistence(timeout: 10))
        expect(app.element("search.chip.channels"), "label == 'Channels · 600'", timeout: 10)
        app.element("search.chip.channels").tap()
        let note = app.element("search.capNote")
        XCTAssertTrue(scroll(app, to: note), "the capped list ends with a note")
        XCTAssertEqual(note.label, "Showing 500 of 600")
        XCTAssertFalse(app.element("search.result.channel.500").exists)

        // The guide lists four until See all, which lists the rest in place.
        app.element("search.clear").tap()
        app.element("search.field").typeText("talk")
        app.element("search.chip.all").tap()
        XCTAssertTrue(app.element("search.result.programme.3").waitForExistence(timeout: 5))
        XCTAssertFalse(app.element("search.result.programme.4").exists)
        XCTAssertEqual(app.element("search.seeAll").label, "See all 6")
        app.element("search.seeAll").tap()
        XCTAssertTrue(app.element("search.result.programme.5").waitForExistence(timeout: 5))
    }

    /// Swipes up fast until `element` shows, at most 60 times.
    func scroll(_ app: XCUIApplication, to element: XCUIElement) -> Bool {
        for _ in 0..<60 {
            if element.exists { return true }
            app.swipeUp(velocity: .fast)
        }
        return element.exists
    }

    /// Home's channel row at `position`.
    func row(_ app: XCUIApplication, _ position: Int) -> XCUIElement {
        app.element("browse.row.00000000-0000-0000-0000-0000000000E1.\(position)")
    }

    // search/pick-a-programme, a later programme
    // guide-on-iphone-ipad-and-mac/open-at-a-programme, from Search
    // guide-on-iphone-ipad-and-mac/start-watching-from-the-guide, a later programme
    func testPickingALaterProgrammeOpensTheGuideAtIt() throws {
        let app = try launch()
        search(app, "late film")
        let result = app.element("search.result.programme.0")
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertFalse(result.label.contains(", Now "), "Late Film starts later")
        result.tap()

        XCTAssertTrue(app.tabBars.buttons["Guide"].isSelected)
        expect(app.element("guide.panel.title"), "label == 'Late Film'")
        app.element("guide.watch").tap()

        XCTAssertTrue(app.tabBars.buttons["Live"].isSelected)
        expect(app.element("browse.nowPlaying"), "label CONTAINS 'News One'")
        let later = app.element("browse.later")
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        XCTAssertTrue(later.label.hasPrefix("Later: "), later.label)
        XCTAssertTrue(later.label.hasSuffix("Late Film"), later.label)

        row(app, 1).tap()
        expect(app.element("browse.nowPlaying"), "label CONTAINS 'News Two'")
        XCTAssertFalse(later.exists, "a channel change clears it")
    }

    // search/pick-a-programme, a programme on now
    func testPickingAProgrammeOnNowPlaysItsChannelWithoutALaterLine() throws {
        let app = try launch()
        search(app, "morning")
        let result = app.element("search.result.programme.0")
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        expect(app.element("browse.nowPlaying"), "label CONTAINS 'News One'")
        XCTAssertFalse(app.element("browse.later").exists)
    }

    // title-detail-and-episode-picker/back-to-where-you-were
    func testBackFromASeriesPageReturnsToSearchWithTheQuery() throws {
        let app = try launch()
        search(app, "harbor watch")
        let result = app.element("search.result.title.0")
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        result.tap()
        XCTAssertTrue(app.element("title.name").waitForExistence(timeout: 5))

        app.element("title.back").tap()
        expect(app.element("title.name"), "exists == false")
        expect(app.element("search.field"), "value == 'harbor watch'")
        XCTAssertTrue(result.isHittable, "the result is back in view")

        result.tap()
        XCTAssertTrue(app.element("title.name").waitForExistence(timeout: 5))
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.5))
        edge.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
        expect(app.element("title.name"), "exists == false")
        expect(app.element("search.field"), "value == 'harbor watch'")
    }

    // search/recent-searches
    func testAPickedSearchIsListedWithAnEmptyFieldAndRunsAgain() throws {
        let app = try launch()
        search(app, "sport")
        let result = app.element("search.result.channel.0")
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        XCTAssertTrue(app.tabBars.buttons["Live"].isSelected)

        app.tabBars.buttons["Search"].tap()
        app.element("search.clear").tap()
        let recent = app.element("search.recent.0")
        XCTAssertTrue(recent.waitForExistence(timeout: 5), "an empty field lists recent searches")
        XCTAssertEqual(recent.label, "Recent search, sport")

        recent.tap()
        expect(app.element("search.field"), "value == 'sport'")
        XCTAssertTrue(app.element("search.result.channel.0").waitForExistence(timeout: 5))
    }

    // movies-and-series-browsing/search-from-the-section
    func testTheSearchButtonInMoviesOpensSearchSetToMovies() throws {
        let app = try launch()
        let tab = app.tabBars.buttons["Movies"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        let button = app.element("movies.search")
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()

        XCTAssertTrue(app.tabBars.buttons["Search"].isSelected)
        let field = app.element("search.field")
        expect(field, "hasKeyboardFocus == true")
        field.typeText("harbor")
        XCTAssertTrue(app.element("search.result.title.0").waitForExistence(timeout: 10))
        XCTAssertTrue(app.element("search.chip.movies").isSelected, "Search opens set to movies")
        XCTAssertEqual(app.element("search.result.title.0").label, "Movies & series, The Long Harbor")
        XCTAssertFalse(app.element("search.result.title.1").exists, "Harbor Watch is a series")
    }
}
