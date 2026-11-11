import XCTest

/// Reopening where the user left off on iPhone (session-restore-and-recently-watched
/// capability). The first launch of each test starts with nothing stored;
/// the relaunch passes `-ui-testing-keep-session` so the app reads what the
/// first one stored (`UITestingRecents`).
@MainActor
final class RestoreUITests: XCTestCase {
    static let home = "00000000-0000-0000-0000-0000000000D1"
    static let cabin = "00000000-0000-0000-0000-0000000000D2"
    nonisolated let log = FileManager.default.temporaryDirectory.appending(path: "restore-engine-\(UUID().uuidString).log")
    nonisolated let lastChannel = FileManager.default.temporaryDirectory.appending(path: "restore-last-\(UUID().uuidString).txt")

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the tab bar tests run on an iPhone")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: log)
        try? FileManager.default.removeItem(at: lastChannel)
    }

    func launch(_ scenario: String = "channels", keep: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", scenario] + (keep ? ["-ui-testing-keep-session"] : [])
        app.launchEnvironment["UITESTING_ENGINE_LOG"] = log.path
        app.launchEnvironment["UITESTING_LAST_CHANNEL_FILE"] = lastChannel.path
        app.launch()
        return app
    }

    var loaded: [String] {
        ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    /// Waits until the app has stored `id` as the last channel.
    func waitForLastChannel(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let mirror = lastChannel
        let stored = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in (try? String(contentsOf: mirror, encoding: .utf8)) == "fixture/\(id)" }, object: nil)
        XCTAssertEqual(
            XCTWaiter().wait(for: [stored], timeout: 10), .completed, "\(id) never became the last channel", file: file, line: line)
    }

    func expect(_ element: XCUIElement, _ predicate: String, file: StaticString = #filePath, line: UInt = #line) {
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [wait], timeout: 15), .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    /// Plays Cabin Film from All channels and waits until it is stored.
    func playCabinFilm(_ app: XCUIApplication) {
        let film = app.element("browse.row.\(Self.cabin).0")
        XCTAssertTrue(film.waitForExistence(timeout: 10))
        film.tap()
        app.waitForEngine("playing loads=1")
        waitForLastChannel("cabin-film")
    }

    // session-restore-and-recently-watched/reopen-on-the-same-tab-and-group
    // session-restore-and-recently-watched/the-last-channel-plays-again
    // session-restore-and-recently-watched/restore-survives-the-system-closing-the-app
    func testTheTabGroupAndChannelComeBackAfterTheSystemClosesTheApp() {
        var app = launch()
        // Favorites, All channels, News, Sport, Ungrouped, Films.
        let sport = app.element("browse.group.3")
        XCTAssertTrue(sport.waitForExistence(timeout: 10))
        sport.tap()
        app.element("browse.row.\(Self.home).2").tap()
        app.waitForEngine("playing loads=1")
        waitForLastChannel("sport-one")
        app.tabBars.buttons["Guide"].tap()
        app.terminate()

        app = launch(keep: true)
        expect(app.tabBars.buttons["Guide"], "isSelected == true")
        XCTAssertEqual(loaded, ["sport-one.ts"], "nothing plays until Live shows")
        app.tabBars.buttons["Live"].tap()
        app.waitForEngine("playing loads=1")
        XCTAssertEqual(loaded, ["sport-one.ts", "sport-one.ts"])
        expect(app.element("browse.group.3"), "isSelected == true")
    }

    // session-restore-and-recently-watched/reopen-on-the-same-tab-and-group, Search is not restored
    func testSearchOpensOnLive() {
        var app = launch()
        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 10))
        app.tabBars.buttons["Search"].tap()
        app.terminate()

        app = launch(keep: true)
        expect(app.tabBars.buttons["Live"], "isSelected == true")
    }

    // session-restore-and-recently-watched/the-last-channel-plays-again, offline or slow at launch
    func testTheChannelPlaysOnceItsSourceLoadsAfterARetry() {
        var app = launch()
        playCabinFilm(app)
        app.terminate()

        // Cabin fails on the first load and loads on the next.
        app = launch("failing", keep: true)
        let retry = app.element("browse.banner.failed.retry")
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        XCTAssertEqual(loaded, ["cabin-film.ts"], "nothing plays while Cabin failed")
        retry.tap()
        app.waitForEngine("playing loads=1")
        XCTAssertEqual(loaded.last, "cabin-film.ts")
    }

    // session-restore-and-recently-watched/reopen-on-the-same-tab-and-group, a group that arrives later
    func testALateGroupIsSelectedWhenItArrives() {
        var app = launch()
        let films = app.element("browse.group.5")
        XCTAssertTrue(films.waitForExistence(timeout: 10))
        // The chip sits past the screen edge until the chips scroll.
        app.element("browse.group.3").swipeLeft()
        films.tap()
        app.terminate()

        // Cabin's login arrives six seconds after launch.
        app = launch("waiting", keep: true)
        expect(app.element("browse.group.1"), "isSelected == true")
        expect(app.element("browse.group.5"), "isSelected == true")
    }

    // session-restore-and-recently-watched/the-last-channel-plays-again, the channel cannot be played
    func testAChannelThatCannotBeFoundPlaysNothing() {
        var app = launch()
        playCabinFilm(app)
        app.terminate()

        // Home loads no channels and Cabin has no login.
        app = launch("empty", keep: true)
        XCTAssertTrue(app.element("browse.empty").waitForExistence(timeout: 10))
        XCTAssertEqual(loaded, ["cabin-film.ts"])
    }
}
