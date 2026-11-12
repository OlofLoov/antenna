import XCTest

/// The reminder banner and Watch on iPhone (programme-reminders capability),
/// on the scripted Live launch with Kick-off on News One two minutes after
/// launch, due at once with the five-minute lead time.
@MainActor
final class ReminderBannerUITests: XCTestCase {
    nonisolated let log = FileManager.default.temporaryDirectory.appending(path: "reminder-banner-\(UUID().uuidString).log")
    nonisolated let engine = FileManager.default.temporaryDirectory.appending(path: "reminder-engine-\(UUID().uuidString).log")

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: log)
        try? FileManager.default.removeItem(at: engine)
    }

    private func launch(
        _ notifications: String = "denied", seed: String = "due", environment: [String: String] = [:]
    ) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels", "-ui-testing-notifications", notifications, "-ui-testing-reminders", seed]
        app.launchEnvironment["UITESTING_REMINDER_LOG"] = log.path
        app.launchEnvironment["UITESTING_ENGINE_LOG"] = engine.path
        for (key, value) in environment { app.launchEnvironment[key] = value }
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Live"].waitForExistence(timeout: 10))
        return app
    }

    private func expect(_ element: XCUIElement, _ predicate: String, file: StaticString = #filePath, line: UInt = #line) {
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [wait], timeout: 10), .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    private var logLines: [String] {
        ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    // programme-reminders/a-banner-while-antenna-is-open
    // programme-reminders/watch-plays-the-channel, a channel outside the current group
    func testTheBannerShowsOverAnyScreenAndWatchPlaysInAllChannels() throws {
        let app = try launch()
        // Sport, which lacks News One.
        let sport = app.element("browse.group.3")
        XCTAssertTrue(sport.waitForExistence(timeout: 10))
        sport.tap()
        expect(sport, "isSelected == true")
        app.tabBars.buttons["Settings"].tap()
        let banner = app.element("reminders.banner")
        XCTAssertTrue(banner.waitForExistence(timeout: 10), "no banner")
        XCTAssertEqual(app.element("reminders.banner.title").label, "Kick-off")
        XCTAssertTrue(app.element("reminders.banner.body").label.hasSuffix("1 News One"), app.element("reminders.banner.body").label)
        app.element("reminders.banner.watch").tap()
        XCTAssertTrue(app.tabBars.buttons["Live"].isSelected)
        expect(app.element("browse.nowPlaying"), "label CONTAINS 'News One'")
        expect(app.element("browse.group.1"), "isSelected == true")
        XCTAssertFalse(banner.exists)
    }

    // programme-reminders/watch-plays-the-channel, one already playing
    func testWatchLeavesAPlayingChannelAlone() throws {
        let app = try launch()
        XCTAssertTrue(app.element("reminders.banner").waitForExistence(timeout: 10))
        app.row(0).tap()
        app.waitForEngine("playing loads=1")
        app.element("reminders.banner.watch").tap()
        expect(app.element("browse.nowPlaying"), "label CONTAINS 'News One'")
        app.waitForEngine("playing loads=1")
    }

    // programme-reminders/watch-plays-the-channel, the channel cannot be found
    func testWatchOnAMissingChannelOpensLiveAndPlaysNothing() throws {
        let app = try launch(seed: "missing")
        app.tabBars.buttons["Guide"].tap()
        XCTAssertTrue(app.element("reminders.banner").waitForExistence(timeout: 10))
        app.element("reminders.banner.watch").tap()
        XCTAssertTrue(app.tabBars.buttons["Live"].isSelected)
        XCTAssertFalse(app.element("browse.nowPlaying").waitForExistence(timeout: 3), "something plays")
    }

    // programme-reminders/a-banner-while-antenna-is-open, close the banner
    func testTheBannerClosesOnDismiss() throws {
        let app = try launch()
        let banner = app.element("reminders.banner")
        XCTAssertTrue(banner.waitForExistence(timeout: 10))
        app.element("reminders.banner.dismiss").tap()
        XCTAssertTrue(banner.waitForNonExistence(timeout: 5))
    }

    // programme-reminders/a-banner-while-antenna-is-open, close the banner after a short time
    func testTheBannerClosesByItself() throws {
        let app = try launch(seed: "soon", environment: ["UITESTING_REMINDER_BANNER_SECONDS": "3"])
        let shown = app.element("reminders.banner")
        XCTAssertTrue(shown.waitForExistence(timeout: 20))
        XCTAssertTrue(shown.waitForNonExistence(timeout: 10), "the banner stayed")
    }

    // programme-reminders/a-banner-while-antenna-is-open, only when notifications are off
    // programme-reminders/a-notification-before-the-programme-starts, set closer to start than the lead time
    func testWithNotificationsAllowedTheNotificationGoesOffInstead() throws {
        let app = try launch("allowed")
        let deadline = Date.now.addingTimeInterval(10)
        while !logLines.contains(where: { $0.hasPrefix("schedule Kick-off | Starts at ") }), Date.now < deadline {
            _ = app.element("reminders.banner").waitForExistence(timeout: 0.5)
        }
        XCTAssertTrue(logLines.contains { $0.hasPrefix("schedule Kick-off | Starts at ") && $0.hasSuffix("on News One") }, "\(logLines)")
        XCTAssertFalse(app.element("reminders.banner").exists, "a banner as well as the notification")
    }

    // programme-reminders/watch-plays-the-channel, from a notification
    func testTappingTheNotificationPlaysTheChannel() throws {
        let app = try launch("allowed", environment: ["UITESTING_REMINDER_OPEN": "4"])
        app.tabBars.buttons["Settings"].tap()
        expect(app.element("browse.nowPlaying"), "label CONTAINS 'News One'")
        XCTAssertTrue(app.tabBars.buttons["Live"].isSelected)
    }

    // programme-reminders/a-banner-while-antenna-is-open, on iPad
    func testOnIPadTheBannerSitsTopTrailingAndWatchPlays() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "the columns run on an iPad")
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels", "-ui-testing-notifications", "denied", "-ui-testing-reminders", "due"]
        app.launchEnvironment["UITESTING_ENGINE_LOG"] = engine.path
        app.launch()
        let banner = app.element("reminders.banner")
        XCTAssertTrue(banner.waitForExistence(timeout: 15))
        XCTAssertEqual(banner.frame.width, 400, accuracy: 1)
        XCTAssertEqual(banner.frame.maxX, app.windows.firstMatch.frame.maxX - 16, accuracy: 1)
        app.element("reminders.banner.watch").tap()
        expect(app.element("browse.panel.now"), "label CONTAINS 'News One'")
    }
}
