import XCTest

/// Reopening on the title watched last on iPhone (session-restore-and-recently-watched
/// capability), on the `watching` script of `UITestingShelf`, where Harbor
/// Watch's first episode is 30 % in at every launch. The relaunch passes
/// `-ui-testing-keep-session`, so it reads what the first launch stored.
@MainActor
final class ReopenTitleUITests: XCTestCase {
    static let home = "00000000-0000-0000-0000-0000000000E1"

    override func setUp() async throws {
        continueAfterFailure = false
        let idiom = await MainActor.run { UIDevice.current.userInterfaceIdiom }
        try XCTSkipUnless(idiom == .phone, "the tab bar tests run on an iPhone")
    }

    func launch(_ scenario: String = "watching", keep: Bool = false, watchSeconds: Int? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", scenario, "-ui-testing-reduce-motion"] + (keep ? ["-ui-testing-keep-session"] : [])
        if let watchSeconds { app.launchEnvironment["UITESTING_WATCH_SECONDS"] = "\(watchSeconds)" }
        app.launchInEnglish()
        return app
    }

    func expect(_ element: XCUIElement, _ predicate: String, file: StaticString = #filePath, line: UInt = #line) {
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [wait], timeout: 15), .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    /// Plays Harbor Watch from Continue watching in Series, then closes the player.
    func watchHarborWatch(_ app: XCUIApplication) {
        let tab = app.tabBars.buttons["Series"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        let card = app.element("series.row.continueWatching").descendants(matching: .any)["series.card.xtream#cabin#series#2"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        expect(app.element("shelf.debug.engine"), "value == 'playing 21.mp4 from 810'")
        app.element("series.player.close").tap()
        XCTAssertTrue(app.element("series.player").waitForNonExistence(timeout: 5))
    }

    // session-restore-and-recently-watched/reopen-on-the-title-watched-last
    // session-restore-and-recently-watched/what-was-watched-last
    // session-restore-and-recently-watched/reopen-on-the-same-tab-and-group, last watched a title
    func testAnEpisodeReopensItsSeriesPageWithResume() {
        var app = launch()
        watchHarborWatch(app)
        app.terminate()

        app = launch(keep: true)
        expect(app.tabBars.buttons["Series"], "isSelected == true")
        expect(app.element("title.name"), "label == 'Harbor Watch'")
        expect(app.element("title.play"), "label BEGINSWITH 'Resume'")
        expect(app.element("episodes.row.xtream#cabin#episode#21"), "exists == true")
        XCTAssertFalse(app.element("series.player").exists, "nothing plays")

        // Back goes to the section's rows.
        app.element("title.back").tap()
        expect(app.element("series.hero"), "exists == true")
        XCTAssertFalse(app.element("title.root").exists)
    }

    // session-restore-and-recently-watched/what-was-watched-last, a channel after the episode
    // session-restore-and-recently-watched/the-last-channel-plays-again
    func testAChannelWatchedAfterTheEpisodeReopensOnLive() {
        var app = launch(watchSeconds: 1)
        watchHarborWatch(app)
        app.tabBars.buttons["Live"].tap()
        let row = app.element("browse.row.\(Self.home).0")
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        app.waitForEngine("playing loads=1")
        // The count is one second here; three leave room for a slow runner.
        sleep(3)
        app.terminate()

        app = launch(keep: true)
        expect(app.tabBars.buttons["Live"], "isSelected == true")
        app.waitForEngine("playing loads=1")
        XCTAssertFalse(app.element("title.root").exists, "no title page over Live")
    }

    // session-restore-and-recently-watched/a-title-that-cannot-open-gives-way
    func testATitleThatIsGoneOpensTheSectionWithoutAPage() {
        var app = launch()
        watchHarborWatch(app)
        app.terminate()

        // Cabin answers with nothing, so Harbor Watch is gone.
        app = launch("empty", keep: true)
        expect(app.tabBars.buttons["Series"], "isSelected == true")
        XCTAssertFalse(app.element("title.root").waitForExistence(timeout: 5), "no page opens")
    }
}
