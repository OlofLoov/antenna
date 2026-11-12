import XCTest

/// The guide-on-iphone-ipad-and-mac capability on iPhone, on the scripted
/// Live launch: Home has News One (Morning News on now, then Weather,
/// Business, Sport Tonight and Late Film), News Two (guide loading), Sport
/// One (First Half ends 15 seconds after launch, then Second Half) and Kids
/// One (no guide); Cabin has Cabin Film.
@MainActor
final class GuideUITests: XCTestCase {
    nonisolated let log = FileManager.default.temporaryDirectory.appending(path: "guide-engine-\(UUID().uuidString).log")

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: log)
    }

    private func launch(_ scenario: String = "channels", extra: [String] = []) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the rows run on an iPhone")
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", scenario] + extra
        app.launchEnvironment["UITESTING_ENGINE_LOG"] = log.path
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Guide"].waitForExistence(timeout: 10))
        return app
    }

    private func openGuide(_ app: XCUIApplication) {
        app.tabBars.buttons["Guide"].tap()
        XCTAssertTrue(app.element("guide.root").waitForExistence(timeout: 10), "the guide never appeared")
    }

    private func key(_ position: Int) -> String { "\(LiveUITests.home).\(position)" }

    private func expect(_ element: XCUIElement, _ predicate: String, file: StaticString = #filePath, line: UInt = #line) {
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [wait], timeout: 10), .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    private func cards(_ app: XCUIApplication, row position: Int) -> [XCUIElement] {
        app.descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@ OR identifier BEGINSWITH %@", "guide.block.\(key(position)).",
                    "guide.gap.\(key(position)).")
            )
            .allElementsBoundByIndex.sorted { $0.frame.minX < $1.frame.minX }
    }

    // guide-on-iphone-ipad-and-mac/one-row-per-channel-on-iphone
    func testOneRowPerChannelFromTheProgrammeOnNow() throws {
        let app = try launch()
        openGuide(app)
        XCTAssertTrue(app.element("guide.chips").exists)
        XCTAssertTrue(app.element("guide.days").exists)
        XCTAssertTrue(app.element("guide.list").exists)
        XCTAssertFalse(app.element("guide.filter").exists, "no filter on iPhone")

        let news = cards(app, row: 0)
        XCTAssertGreaterThanOrEqual(news.count, 2)
        XCTAssertTrue(news[0].label.contains("Morning News"), news[0].label)
        XCTAssertTrue(news[0].label.hasSuffix("on now"), news[0].label)
        XCTAssertTrue(news[1].label.contains("Weather"), news[1].label)
        XCTAssertEqual(news[0].frame.width, 168, accuracy: 1)
        XCTAssertTrue(app.element("guide.loading.\(key(1))").exists, "News Two's guide is loading")
        XCTAssertTrue(app.element("guide.noGuide.\(key(3))").exists, "Kids One has no guide")
        XCTAssertEqual(app.element("guide.loading.\(key(1))").label, "Loading guide…")
    }

    // guide-on-iphone-ipad-and-mac/one-row-per-channel-on-iphone, a row scrolls on its own
    func testEachRowScrollsSideways() throws {
        let app = try launch()
        openGuide(app)
        let strip = app.element("guide.strip.\(key(0))")
        let before = cards(app, row: 0)[0].frame.minX
        let lateFilm = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS 'Late Film'", "guide.block.\(key(0))."))
            .firstMatch
        let width = app.windows.firstMatch.frame.width
        XCTAssertFalse(lateFilm.exists && lateFilm.frame.maxX <= width, "Late Film starts off screen")
        strip.swipeLeft()
        XCTAssertTrue(lateFilm.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(lateFilm.frame.maxX, width + 1, "Late Film scrolled into view")
        XCTAssertEqual(cards(app, row: 2).first?.frame.minX ?? 0, before, accuracy: 1, "Sport One stays put")
    }

    // guide-on-iphone-ipad-and-mac/the-same-group-as-live
    func testGroupChipsChangeLivesGroupToo() throws {
        let app = try launch()
        app.element("browse.group.3").tap()
        app.row(2).tap()
        app.waitForEngine("playing loads=1")
        openGuide(app)
        XCTAssertTrue(app.element("guide.group.3").isSelected, "the guide opens on Live's group")
        XCTAssertEqual(app.element("guide.channel.\(key(2))").value as? String, "playing")
        XCTAssertFalse(app.element("guide.channel.\(key(0))").exists)

        app.element("guide.group.2").tap()
        XCTAssertTrue(app.element("guide.channel.\(key(0))").waitForExistence(timeout: 5))
        app.tabBars.buttons["Live"].tap()
        XCTAssertTrue(app.element("browse.group.2").isSelected)
        app.waitForEngine("playing loads=1")
    }

    // guide-on-iphone-ipad-and-mac/read-about-a-programme
    // guide-on-iphone-ipad-and-mac/start-watching-from-the-guide
    func testDetailsOpenAsASheetAndWatchPlaysInLive() throws {
        let app = try launch()
        openGuide(app)
        cards(app, row: 0)[0].tap()
        let panel = app.element("guide.panel")
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertEqual(app.element("guide.panel.title").label, "Morning News")
        XCTAssertTrue(app.element("guide.panel.progress").exists)
        app.element("guide.watch").tap()
        XCTAssertTrue(app.tabBars.buttons["Live"].isSelected)
        app.waitForEngine("playing loads=1")
        expect(app.element("browse.nowPlaying"), "label CONTAINS 'News One'")
    }

    // guide-on-iphone-ipad-and-mac/playback-carries-on-out-of-sight
    func testTheNowPlayingBarReturnsToLive() throws {
        let app = try launch()
        openGuide(app)
        XCTAssertFalse(app.element("guide.nowPlaying").exists, "nothing plays yet")
        app.tabBars.buttons["Live"].tap()
        app.row(0).tap()
        app.waitForEngine("playing loads=1")
        openGuide(app)

        let bar = app.element("guide.nowPlaying")
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        XCTAssertTrue(bar.label.contains("Morning News"), bar.label)
        XCTAssertTrue(bar.label.contains("1 News One"), bar.label)
        XCTAssertTrue(bar.label.contains("LIVE"), bar.label)
        XCTAssertLessThanOrEqual(bar.frame.maxY, app.tabBars.firstMatch.frame.minY + 1, "the bar sits above the tab bar")
        app.waitForEngine("playing loads=1")

        bar.tap()
        XCTAssertTrue(app.tabBars.buttons["Live"].isSelected)
        app.waitForEngine("playing loads=1")
    }

    // guide-on-iphone-ipad-and-mac/start-watching-from-the-guide, the channel name
    func testTappingAChannelNamePlaysIt() throws {
        let app = try launch()
        openGuide(app)
        app.element("guide.channel.\(key(2))").tap()
        XCTAssertTrue(app.tabBars.buttons["Live"].isSelected)
        app.waitForEngine("playing loads=1")
        expect(app.element("browse.nowPlaying"), "label CONTAINS 'Sport One'")
    }

    // guide-on-iphone-ipad-and-mac/move-through-the-days
    func testADayChipShowsThatDay() throws {
        let app = try launch(extra: ["-ui-testing-guide", "days"])
        openGuide(app)
        XCTAssertTrue(app.element("guide.day.0").isSelected)
        app.element("guide.day.1").tap()
        expect(app.element("guide.day.1"), "selected == true")
        expect(cards(app, row: 2).first ?? app.element("guide.missing"), "label CONTAINS 'Tomorrow Match'")
        app.element("guide.now").tap()
        expect(app.element("guide.day.0"), "selected == true")
        XCTAssertTrue(cards(app, row: 0)[0].label.contains("Morning News"))
    }

    // guide-on-iphone-ipad-and-mac/nothing-to-show-yet
    func testAnEmptyGroupSaysSo() throws {
        let app = try launch()
        openGuide(app)
        app.element("guide.group.0").tap()
        let empty = app.element("guide.empty")
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        XCTAssertEqual(empty.label, "No channels in Favorites")
        XCTAssertTrue(app.element("guide.day.0").exists, "the chips still work")
    }

    // guide-on-iphone-ipad-and-mac/nothing-to-show-yet, sources still loading
    func testLoadingSourcesShowLivesLoadingRows() throws {
        let app = try launch("loading")
        openGuide(app)
        XCTAssertTrue(app.element("browse.loading").waitForExistence(timeout: 5))
        XCTAssertFalse(app.element("guide.days").exists, "the chips hide while loading")
    }

    // guide-on-iphone-ipad-and-mac/channels-with-gaps-or-no-guide
    func testAFailedGuideGetsABanner() throws {
        let app = try launch(extra: ["-ui-testing-guide", "failed"])
        openGuide(app)
        XCTAssertTrue(app.element("guide.banner.failed").waitForExistence(timeout: 5))
        XCTAssertEqual(app.element("guide.banner.failed.text").label, "Could not load the guide for Cabin")
        app.element("guide.banner.failed.retry").tap()
        expect(app.element("guide.banner.failed"), "exists == false")
    }
}
