import XCTest

/// The guide-on-iphone-ipad-and-mac capability in the iPad window. Runs on an
/// iPad simulator; on an iPhone every test skips. Uses the scripted Live
/// launch: Home has News One (Morning News on now, then four more), News Two
/// (guide loading), Sport One (First Half ends 15 seconds after launch) and
/// Kids One (no guide); Cabin has Cabin Film.
@MainActor
final class GuideRegularUITests: XCTestCase {
    nonisolated let log = FileManager.default.temporaryDirectory.appending(path: "guide-engine-\(UUID().uuidString).log")

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: log)
    }

    private func launch(_ scenario: String = "channels", extra: [String] = [], reset: Bool = true) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "the grid needs an iPad")
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", scenario] + extra + (reset ? ["-ui-testing-reset-guide-zoom"] : [])
        app.launchEnvironment["UITESTING_ENGINE_LOG"] = log.path
        app.launch()
        XCTAssertTrue(app.element("browse.section.guide").waitForExistence(timeout: 10), "the sidebar never appeared")
        return app
    }

    private func openGuide(_ app: XCUIApplication) {
        app.element("browse.section.guide").tap()
        XCTAssertTrue(app.element("guide.grid").waitForExistence(timeout: 10), "the grid never appeared")
    }

    private func key(_ position: Int) -> String { "\(LiveUITests.home).\(position)" }

    private func expect(_ element: XCUIElement, _ predicate: String, file: StaticString = #filePath, line: UInt = #line) {
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [wait], timeout: 10), .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    /// Blocks of the row at `position` whose identifiers start with `kind`.
    private func blocks(_ app: XCUIApplication, _ kind: String, row position: Int) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "guide.\(kind).\(key(position))."))
    }

    private func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    // guide-on-iphone-ipad-and-mac/a-time-grid-on-ipad-and-mac
    func testTheGridOpensHalfAnHourBackWithTheNowLine() throws {
        let app = try launch()
        openGuide(app)
        let now = Date.now
        XCTAssertTrue(app.element("guide.toolbar").exists)
        XCTAssertTrue(app.element("guide.filter").exists)
        XCTAssertTrue(app.element("guide.zoomIn").exists)
        XCTAssertTrue(app.element("guide.zoomOut").exists)
        XCTAssertFalse(app.element("browse.player").exists, "no picture in the guide")
        XCTAssertFalse(app.element("browse.list").exists, "no channel list in the guide")

        let columns = app.descendants(matching: .any).matching(identifier: "guide.column").allElementsBoundByIndex
            .sorted { $0.frame.minX < $1.frame.minX }
        let back = halfHour(atOrBefore: now.addingTimeInterval(-1800))
        let index = try XCTUnwrap(columns.firstIndex { $0.frame.minX >= app.element("guide.groupTitle").frame.maxX - 1 })
        XCTAssertEqual(columns[index].label, time(back))
        XCTAssertEqual(columnWidth(app), 180, accuracy: 1)
        XCTAssertEqual(app.element("guide.nowLine").label, time(Date.now))

        let channels = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'guide.channel.'"))
            .allElementsBoundByIndex.sorted { $0.frame.minY < $1.frame.minY }
        XCTAssertEqual(channels.count, 5)
        XCTAssertEqual(channels.first?.label, "1 News One")
        XCTAssertTrue(blocks(app, "block", row: 0).firstMatch.exists, "Morning News is in the grid")
        XCTAssertTrue(app.element("guide.loading.\(key(1))").exists, "News Two's guide is loading")
        XCTAssertTrue(app.element("guide.noGuide.\(key(3))").exists, "Kids One has no guide")
    }

    // guide-on-iphone-ipad-and-mac/a-time-grid-on-ipad-and-mac, identifiers never hold a stream link
    func testNoGuideIdentifierHoldsAStreamLink() throws {
        let app = try launch()
        openGuide(app)
        let identifiers = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'guide.'"))
            .allElementsBoundByIndex.map(\.identifier)
        XCTAssertGreaterThan(identifiers.count, 10)
        // The fixture streams are file:///fixture/<id>.ts, with no host or query.
        for identifier in identifiers {
            XCTAssertFalse(identifier.contains("file:"), identifier)
            XCTAssertFalse(identifier.contains("fixture"), identifier)
            XCTAssertFalse(identifier.contains("?"), identifier)
        }
    }

    // guide-on-iphone-ipad-and-mac/the-same-group-as-live
    func testTheGuideAndLiveShareTheGroup() throws {
        let app = try launch()
        app.element("browse.group.3").tap()
        XCTAssertEqual(app.element("browse.header.title").label, "Sport")
        app.row(2).tap()
        app.waitForEngine("playing loads=1")

        openGuide(app)
        expect(app.element("guide.groupTitle"), "label == 'Sport, 1'")
        XCTAssertEqual(app.element("guide.channel.\(key(2))").value as? String, "playing")
        app.element("browse.group.2").tap()
        expect(app.element("guide.groupTitle"), "label == 'News, 2'")
        XCTAssertTrue(app.element("guide.channel.\(key(0))").exists)
        XCTAssertTrue(app.element("browse.section.guide").isSelected, "the guide stays open")

        app.element("browse.section.live").tap()
        expect(app.element("browse.header.title"), "label == 'News'")
        app.waitForEngine("playing loads=1")
    }

    // guide-on-iphone-ipad-and-mac/zoom
    func testZoomStepsAndIsKeptAfterARelaunch() throws {
        var app = try launch()
        openGuide(app)
        let zoomIn = app.element("guide.zoomIn")
        let zoomOut = app.element("guide.zoomOut")
        XCTAssertTrue(zoomIn.isEnabled)
        zoomIn.tap()
        XCTAssertFalse(zoomIn.isEnabled, "270 pt is the widest step")
        XCTAssertEqual(columnWidth(app), 270, accuracy: 1)
        zoomOut.tap()
        zoomOut.tap()
        zoomOut.tap()
        XCTAssertFalse(zoomOut.isEnabled, "90 pt is the narrowest step")
        zoomIn.tap()

        app.terminate()
        app = try launch(reset: false)
        openGuide(app)
        XCTAssertEqual(columnWidth(app), 120, accuracy: 1)
        XCTAssertTrue(app.element("guide.zoomOut").isEnabled)
    }

    // guide-on-iphone-ipad-and-mac/zoom, the keys
    func testCommandPlusAndMinusZoom() throws {
        let app = try launch()
        openGuide(app)
        // The simulator sometimes drops the first key press after launch.
        for _ in 0..<3 where columnWidth(app) < 269 {
            app.typeKey("=", modifierFlags: .command)
        }
        XCTAssertEqual(columnWidth(app), 270, accuracy: 1)
        app.typeKey("-", modifierFlags: .command)
        XCTAssertEqual(columnWidth(app), 180, accuracy: 1)
    }

    // guide-on-iphone-ipad-and-mac/filter-channels-by-typing
    func testTheFilterNarrowsTheGroupAfterEachLetter() throws {
        let app = try launch()
        openGuide(app)
        expect(app.element("guide.groupTitle"), "label == 'All channels, 5'")
        let filter = app.element("guide.filter")
        filter.tap()
        filter.typeText("new")
        expect(app.element("guide.groupTitle"), "label == 'All channels, 2'")
        filter.typeText("s t")
        expect(app.element("guide.groupTitle"), "label == 'All channels, 1'")
        XCTAssertTrue(app.element("guide.channel.\(key(1))").exists)
        XCTAssertFalse(app.element("guide.channel.\(key(0))").exists)

        app.element("guide.filter.clear").tap()
        expect(app.element("guide.groupTitle"), "label == 'All channels, 5'")
        filter.tap()
        filter.typeText("3")
        expect(app.element("guide.groupTitle"), "label == 'All channels, 1'")
        XCTAssertTrue(app.element("guide.channel.\(key(2))").exists, "Sport One is number 3")
        app.element("browse.group.2").tap()
        expect(app.element("guide.groupTitle"), "label == 'News, 2'")
        let cleared = app.element("guide.filter").value as? String ?? ""
        XCTAssertTrue(cleared.isEmpty || cleared == "Filter", "another group clears the filter, not \(cleared)")
    }

    // guide-on-iphone-ipad-and-mac/read-about-a-programme
    func testTappingAProgrammeOpensItsDetails() throws {
        let app = try launch()
        openGuide(app)
        let morning = blocks(app, "block", row: 0).firstMatch
        XCTAssertTrue(morning.label.contains("News One, Morning News"), morning.label)
        XCTAssertTrue(morning.label.hasSuffix("on now"), morning.label)
        morning.tap()
        let panel = app.element("guide.panel")
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertEqual(app.element("guide.panel.title").label, "Morning News")
        XCTAssertTrue(app.element("guide.panel.eyebrow").label.uppercased().contains("NOW"))
        XCTAssertTrue(app.element("guide.panel.progress").exists)
        XCTAssertEqual(app.element("guide.panel.summary").label, "Headlines and weather.")
        XCTAssertTrue(app.element("guide.panel.meta").label.contains("1 h"))
        app.element("guide.panel.close").tap()
        expect(panel, "exists == false")
    }

    // guide-on-iphone-ipad-and-mac/read-about-a-programme, with a keyboard
    func testArrowsAndReturnOpenDetails() throws {
        let app = try launch()
        openGuide(app)
        // The simulator sometimes drops the first key press after launch.
        let ring = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'guide.block.' AND selected == true")
        )
        .firstMatch
        for _ in 0..<3 where !ring.exists {
            app.typeKey(.downArrow, modifierFlags: [])
        }
        XCTAssertTrue(ring.label.contains("News One, Morning News"), ring.label)
        app.typeKey("\n", modifierFlags: [])
        XCTAssertTrue(app.element("guide.panel").waitForExistence(timeout: 5))
        XCTAssertEqual(app.element("guide.panel.title").label, "Morning News")
        app.element("guide.panel.close").tap()
        expect(app.element("guide.panel"), "exists == false")
        app.typeKey(.rightArrow, modifierFlags: [])
        app.typeKey("\n", modifierFlags: [])
        XCTAssertTrue(app.element("guide.panel").waitForExistence(timeout: 5))
        XCTAssertEqual(app.element("guide.panel.title").label, "Weather")
    }

    // guide-on-iphone-ipad-and-mac/start-watching-from-the-guide
    func testWatchOpensLiveWithTheChannelPlaying() throws {
        let app = try launch()
        openGuide(app)
        app.waitForEngine("idle loads=0")
        XCTAssertFalse(app.element("guide.nowPlaying").exists, "nothing plays yet")
        blocks(app, "block", row: 0).firstMatch.tap()
        app.element("guide.watch").tap()

        app.waitForEngine("playing loads=1")
        XCTAssertTrue(app.element("browse.section.live").isSelected)
        XCTAssertTrue(app.element("browse.panel.now").waitForExistence(timeout: 5))
        XCTAssertTrue(app.element("browse.panel.now").label.contains("Morning News"))
    }

    // guide-on-iphone-ipad-and-mac/start-watching-from-the-guide, a later programme
    func testWatchOnALaterProgrammePlaysNowAndNotesIt() throws {
        let app = try launch()
        openGuide(app)
        let weather = blocks(app, "block", row: 0).element(boundBy: 1)
        XCTAssertTrue(weather.label.contains("Weather"), weather.label)
        weather.tap()
        app.element("guide.watch").tap()
        app.waitForEngine("playing loads=1")
        let later = app.element("browse.later")
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        XCTAssertTrue(later.label.hasSuffix("Weather"), later.label)
    }

    // guide-on-iphone-ipad-and-mac/playback-carries-on-out-of-sight
    func testPlaybackCarriesOnAndTheChannelNameKeepsIt() throws {
        let app = try launch()
        app.row(0).tap()
        app.waitForEngine("playing loads=1")
        openGuide(app)
        let chip = app.element("guide.nowPlaying")
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertTrue(chip.label.contains("1 News One"), chip.label)
        XCTAssertTrue(chip.label.hasPrefix("Playing"), "the live dot shows while it plays")
        app.waitForEngine("playing loads=1")

        app.element("guide.channel.\(key(0))").tap()
        XCTAssertTrue(app.element("browse.section.live").isSelected)
        app.waitForEngine("playing loads=1")

        openGuide(app)
        app.element("guide.nowPlaying").tap()
        XCTAssertTrue(app.element("browse.section.live").isSelected)
        app.waitForEngine("playing loads=1")
    }

    // guide-on-iphone-ipad-and-mac/a-time-grid-on-ipad-and-mac, the window changes size
    func testNarrowingKeepsTheGroupAndTheDetails() throws {
        let app = try launch(extra: ["-ui-testing-narrow-on-details"])
        openGuide(app)
        app.element("browse.group.2").tap()
        blocks(app, "block", row: 0).firstMatch.tap()
        // The sidebar goes when the window turns narrow, a second after the details open.
        expect(app.element("browse.section.guide"), "exists == false")
        XCTAssertTrue(app.element("guide.panel").waitForExistence(timeout: 5), "the details stay open as a sheet")
        XCTAssertEqual(app.element("guide.panel.title").label, "Morning News")
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(app.element("guide.list").waitForExistence(timeout: 5), "the rows replace the grid")
        XCTAssertTrue(app.element("guide.group.2").isSelected)
    }

    // guide-on-iphone-ipad-and-mac/move-through-the-days
    func testDayChipsAndNow() throws {
        let app = try launch(extra: ["-ui-testing-guide", "days"])
        openGuide(app)
        XCTAssertTrue(app.element("guide.day.0").isSelected)
        XCTAssertEqual(app.element("guide.day.0").label, "Today")
        let tomorrow = app.element("guide.day.1")
        XCTAssertTrue(tomorrow.exists)
        tomorrow.tap()
        expect(tomorrow, "selected == true")
        XCTAssertTrue(blocks(app, "block", row: 2).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(blocks(app, "block", row: 2).firstMatch.label.contains("Tomorrow Match"))
        app.element("guide.now").tap()
        expect(app.element("guide.day.0"), "selected == true")
        XCTAssertTrue(blocks(app, "block", row: 0).firstMatch.label.contains("Morning News"))
    }

    // guide-on-iphone-ipad-and-mac/move-through-the-days, a short guide
    func testAShortGuideListsTodayOnly() throws {
        let app = try launch()
        openGuide(app)
        XCTAssertTrue(app.element("guide.day.0").exists)
        XCTAssertFalse(app.element("guide.day.1").exists)
    }

}

