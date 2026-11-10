import XCTest

/// The live-tv-on-iphone-ipad-mac capability on iPhone. Each test launches
/// the app with `-ui-testing-live <scenario>` (`UITestingLive`): scripted
/// sources Home and Cabin, a scripted guide and a fake engine that writes
/// the file name of each stream it loads to a log in this test's temporary
/// directory.
@MainActor
final class LiveUITests: XCTestCase {
    static let home = "00000000-0000-0000-0000-0000000000D1"
    nonisolated let log = FileManager.default.temporaryDirectory.appending(path: "live-engine-\(UUID().uuidString).log")

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: log)
    }

    func launch(_ scenario: String = "channels", arguments: [String] = []) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", scenario] + arguments
        app.launchEnvironment["UITESTING_ENGINE_LOG"] = log.path
        app.launch()
        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 10), "the channel list never appeared")
        return app
    }

    /// The streams the engine loaded, in order.
    var loaded: [String] {
        ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    // live-tv-on-iphone-ipad-mac/picture-pinned-at-the-top-on-iphone
    func testThePictureSitsAboveTheLineChipsAndList() throws {
        let app = try launch()
        let player = app.element("browse.player")
        XCTAssertTrue(app.element("browse.nothingSelected").exists)
        app.row(0).tap()
        XCTAssertTrue(app.element("browse.nowPlaying").waitForExistence(timeout: 5))

        let nowPlaying = app.element("browse.nowPlaying").frame
        let chips = app.element("browse.group.0").frame
        let list = app.element("browse.list").frame
        let window = app.windows.firstMatch.frame
        XCTAssertEqual(player.frame.width, window.width, accuracy: 1)
        XCTAssertEqual(player.frame.width / player.frame.height, 16 / 9, accuracy: 0.02)
        XCTAssertLessThanOrEqual(player.frame.maxY, nowPlaying.minY + 1)
        XCTAssertLessThanOrEqual(nowPlaying.maxY, chips.minY + 1)
        XCTAssertLessThanOrEqual(chips.maxY, list.minY + 1)
        for tab in ["Live", "Guide", "Movies", "Search", "Settings"] {
            XCTAssertTrue(app.tabBars.buttons[tab].exists, "no \(tab) tab")
        }
        XCTAssertFalse(app.tabBars.buttons["Favorites"].exists)
        XCTAssertFalse(app.tabBars.buttons["Channels"].exists)
    }

    // live-tv-on-iphone-ipad-mac/picture-pinned-at-the-top-on-iphone, switching between narrow and wide
    func testTurningThePhoneDoesNotInterruptTheChannel() throws {
        let app = try launch()
        app.row(0).tap()
        app.waitForEngine("playing loads=1")

        XCUIDevice.shared.orientation = .landscapeLeft
        XCUIDevice.shared.orientation = .portrait

        app.waitForEngine("playing loads=1")
        XCTAssertEqual(loaded, ["news-one.ts"])
    }

    // live-tv-on-iphone-ipad-mac/picture-pinned-at-the-top-on-iphone, large text
    func testLargeTextGrowsTheRowsAndKeepsThePictureShape() throws {
        let app = try launch(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"])
        let row = app.row(0)
        XCTAssertGreaterThan(row.frame.height, 66)
        row.tap()
        app.waitForEngine("playing loads=1")
        let player = app.element("browse.player").frame
        XCTAssertEqual(player.width / player.height, 16 / 9, accuracy: 0.02)
    }

    // live-tv-on-iphone-ipad-mac/pick-a-group
    func testPickingAGroupListsItsChannelsAndKeepsPlaying() throws {
        let app = try launch()
        app.row(2).tap()
        app.waitForEngine("playing loads=1")

        // Favorites, All channels, then Home's News, Sport and Ungrouped, then Cabin's Films.
        app.element("browse.group.2").tap()
        XCTAssertTrue(app.row(0).waitForExistence(timeout: 5))
        XCTAssertTrue(app.row(1).exists)
        XCTAssertFalse(app.row(2).exists)
        XCTAssertTrue(app.row(0).frame.minY < app.row(1).frame.minY, "News keeps the catalogue's order")
        XCTAssertTrue(app.element("browse.group.2").isSelected)

        app.waitForEngine("playing loads=1")
        XCTAssertEqual(loaded, ["sport-one.ts"])
    }

    // live-tv-on-iphone-ipad-mac/pick-a-group, empty Favorites
    func testEmptyFavoritesSaysHowToAddOne() throws {
        let app = try launch()
        app.element("browse.group.0").tap()
        XCTAssertTrue(app.element("browse.emptyGroup").waitForExistence(timeout: 5))
        XCTAssertEqual(app.element("browse.emptyGroup").label, "No favorites yet. Tap the star on a channel to add it.")
    }

    // live-tv-on-iphone-ipad-mac/pick-a-group, VoiceOver reads a row
    func testARowReadsNameNumberProgrammeAndTimeLeft() throws {
        let app = try launch()
        let label = app.row(0).label
        XCTAssertTrue(label.hasPrefix("News One, 1, Morning News, "), label)
        XCTAssertTrue(label.hasSuffix("left"), label)
    }

    // live-tv-on-iphone-ipad-mac/watch-without-leaving-the-list
    func testPickingAChannelPlaysItInPlace() throws {
        let app = try launch()
        app.row(1).tap()

        app.waitForEngine("playing loads=1")
        XCTAssertEqual(loaded, ["news-two.ts"])
        XCTAssertTrue(app.row(1).isSelected)
        XCTAssertFalse(app.row(0).isSelected)
        XCTAssertTrue(app.element("browse.nowPlaying").label.contains("News Two"))

        // The list stays usable: another row plays next.
        app.row(0).tap()
        app.waitForEngine("playing loads=2")
        XCTAssertEqual(loaded, ["news-two.ts", "news-one.ts"])
        XCTAssertTrue(app.row(0).isSelected)
    }

    // live-tv-on-iphone-ipad-mac/watch-without-leaving-the-list, picking the playing channel
    func testPickingThePlayingChannelDoesNotRestartIt() throws {
        let app = try launch()
        app.row(0).tap()
        app.waitForEngine("playing loads=1")

        app.row(0).tap()

        app.waitForEngine("playing loads=1")
        XCTAssertEqual(loaded, ["news-one.ts"])
    }
}

extension XCUIApplication {
    func element(_ identifier: String) -> XCUIElement {
        descendants(matching: .any)[identifier].firstMatch
    }

    /// Home's row at `position` in its source.
    func row(_ position: Int) -> XCUIElement {
        element("browse.row.\(LiveUITests.home).\(position)")
    }

    /// Waits for the fake engine's summary, `"<state> loads=<n>"`.
    func waitForEngine(_ summary: String, file: StaticString = #filePath, line: UInt = #line) {
        let probe = element("browse.debug.engine")
        let matches = NSPredicate(format: "value == %@", summary)
        let wait = XCTNSPredicateExpectation(predicate: matches, object: probe)
        let result = XCTWaiter().wait(for: [wait], timeout: 5)
        XCTAssertEqual(result, .completed, "engine is \(probe.value as? String ?? "missing"), expected \(summary)", file: file, line: line)
    }
}
