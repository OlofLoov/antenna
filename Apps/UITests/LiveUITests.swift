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
        app.launchInEnglish()
        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 10), "the channel list never appeared")
        return app
    }

    /// The streams the engine loaded, in order.
    var loaded: [String] {
        ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    // live-tv-on-iphone-ipad-mac/picture-pinned-at-the-top-on-iphone
    func testThePictureSitsAboveTheLineGroupButtonAndList() throws {
        let app = try launch()
        let player = app.element("browse.player")
        XCTAssertTrue(app.element("browse.nothingSelected").exists)
        app.row(0).tap()
        XCTAssertTrue(app.element("browse.nowPlaying").waitForExistence(timeout: 5))

        let nowPlaying = app.element("browse.nowPlaying").frame
        let groups = app.element("browse.groups").frame
        let list = app.element("browse.list").frame
        let window = app.windows.firstMatch.frame
        XCTAssertEqual(player.frame.width, window.width, accuracy: 1)
        XCTAssertEqual(player.frame.width / player.frame.height, 16 / 9, accuracy: 0.02)
        XCTAssertLessThanOrEqual(player.frame.maxY, nowPlaying.minY + 1)
        XCTAssertLessThanOrEqual(nowPlaying.maxY, groups.minY + 1)
        XCTAssertLessThanOrEqual(groups.maxY, list.minY + 1)
        // The group button spans the width up to the profile button at the row's trailing end.
        let profile = app.element("profile.button").frame
        XCTAssertEqual(groups.minX, window.minX, accuracy: 1)
        XCTAssertEqual(groups.maxX, profile.minX, accuracy: 1, "the group button runs up to the profile button")
        XCTAssertEqual(profile.midY, groups.midY, accuracy: 2, "one row")
        XCTAssertLessThanOrEqual(profile.maxX, window.maxX)
        XCTAssertGreaterThanOrEqual(groups.height, 44)
        XCTAssertTrue(app.element("browse.groups").label.hasPrefix("All channels, 5 channels"), app.element("browse.groups").label)
        // live-tv-on-iphone-ipad-mac/the-iphone-tab-bar
        for tab in ["Live", "Guide", "Movies", "Series", "Search"] {
            XCTAssertTrue(app.tabBars.buttons[tab].exists, "no \(tab) tab")
        }
        XCTAssertFalse(app.tabBars.buttons["Settings"].exists, "Settings opens from the profile button")
        XCTAssertGreaterThan(app.searchTab.frame.minX, app.tabBars.buttons["Series"].frame.maxX, "Search is last, at the trailing end")
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
        app.pickGroup("browse.group.2")
        XCTAssertTrue(app.row(0).waitForExistence(timeout: 5))
        XCTAssertTrue(app.row(1).exists)
        XCTAssertFalse(app.row(2).exists)
        XCTAssertTrue(app.row(0).frame.minY < app.row(1).frame.minY, "News keeps the catalogue's order")
        app.expectOpenGroup("News", row: "browse.group.2")

        app.waitForEngine("playing loads=1")
        XCTAssertEqual(loaded, ["sport-one.ts"])
    }

    // live-tv-on-iphone-ipad-mac/pick-a-group, empty Favorites
    func testEmptyFavoritesSaysHowToAddOne() throws {
        let app = try launch()
        app.pickGroup("browse.group.0")
        XCTAssertTrue(app.element("browse.emptyGroup").waitForExistence(timeout: 5))
        XCTAssertEqual(app.element("browse.emptyGroup").label, "No favorites yet. Touch and hold a channel, or swipe it right, to add it.")
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

    // live-tv-on-iphone-ipad-mac/see-what-is-on-now-and-next
    func testTheNowPlayingLineShowsTheProgrammeItsTimesAndWhatIsNext() throws {
        let app = try launch()
        app.row(0).tap()

        let line = app.element("browse.nowPlaying")
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        XCTAssertTrue(line.label.hasPrefix("Morning News, 1 News One · "), line.label)
        XCTAssertTrue(line.label.hasSuffix(" · Next: Weather"), line.label)
        XCTAssertFalse(line.label.contains("Business"), "one programme next on iPhone")
    }

    // live-tv-on-iphone-ipad-mac/see-what-is-on-now-and-next, nothing in the guide
    func testAChannelWithoutAGuideSaysSo() throws {
        let app = try launch()
        app.row(3).tap()

        let line = app.element("browse.nowPlaying")
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        XCTAssertEqual(line.label, "No programme information, 4 Kids One")
    }

    // live-tv-on-iphone-ipad-mac/see-what-is-on-now-and-next, a programme ends
    func testWhenAProgrammeEndsTheLineAndTheRowMoveOn() throws {
        let app = try launch()
        app.row(2).tap()
        let line = app.element("browse.nowPlaying")
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        XCTAssertTrue(line.label.hasPrefix("First Half"), line.label)

        let moved = NSPredicate(format: "label BEGINSWITH 'Second Half'")
        let wait = XCTNSPredicateExpectation(predicate: moved, object: line)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 30), .completed, "the line still reads \(line.label)")
        let row = app.row(2)
        let rowMoved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS 'Second Half'"), object: row)
        XCTAssertEqual(XCTWaiter().wait(for: [rowMoved], timeout: 10), .completed, "the row still reads \(row.label)")
    }

    // live-tv-on-iphone-ipad-mac/star-a-channel
    func testTheStarAddsAndRemovesTheFavorite() throws {
        let app = try launch()
        app.row(1).tap()
        let star = app.element("browse.favorite")
        XCTAssertTrue(star.waitForExistence(timeout: 5))
        XCTAssertEqual(star.label, "Add to favorites")

        star.tap()
        XCTAssertEqual(star.label, "Remove from favorites")
        XCTAssertTrue(star.isSelected)
        app.pickGroup("browse.group.0")
        XCTAssertTrue(app.row(1).waitForExistence(timeout: 2), "News Two is in Favorites")
        XCTAssertFalse(app.row(0).exists)

        star.tap()
        XCTAssertEqual(star.label, "Add to favorites")
        XCTAssertTrue(app.element("browse.emptyGroup").waitForExistence(timeout: 2), "Favorites is empty again")
    }
}

