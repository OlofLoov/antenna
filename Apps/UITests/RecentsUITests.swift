import XCTest

/// Recents on iPhone and iPad (session-restore-and-recently-watched capability), on
/// `-ui-testing-live channels`. `UITESTING_RECENTS` seeds the recents and
/// `UITESTING_WATCH_SECONDS` shortens the ten-second count (`UITestingRecents`).
@MainActor
final class RecentsUITests: XCTestCase {
    nonisolated let log = FileManager.default.temporaryDirectory.appending(path: "recents-engine-\(UUID().uuidString).log")
    nonisolated let recentsFile = FileManager.default.temporaryDirectory.appending(path: "recents-\(UUID().uuidString).txt")

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: log)
        try? FileManager.default.removeItem(at: recentsFile)
    }

    func launch(recents: String? = nil, watchSeconds: Double = 1) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"]
        app.launchEnvironment["UITESTING_ENGINE_LOG"] = log.path
        app.launchEnvironment["UITESTING_WATCH_SECONDS"] = String(watchSeconds)
        app.launchEnvironment["UITESTING_RECENTS_FILE"] = recentsFile.path
        if let recents { app.launchEnvironment["UITESTING_RECENTS"] = recents }
        app.launch()
        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 10), "the channel list never appeared")
        return app
    }

    /// Waits until the app has stored `ids` as its recents, newest first.
    func waitForRecents(_ ids: [String], file: StaticString = #filePath, line: UInt = #line) {
        let expected = ids.map { "fixture/\($0)" }.joined(separator: "\n")
        let mirror = recentsFile
        let stored = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in (try? String(contentsOf: mirror, encoding: .utf8)) == expected }, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [stored], timeout: 10), .completed, "recents never became \(ids)", file: file, line: line)
    }

    /// The rows of the open list, top to bottom, by identifier.
    func rows(_ app: XCUIApplication) -> [String] {
        let rows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'browse.row.'"))
        return rows.allElementsBoundByIndex.filter(\.isHittable).sorted { $0.frame.minY < $1.frame.minY }.map(\.identifier)
    }

    // session-restore-and-recently-watched/recents-sits-between-favorites-and-all-channels
    func testRecentsSitsBetweenFavoritesAndAllChannelsNewestFirst() {
        let app = launch(recents: "sport-one,news-one")
        let recents = app.element("browse.group.1")
        XCTAssertTrue(recents.waitForExistence(timeout: 5))
        XCTAssertTrue(recents.label.hasPrefix("Recents, 2 channels"), "label is \(recents.label)")
        XCTAssertTrue(app.element("browse.group.0").label.hasPrefix("Favorites"))
        XCTAssertTrue(app.element("browse.group.2").label.hasPrefix("All channels"))
        recents.tap()
        XCTAssertEqual(rows(app), ["browse.row.\(LiveUITests.home).2", "browse.row.\(LiveUITests.home).0"])
    }

    // session-restore-and-recently-watched/recents-sits-between-favorites-and-all-channels, nothing to list
    func testRecentsIsHiddenWithNothingToList() {
        let app = launch(recents: "gone")
        XCTAssertTrue(app.element("browse.group.1").waitForExistence(timeout: 5))
        XCTAssertTrue(app.element("browse.group.1").label.hasPrefix("All channels"), "a channel that no longer exists is not listed")
    }

    // session-restore-and-recently-watched/a-channel-counts-as-watched-after-ten-seconds
    // session-restore-and-recently-watched/the-list-holds-still-while-you-use-it
    func testPlayingFromRecentsKeepsTheOrderUntilItOpensAgain() {
        let app = launch(recents: "sport-one,news-one")
        app.element("browse.group.1").tap()
        let newsOne = app.element("browse.row.\(LiveUITests.home).0")
        newsOne.tap()
        app.waitForEngine("playing loads=1")
        waitForRecents(["news-one", "sport-one"])
        XCTAssertEqual(rows(app), ["browse.row.\(LiveUITests.home).2", "browse.row.\(LiveUITests.home).0"], "the open list holds still")
        app.element("browse.group.2").tap()
        app.element("browse.group.1").tap()
        XCTAssertEqual(rows(app), ["browse.row.\(LiveUITests.home).0", "browse.row.\(LiveUITests.home).2"])
    }

    // session-restore-and-recently-watched/a-channel-counts-as-watched-after-ten-seconds
    func testAChannelWatchedLongEnoughJoinsRecents() {
        let app = launch()
        XCTAssertTrue(app.element("browse.group.1").label.hasPrefix("All channels"))
        app.element("browse.row.\(LiveUITests.home).3").tap()
        app.waitForEngine("playing loads=1")
        let recents = app.element("browse.group.1")
        let joined = NSPredicate(format: "label BEGINSWITH 'Recents, 1 channel'")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: joined, object: recents)], timeout: 10), .completed)
    }
}
