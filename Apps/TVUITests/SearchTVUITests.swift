import XCTest

/// The Search tab on Apple TV (search capability), on the scripted shell
/// of `ShellUITests`: Channel a1 to a3 and b1, a1's Morning News on now with
/// Weather, Business, Sport Tonight and Late Film after it, and b1's Evening
/// Film on now.
@MainActor
final class SearchTVUITests: XCTestCase {
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
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: timeout), .completed, "\(element) never matched \(predicate)", file: file,
            line: line)
    }

    func expectFocus(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        expect(element(identifier), "hasFocus == true", file: file, line: line)
    }

    func expectEngine(_ summary: String, file: StaticString = #filePath, line: UInt = #line) {
        expect(element("shell.debug.engine"), "value == '\(summary)'", file: file, line: line)
    }

    /// What has focus, for failure messages.
    func focusedElements() -> String {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex
            .map { "[\($0.identifier) '\($0.label)']" }.joined(separator: " ")
    }

    /// Launches with a1 playing and opens the Search tab from the bar.
    func openSearch(environment: [String: String] = [:]) {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels"]
        app.launchEnvironment.merge(environment) { $1 }
        app.launchInEnglish()
        expectEngine("playing loads=1 file=a1.ts")
        expectFocus("shell.picture")
        expect(element("zapBar.bar"), "exists == false")
        press(.menu)
        expectFocus("shell.tab.live")
        moveAlongTheBar(.right, to: "shell.tab.search")
        press(.select)
        XCTAssertTrue(element("search.results").waitForExistence(timeout: 10))
        // Select on the tab takes the highlight to the keyboard; one that lands
        // while the page opens leaves it on the tab, and a swipe down goes on.
        let tab = element("shell.tab.search")
        if tab.exists, tab.hasFocus { press(.down) }
    }

    /// Types `text` with the search keyboard.
    func type(_ text: String) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.typeText(text)
    }

    /// Swipes down from the keyboard until a result has focus.
    func moveToResults(_ identifier: String) {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        for _ in 0..<4 {
            if target.hasFocus { return }
            press(.down)
            _ = XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasFocus == true"), object: target)], timeout: 2)
        }
        XCTAssertTrue(target.hasFocus, "never reached \(identifier); focused: \(focusedElements())")
    }

    // search/results-grouped-best-first
    // search/very-long-result-lists, Apple TV lists every programme
    func testEverySectionShowsWithoutChips() {
        openSearch()
        type("film")
        let first = element("search.result.programme.0")
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        XCTAssertTrue(first.label.hasPrefix("In the guide, Evening Film, Now Channel b1"), first.label)
        XCTAssertTrue(element("search.result.programme.1").label.hasPrefix("In the guide, Late Film"))
        XCTAssertFalse(element("search.chips").exists, "Apple TV shows every section")
        XCTAssertFalse(element("search.section.channels").exists)
    }

    // design-system/apple-tv-content-stays-in-the-safe-area
    // The results sat 144 pt from the side: 64 pt of padding inside the system's own 80.
    func testTheResultsKeepTheSafeEdges() {
        openSearch()
        type("film")
        let first = element("search.result.programme.0")
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        XCTAssertEqual(first.frame.minX, 80, accuracy: 1, "the results start at the safe edge")
        XCTAssertLessThanOrEqual(first.frame.maxX, app.frame.width - 79, "the results end inside the safe edge")
    }

    // search/pick-a-channel-or-title-to-watch
    func testPickingAChannelPlaysItFullScreen() {
        openSearch()
        type("a2")
        moveToResults("search.result.channel.0")
        press(.select)
        expectEngine("playing loads=2 file=a2.ts")
        expectFocus("shell.picture")
    }

    // search/pick-a-channel-or-title-to-watch, back from a result to the keyboard
    func testSwipingUpFromAResultReachesTheKeyboard() {
        openSearch()
        type("a2")
        moveToResults("search.result.channel.0")
        press(.up)
        expect(element("search.result.channel.0"), "hasFocus == false")
        XCTAssertFalse(
            element("shell.tab.search").exists && element("shell.tab.search").hasFocus,
            "one swipe up lands on the keyboard: \(focusedElements())")
        app.searchFields.firstMatch.typeText("x")
        expect(app.searchFields.firstMatch, "value == 'a2x'")
    }

    // search/pick-a-programme
    // design-system/live-video-keeps-playing-under-overlays, Search pauses the channel
    func testPickingAProgrammeOnNowPlaysItsChannel() {
        openSearch()
        type("evening")
        moveToResults("search.result.programme.0")
        press(.select)
        expectEngine("playing loads=2 file=b1.ts")
    }

    // search/pick-a-programme
    // design-system/live-video-keeps-playing-under-overlays, Search pauses the channel
    func testPickingALaterProgrammeOpensTheGuideAtIt() {
        openSearch(environment: Midday.environment)
        type("late film")
        moveToResults("search.result.programme.0")
        press(.select)
        expectFocus("guide.grid")
        expect(element("guide.panel.title"), "label == 'Late Film'")
        // The Guide plays a1 again, from the pause or, after 30 seconds in Search, tuned again
        // (tvos-shell/the-video-pauses-behind-movies-series-and-search).
        expect(element("shell.debug.engine"), "value BEGINSWITH 'playing loads=' AND value ENDSWITH ' file=a1.ts'")
    }

    // programme-reminders/remind-me-appears-only-before-a-programme-starts, in Search on Apple TV
    func testTheBellAfterALaterProgrammeSetsAReminder() {
        openSearch()
        type("late film")
        moveToResults("search.result.programme.0")
        press(.right)
        let bell = element("search.result.programme.0.remind")
        expectFocus("search.result.programme.0.remind")
        XCTAssertEqual(bell.label, "Remind me")
        press(.select)
        expect(bell, "label == 'Reminder set'")
        XCTAssertTrue(element("search.results").exists, "the bell left Search")
        // Nothing plays behind Search (tvos-shell/the-video-pauses-behind-movies-series-and-search).
        expect(element("shell.debug.engine"), "value IN {'paused loads=1 file=a1.ts', 'idle loads=1 file=a1.ts'}")
    }

    // title-detail-and-episode-picker/back-to-where-you-were
    func testMenuOnASeriesPageReturnsToSearchWithTheQuery() {
        openSearch()
        type("long winter")
        moveToResults("search.result.title.0")
        press(.select)
        XCTAssertTrue(element("title.name").waitForExistence(timeout: 10))
        XCTAssertFalse(element("shell.tab.search").exists, "the page hides the tab bar")

        press(.menu)
        expect(element("title.name"), "exists == false")
        expect(app.searchFields.firstMatch, "value BEGINSWITH 'long winter'")
        // search/pick-a-channel-or-title-to-watch, back on the result on Apple TV
        expectFocus("search.result.title.0")
    }

    // search/pick-a-channel-or-title-to-watch, back on the result on Apple TV
    func testMenuOnAMoviePageComesBackToItsPoster() {
        openSearchOnTheShelf()
        type("quiet")
        moveToResults("search.result.title.0")
        XCTAssertTrue(element("search.result.title.0").label.contains("Quiet Engines"), element("search.result.title.0").label)
        press(.select)
        XCTAssertTrue(element("title.name").waitForExistence(timeout: 10), "the movie's page opens")
        XCTAssertEqual(element("title.name").label, "Quiet Engines")
        XCTAssertFalse(element("movies.player").exists, "nothing plays")
        press(.menu)
        expect(element("title.name"), "exists == false")
        expectFocus("search.result.title.0")
    }

    // search/recent-searches
    // search/pick-a-channel-or-title-to-watch, back on the result on Apple TV
    func testRecentSearchesShowWithAnEmptyField() {
        openSearch()
        type("a2")
        moveToResults("search.result.channel.0")
        press(.select)
        expectEngine("playing loads=2 file=a2.ts")
        expectFocus("shell.picture")
        expect(element("zapBar.bar"), "exists == false")

        press(.menu)
        expectFocus("shell.tab.live")
        moveAlongTheBar(.right, to: "shell.tab.search")
        press(.down)
        // The picked channel has focus; one swipe up is the keyboard.
        expectFocus("search.result.channel.0")
        press(.up)
        expect(element("search.result.channel.0"), "hasFocus == false")
        let field = app.searchFields.firstMatch
        expect(field, "value BEGINSWITH 'a2'")
        field.typeText(XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue)
        let recent = element("search.recent.0")
        XCTAssertTrue(recent.waitForExistence(timeout: 10), "an empty field lists recent searches")
        XCTAssertEqual(recent.label, "Recent search, a2")
    }

    // movies-and-series-browsing/search-from-the-section
    func testMoviesHasNoSearchButtonOnAppleTV() {
        openSearch()
        press(.menu)
        moveAlongTheBar(.left, to: "shell.tab.movies")
        press(.select)
        XCTAssertTrue(element("movies.hero").waitForExistence(timeout: 10))
        XCTAssertFalse(element("movies.search").exists, "the Search tab is the way to search")
    }

    // browse-by-person/find-a-person-in-search
    // search/results-grouped-best-first, People last
    // browse-by-person/a-person-s-page, going back from Search
    // search/pick-a-channel-or-title-to-watch, back on the result on Apple TV
    func testTypingANamePicksThePerson() {
        openSearchOnTheShelf()
        type("mira h")
        let person = element("search.person.0")
        XCTAssertTrue(person.waitForExistence(timeout: 10))
        XCTAssertTrue(person.label.hasPrefix("People, Mira Holt, Acting · "), person.label)
        moveToResults("search.person.0")
        press(.select)
        XCTAssertTrue(element("person.header").waitForExistence(timeout: 5))
        // browse-by-person/a-person-s-page, Apple TV focus: the posters arrive after the page, and Menu needs focus on it.
        expectFocus("person.row.movies.card.xtream#cabin#vod#1")
        press(.menu)
        expect(element("person.header"), "exists == false")
        expect(app.searchFields.firstMatch, "value BEGINSWITH 'mira h'")
        expectFocus("search.person.0")
    }

    // search/results-grouped-best-first, results look like the rest of the app
    // Search drew 180 by 270 posters where Movies draws 212 by 318.
    func testPostersMatchMovies() {
        openSearchOnTheShelf()
        type("harbor")
        let poster = element("search.result.title.0")
        XCTAssertTrue(poster.waitForExistence(timeout: 10))
        let size = poster.frame.size

        press(.menu)
        moveAlongTheBar(.left, to: "shell.tab.movies")
        press(.select)
        let row = element("movies.row.recentlyAdded")
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let shelfPoster = row.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'movies.card.'")).firstMatch
        XCTAssertTrue(shelfPoster.waitForExistence(timeout: 5))
        XCTAssertEqual(size.width, shelfPoster.frame.width, accuracy: 0.5, "a poster in Search is as wide as in Movies")
        XCTAssertEqual(size.height, shelfPoster.frame.height, accuracy: 0.5, "and as tall")
    }

    // search/results-grouped-best-first, results look like the rest of the app
    // design-system/channel-rows-share-one-anatomy
    // Search drew channels as 112 pt cards in a sideways row.
    func testChannelRowsMatchTheChannelList() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels"]
        app.launchInEnglish()
        expectEngine("playing loads=1 file=a1.ts")
        expectFocus("shell.picture")
        expect(element("zapBar.bar"), "exists == false")
        press(.select)
        XCTAssertTrue(element("overlay.root").waitForExistence(timeout: 10))
        // The second row, at rest; the focused first row grows to 100.
        let listRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'overlay.channel.'")).element(boundBy: 1)
        XCTAssertTrue(listRow.waitForExistence(timeout: 5))
        let listHeight = listRow.frame.height
        press(.menu)
        expect(element("overlay.root"), "exists == false")

        press(.menu)
        expectFocus("shell.tab.live")
        moveAlongTheBar(.right, to: "shell.tab.search")
        press(.select)
        XCTAssertTrue(element("search.results").waitForExistence(timeout: 10))
        let tab = element("shell.tab.search")
        if tab.exists, tab.hasFocus { press(.down) }
        type("channel")
        let row = element("search.result.channel.1")
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertEqual(row.frame.height, listHeight, accuracy: 0.5, "a channel row in Search is as tall as in the channel list")
    }

    /// Launches on the shelf's `titles` script and opens the Search tab.
    func openSearchOnTheShelf() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", "titles"]
        app.launchInEnglish()
        // The system bar takes Menu only once something on the page has focus.
        _ = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch.waitForExistence(timeout: 10)
        press(.menu)
        XCTAssertTrue(element("shell.tab.search").waitForExistence(timeout: 10))
        moveAlongTheBar(.right, to: "shell.tab.search")
        press(.select)
        XCTAssertTrue(element("search.results").waitForExistence(timeout: 10))
        let tab = element("shell.tab.search")
        if tab.exists, tab.hasFocus { press(.down) }
    }
}