extension XCUIApplication {
    func element(_ identifier: String) -> XCUIElement {
        descendants(matching: .any)[identifier].firstMatch
    }

    /// The group row `identifier` (`browse.group.<n>`, `guide.group.<n>`,
    /// `groups.new`, `browse.locked.<key>`). On iPhone the rows sit in the
    /// Groups sheet, so the group button opens it first and the sheet grows
    /// when the row is below its fold; on iPad and Mac the sidebar lists them.
    @discardableResult func groupRow(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let row = element(identifier)
        let button = element(identifier.hasPrefix("guide.") ? "guide.groups" : "browse.groups")
        if !row.exists, button.waitForExistence(timeout: 5) {
            button.tap()
            // The sheet opens at half height; the grabber grows it, then the list scrolls.
            let grabber = buttons["Sheet Grabber"]
            if !row.waitForExistence(timeout: 3), grabber.exists { grabber.tap() }
            for _ in 0..<4 where !row.waitForExistence(timeout: 2) { element("browse.groups.sheet").swipeUp() }
            XCTAssertTrue(row.waitForExistence(timeout: 5), "no \(identifier) in the Groups sheet", file: file, line: line)
        }
        return row
    }

    /// Opens the group row `identifier`, through the Groups sheet on iPhone.
    func pickGroup(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        groupRow(identifier, file: file, line: line).tap()
        let sheet = element("browse.groups.sheet")
        if sheet.exists { XCTAssertTrue(sheet.waitForNonExistence(timeout: 5), "the Groups sheet stayed open", file: file, line: line) }
    }

    /// Closes the Groups sheet when it is open.
    func closeGroups() {
        let close = element("browse.groups.close")
        if close.exists { close.tap() }
        XCTAssertTrue(element("browse.groups.sheet").waitForNonExistence(timeout: 5), "the Groups sheet stayed open")
    }

    /// Waits until `name` is the open group: the group button reads it on
    /// iPhone, the sidebar row `identifier` is selected on iPad and Mac.
    func expectOpenGroup(_ name: String, row identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = element(identifier.hasPrefix("guide.") ? "guide.groups" : "browse.groups")
        let (object, predicate) =
            button.exists
            ? (button, NSPredicate(format: "label BEGINSWITH %@", "\(name),"))
            : (element(identifier), NSPredicate(format: "isSelected == true"))
        let wait = XCTNSPredicateExpectation(predicate: predicate, object: object)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 10), .completed, "\(object.label) is not \(name)", file: file, line: line)
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
        let result = XCTWaiter().wait(for: [wait], timeout: 15)
        XCTAssertEqual(result, .completed, "engine is \(probe.value as? String ?? "missing"), expected \(summary)", file: file, line: line)
    }
}