// MARK: Missing guides and empty states

extension GuideRegularUITests {
    // guide-on-iphone-ipad-and-mac/channels-with-gaps-or-no-guide
    func testAFailedGuideGetsABannerWithRetry() throws {
        let app = try launch(extra: ["-ui-testing-guide", "failed"])
        openGuide(app)
        let banner = app.element("guide.banner.failed")
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        XCTAssertEqual(app.element("guide.banner.failed.text").label, "Could not load the guide for Cabin")
        XCTAssertTrue(app.element("guide.failed.\(LiveStatesUITests.cabin).0").exists, "Cabin Film reads Guide unavailable")
        app.element("guide.banner.failed.retry").tap()
        expect(banner, "exists == false")
    }

    // guide-on-iphone-ipad-and-mac/channels-with-gaps-or-no-guide, dismiss
    func testDismissingTheBannerHidesIt() throws {
        let app = try launch(extra: ["-ui-testing-guide", "failed"])
        openGuide(app)
        let banner = app.element("guide.banner.failed")
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        app.element("guide.banner.failed.dismiss").tap()
        expect(banner, "exists == false")
    }

    // guide-on-iphone-ipad-and-mac/channels-with-gaps-or-no-guide, a login still to sync
    func testALoginStillToSyncGetsAWaitingBanner() throws {
        let app = try launch("waiting")
        openGuide(app)
        let banner = app.element("guide.banner.waiting.\(LiveStatesUITests.cabin)")
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        XCTAssertEqual(banner.label, "Cabin: waiting for its login to sync from iCloud")
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: banner)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 20), .completed, "the banner clears once the login arrives")
    }

    // guide-on-iphone-ipad-and-mac/nothing-to-show-yet
    func testAnEmptyGroupKeepsTheToolbar() throws {
        let app = try launch()
        openGuide(app)
        app.element("browse.group.0").tap()
        let empty = app.element("guide.empty")
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        XCTAssertEqual(empty.label, "No channels in Favorites")
        XCTAssertTrue(app.element("guide.toolbar").exists)
        XCTAssertTrue(app.element("guide.zoomIn").isEnabled)
    }

    // guide-on-iphone-ipad-and-mac/nothing-to-show-yet, every source failed
    func testEveryFailedSourceShowsLivesErrorWithoutTheToolbar() throws {
        let app = try launch("offline")
        app.element("browse.section.guide").tap()
        XCTAssertTrue(app.element("browse.error").waitForExistence(timeout: 10))
        XCTAssertTrue(app.element("browse.retry").exists)
        XCTAssertFalse(app.element("guide.toolbar").exists)
    }

    /// The distance between two neighbouring half-hour labels.
    private func columnWidth(_ app: XCUIApplication) -> Double {
        let columns = app.descendants(matching: .any).matching(identifier: "guide.column").allElementsBoundByIndex
            .map(\.frame.minX).sorted()
        guard columns.count > 2 else { return 0 }
        return columns[2] - columns[1]
    }

    private func halfHour(atOrBefore date: Date) -> Date {
        let parts = Calendar.current.dateComponents([.minute, .second, .nanosecond], from: date)
        let seconds = Double((parts.minute ?? 0) % 30) * 60 + Double(parts.second ?? 0) + Double(parts.nanosecond ?? 0) / 1e9
        return date.addingTimeInterval(-seconds)
    }
}
