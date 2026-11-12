import XCTest

/// Reminders on iPhone (programme-reminders capability), on the scripted
/// Live launch: News One has Morning News on now, then Weather and more.
/// The notification center is scripted, so no system prompt appears; it
/// writes "ask" and each notification it schedules to a log.
@MainActor
final class RemindersUITests: XCTestCase {
    nonisolated let log = FileManager.default.temporaryDirectory.appending(path: "reminders-\(UUID().uuidString).log")

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: log)
    }

    private func launch(_ notifications: String = "notDetermined", extra: [String] = [], shelf: Bool = false) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        let app = XCUIApplication()
        app.launchArguments =
            (shelf ? ["-ui-testing-shelf", "titles", "-ui-testing-reduce-motion"] : ["-ui-testing-live", "channels"])
            + ["-ui-testing-notifications", notifications] + extra
        app.launchEnvironment["UITESTING_REMINDER_LOG"] = log.path
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 10))
        return app
    }

    private var logLines: [String] {
        ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    private func expect(_ element: XCUIElement, _ predicate: String, file: StaticString = #filePath, line: UInt = #line) {
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [wait], timeout: 10), .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    private func expectLog(_ check: @escaping ([String]) -> Bool, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in check(self.logLines) }, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 10), .completed, "\(message): \(logLines)", file: file, line: line)
    }

    private func openReminders(_ app: XCUIApplication) {
        app.tabBars.buttons["Settings"].tap()
        let row = app.element("settings.reminders")
        if !row.waitForExistence(timeout: 5) { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.element("reminders.leadTime").waitForExistence(timeout: 5))
    }

    /// Opens Weather's details in the guide: News One's second programme.
    private func openWeather(_ app: XCUIApplication) {
        app.tabBars.buttons["Guide"].tap()
        XCTAssertTrue(app.element("guide.root").waitForExistence(timeout: 10))
        let weather = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "guide.block.\(LiveUITests.home).0."))
            .allElementsBoundByIndex.sorted { $0.frame.minX < $1.frame.minX }[1]
        weather.tap()
        expect(app.element("guide.panel.title"), "label == 'Weather'")
    }

    // programme-reminders/set-a-reminder-in-one-tap
    // programme-reminders/permission-is-asked-only-when-it-is-needed
    // programme-reminders/remind-me-appears-only-before-a-programme-starts
    func testRemindMeInTheGuideSavesThenAsksOnce() throws {
        let app = try launch()
        openWeather(app)
        XCTAssertTrue(logLines.isEmpty, "asked before a reminder was set: \(logLines)")
        let remind = app.element("guide.remind")
        XCTAssertEqual(remind.label, "Remind me")
        remind.tap()
        expect(remind, "label == 'Reminder set'")
        XCTAssertTrue(app.element("guide.panel").exists, "the details closed")
        XCTAssertTrue(app.tabBars.buttons["Guide"].isSelected, "setting a reminder left the guide")
        expectLog({ $0.first == "ask" }, "the prompt never came")
        expectLog({ $0.contains { $0.hasPrefix("schedule Weather | Starts at") } }, "Weather was not scheduled")

        // Off and on again asks no more.
        remind.tap()
        expect(remind, "label == 'Remind me'")
        remind.tap()
        expect(remind, "label == 'Reminder set'")
        XCTAssertEqual(logLines.filter { $0 == "ask" }.count, 1)
    }

    // programme-reminders/remind-me-appears-only-before-a-programme-starts
    func testAProgrammeOnNowOffersNoRemindMe() throws {
        let app = try launch()
        app.tabBars.buttons["Guide"].tap()
        XCTAssertTrue(app.element("guide.root").waitForExistence(timeout: 10))
        let first = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "guide.block.\(LiveUITests.home).0."))
            .allElementsBoundByIndex.sorted { $0.frame.minX < $1.frame.minX }[0]
        first.tap()
        expect(app.element("guide.panel.title"), "label == 'Morning News'")
        XCTAssertTrue(app.element("guide.watch").exists)
        XCTAssertFalse(app.element("guide.remind").exists, "a programme on now offers Remind me")
    }

    // programme-reminders/permission-is-asked-only-when-it-is-needed
    func testDeclinedPermissionKeepsTheReminder() throws {
        let app = try launch(extra: ["-ui-testing-notifications-answer", "deny"])
        openWeather(app)
        app.element("guide.remind").tap()
        expectLog({ $0 == ["ask"] }, "no prompt")
        expect(app.element("guide.remind"), "label == 'Reminder set'")
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(app.element("guide.panel").waitForNonExistence(timeout: 5))
        openReminders(app)
        expect(app.element("reminders.row.0"), "label CONTAINS 'Weather'")
        XCTAssertTrue(app.element("reminders.permissionDenied").exists)
    }

    // programme-reminders/permission-is-asked-only-when-it-is-needed, no early prompt
    // programme-reminders/see-every-upcoming-reminder-in-one-list, no reminders
    // programme-reminders/the-app-says-when-reminders-cannot-notify, not asked yet
    func testTheEmptyPageAsksNothingAndSaysHowToSetOne() throws {
        let app = try launch()
        openReminders(app)
        XCTAssertTrue(app.element("reminders.empty").exists)
        XCTAssertFalse(app.element("reminders.count").exists)
        XCTAssertTrue(app.element("reminders.allowNotifications").exists)
        XCTAssertTrue(logLines.isEmpty, "Settings asked about notifications")
    }

    // programme-reminders/see-every-upcoming-reminder-in-one-list
    // programme-reminders/reminders-follow-a-programme-that-moves
    // programme-reminders/reminders-survive-a-programme-leaving-the-guide
    // programme-reminders/the-app-says-when-reminders-cannot-notify
    func testTheListShowsEachUpcomingReminderSoonestFirst() throws {
        let app = try launch("denied", extra: ["-ui-testing-reminders", "list"])
        app.tabBars.buttons["Settings"].tap()
        expect(app.element("settings.reminders"), "label CONTAINS '3'")
        openReminders(app)
        expect(app.element("reminders.count"), "label == '3'")
        expect(app.element("reminders.row.0"), "label CONTAINS 'Weather'")
        XCTAssertTrue(app.element("reminders.row.0").label.contains("Today"), app.element("reminders.row.0").label)
        XCTAssertTrue(app.element("reminders.row.0.status").label.hasPrefix("Moved from "))
        expect(app.element("reminders.row.1"), "label CONTAINS 'Harbour Talk'")
        XCTAssertEqual(app.element("reminders.row.1.status").label, "No longer in the guide")
        expect(app.element("reminders.row.2"), "label CONTAINS 'Late Film'")
        XCTAssertTrue(app.element("reminders.row.2").label.contains("Tomorrow"), app.element("reminders.row.2").label)
        XCTAssertFalse(app.element("reminders.row.3").exists, "an ended programme is listed")
        XCTAssertTrue(app.element("reminders.permissionDenied").exists)
        XCTAssertTrue(app.element("reminders.openSettings").exists)
    }

    // programme-reminders/remove-a-reminder-anywhere
    func testSwipingRemovesAReminder() throws {
        let app = try launch("allowed", extra: ["-ui-testing-reminders", "list"])
        openReminders(app)
        expect(app.element("reminders.count"), "label == '3'")
        XCTAssertFalse(app.element("reminders.permissionDenied").exists, "the notice shows with notifications allowed")
        app.element("reminders.row.0").swipeLeft()
        app.element("reminders.remove.0").tap()
        expect(app.element("reminders.count"), "label == '2'")
        expect(app.element("reminders.row.0"), "label CONTAINS 'Harbour Talk'")
        expectLog({ $0.contains("remove Weather") }, "Weather's notification stayed")
    }

    // programme-reminders/choose-how-early-reminders-go-off
    func testTheLeadTimeStartsAtFiveMinutes() throws {
        let app = try launch()
        openReminders(app)
        let picker = app.element("reminders.leadTime")
        XCTAssertTrue(picker.label.contains("5 minutes") || picker.value as? String == "5 minutes", picker.label)
        picker.tap()
        let ten = app.buttons["10 minutes"].firstMatch
        XCTAssertTrue(ten.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["At start"].exists)
        XCTAssertTrue(app.buttons["30 minutes"].exists)
        ten.tap()
        expect(picker, "label CONTAINS '10 minutes' OR value == '10 minutes'")
    }

    // programme-reminders/remind-me-appears-only-before-a-programme-starts, in Search
    // search/pick-a-programme, the bell
    func testTheBellInSearchSetsAndRemovesAReminder() throws {
        let app = try launch(shelf: true)
        app.tabBars.buttons["Search"].tap()
        let field = app.element("search.field")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        expect(field, "hasKeyboardFocus == true")
        field.typeText("weather")
        let bell = app.element("search.result.programme.0.remind")
        XCTAssertTrue(bell.waitForExistence(timeout: 5))
        XCTAssertEqual(bell.label, "Remind me")
        bell.tap()
        expect(bell, "label == 'Reminder set'")
        XCTAssertTrue(app.tabBars.buttons["Search"].isSelected, "the bell opened something")
        XCTAssertEqual(app.element("search.field").value as? String, "weather")
        bell.tap()
        expect(bell, "label == 'Remind me'")

        field.tap()
        app.element("search.clear").firstMatch.tap()
        app.element("search.field").typeText("morning")
        XCTAssertTrue(app.element("search.result.programme.0").waitForExistence(timeout: 5))
        XCTAssertFalse(app.element("search.result.programme.0.remind").exists, "a programme on now has a bell")
    }
}
