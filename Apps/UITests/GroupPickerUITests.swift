import XCTest

/// The group button and the Groups sheet on iPhone (`iPhone-Live-Groups`,
/// `iPhone-Live-Groups-Search`). Uses the scripted launch of `LiveUITests`:
/// Favorites, All channels, News, Sport, Ungrouped, then Cabin's Films.
@MainActor
final class GroupPickerUITests: XCTestCase {
    nonisolated let log = FileManager.default.temporaryDirectory.appending(path: "live-engine-\(UUID().uuidString).log")

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: log)
    }

    private func launch(_ arguments: [String] = []) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the group button and sheet are on iPhone")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"] + arguments
        app.launchEnvironment["UITESTING_ENGINE_LOG"] = log.path
        app.launchInEnglish()
        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 15), "the channel list never appeared")
        return app
    }

    private func openSheet(_ app: XCUIApplication) {
        app.element("browse.groups").tap()
        XCTAssertTrue(app.element("browse.groups.sheet").waitForExistence(timeout: 5), "no Groups sheet")
    }

    private func search(_ app: XCUIApplication, _ text: String) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "no search field in the sheet")
        field.tap()
        field.typeText(text)
    }

    private var loaded: [String] {
        ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    // live-tv-on-iphone-ipad-mac/pick-a-group, opening the Groups sheet
    // live-tv-on-iphone-ipad-mac/find-a-group-among-many
    func testSearchingAndPickingAGroupChangesTheList() throws {
        let app = try launch()
        app.row(0).tap()
        app.waitForEngine("playing loads=1")
        XCTAssertTrue(app.row(3).exists, "All channels lists Kids One")

        openSheet(app)
        let all = app.element("browse.group.1")
        XCTAssertTrue(all.isSelected, "All channels has the checkmark")
        XCTAssertEqual(all.label, "All channels, 5 channels")
        XCTAssertEqual(all.frame.height, 44, accuracy: 4, "one line per group, so the medium detent shows about eight")
        XCTAssertEqual(app.element("browse.group.3").label, "Sport, 1 channel")
        XCTAssertFalse(app.element("browse.group.3").isSelected)

        search(app, "SPO")
        XCTAssertTrue(app.element("browse.group.2").waitForNonExistence(timeout: 5), "News does not match")
        XCTAssertTrue(app.element("browse.group.3").exists)
        app.element("browse.group.3").tap()

        XCTAssertTrue(app.element("browse.groups.sheet").waitForNonExistence(timeout: 5), "picking closes the sheet")
        app.expectOpenGroup("Sport", row: "browse.group.3")
        XCTAssertTrue(app.row(2).waitForExistence(timeout: 5))
        XCTAssertFalse(app.row(0).exists, "News One is not in Sport")
        XCTAssertFalse(app.row(3).exists, "Kids One is not in Sport")
        app.waitForEngine("playing loads=1")
        XCTAssertEqual(loaded, ["news-one.ts"], "the channel keeps playing")
    }

    // live-tv-on-iphone-ipad-mac/find-a-group-among-many, nothing matches
    func testASearchWithNoMatchSaysSoAndClearingBringsTheGroupsBack() throws {
        let app = try launch()
        openSheet(app)
        search(app, "cricket")
        XCTAssertTrue(app.element("browse.groups.empty").waitForExistence(timeout: 5))
        XCTAssertFalse(app.element("browse.group.0").exists)
        app.searchFields.firstMatch.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "cricket".count))
        XCTAssertTrue(app.element("browse.group.0").waitForExistence(timeout: 5))
        XCTAssertFalse(app.element("browse.groups.empty").exists)
    }

    // live-tv-on-iphone-ipad-mac/pick-a-group, opening the Groups sheet
    func testClosingTheSheetKeepsTheGroup() throws {
        let app = try launch()
        app.pickGroup("browse.group.2")
        openSheet(app)
        XCTAssertTrue(app.element("browse.group.2").isSelected)
        app.closeGroups()
        app.expectOpenGroup("News", row: "browse.group.2")
        XCTAssertTrue(app.row(1).exists)
    }

    // live-tv-on-iphone-ipad-mac/pick-a-group, VoiceOver on the group button
    // live-tv-on-iphone-ipad-mac/find-a-group-among-many, VoiceOver on the group button
    func testTheGroupButtonReadsItsNameAndCount() throws {
        let app = try launch()
        let button = app.element("browse.groups")
        XCTAssertEqual(button.label, "All channels, 5 channels")
        XCTAssertTrue(button.elementType == .button)
    }

    // live-tv-on-iphone-ipad-mac/find-a-group-among-many, hundreds of groups
    func testTwoHundredGroupsScrollAndSearch() throws {
        let app = try launch(["-ui-testing-many-groups"])
        XCTAssertEqual(app.element("browse.groups").label, "All channels, 405 channels")
        openSheet(app)
        // Home's News and Sport, its 200 groups at 4 to 203, then Ungrouped and Films.
        let last = app.element("browse.group.203")
        let sheet = app.element("browse.groups.sheet")
        var swipes = 0
        while !(last.exists && last.isHittable), swipes < 40 {
            sheet.swipeUp(velocity: .fast)
            swipes += 1
        }
        XCTAssertTrue(last.isHittable, "the end of the list never came into view")
        XCTAssertEqual(last.label, "UK ▸ NEWS 200, 2 channels")
        XCTAssertTrue(app.element("browse.group.205").exists, "Films follows")

        search(app, "kids 137")
        let found = app.element("browse.group.140")
        XCTAssertTrue(found.waitForExistence(timeout: 5))
        XCTAssertEqual(found.label, "SE | KIDS 137, 2 channels")
        XCTAssertFalse(app.element("browse.group.139").exists)
        found.tap()
        app.expectOpenGroup("SE | KIDS 137", row: "browse.group.140")
        XCTAssertTrue(app.row(276).waitForExistence(timeout: 5))
        XCTAssertTrue(app.row(277).exists)

        // The sheet opens on the open group, far down the list.
        openSheet(app)
        let open = app.element("browse.group.140")
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        XCTAssertTrue(open.isHittable, "the open group is in view")
        XCTAssertTrue(open.isSelected)
    }
}
