import XCTest

/// Adult content on iPhone, over `-ui-testing-live channels` with
/// `-ui-testing-adult`: Home adds "XXX Night" in the group "XXX", and the
/// passcode is 2580 (adult-content capability).
@MainActor
final class AdultContentUITests: XCTestCase {
    private func launch() throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "runs on an iPhone")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels", "-ui-testing-adult"]
        app.launchInEnglish()
        XCTAssertTrue(element(app, "browse.list").waitForExistence(timeout: 10), "the channel list never appeared")
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func type(_ app: XCUIApplication, _ digits: String) {
        for digit in digits { element(app, "groups.passcode.key.\(digit)").tap() }
    }

    private func openSettings(_ app: XCUIApplication) -> XCUIElement {
        app.openSettings()
        let toggle = element(app, "settings.adultContent")
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "no Show adult content switch")
        return toggle.switches.firstMatch.exists ? toggle.switches.firstMatch : toggle
    }

    private func expectAllChannels(_ app: XCUIApplication, _ count: Int, file: StaticString = #filePath, line: UInt = #line) {
        app.closeSettings()
        app.tabBars.buttons["Live"].tap()
        let groups = element(app, "browse.groups")
        expectation(for: NSPredicate(format: "label BEGINSWITH %@", "All channels, \(count) channels"), evaluatedWith: groups)
        waitForExpectations(timeout: 10)
    }

    // adult-content/hidden-everywhere-by-default
    func testAdultChannelsAreHiddenByDefault() throws {
        let app = try launch()
        expectAllChannels(app, 5)
        XCTAssertFalse(app.staticTexts["XXX Night"].exists)
        element(app, "browse.groups").tap()
        XCTAssertTrue(element(app, "browse.groups.sheet").waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["XXX"].exists, "the adult group is listed in the Groups sheet")
    }

    // adult-content/show-adult-content-with-the-passcode
    // profiles/what-each-profile-keeps
    func testThePasscodeShowsAdultContentAndSwitchingOffHidesItAgain() throws {
        let app = try launch()
        var toggle = openSettings(app)
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.tap()
        XCTAssertTrue(element(app, "groups.passcode").waitForExistence(timeout: 5))
        type(app, "0000")
        let error = element(app, "groups.passcode.error")
        expectation(for: NSPredicate(format: "label == 'Wrong passcode'"), evaluatedWith: error)
        waitForExpectations(timeout: 5)
        type(app, "2580")
        expectation(for: NSPredicate(format: "value == '1'"), evaluatedWith: toggle)
        waitForExpectations(timeout: 10)
        expectAllChannels(app, 6)
        XCTAssertTrue(
            app.staticTexts["XXX Night"].waitForExistence(timeout: 5)
                || app.buttons.matching(NSPredicate(format: "label CONTAINS 'XXX Night'")).firstMatch.exists)

        toggle = openSettings(app)
        toggle.tap()
        XCTAssertFalse(element(app, "groups.passcode").waitForExistence(timeout: 2), "turning it off asked for the passcode")
        expectation(for: NSPredicate(format: "value == '0'"), evaluatedWith: toggle)
        waitForExpectations(timeout: 5)
        expectAllChannels(app, 5)
    }

    // adult-content/show-adult-content-with-the-passcode
    func testCancellingThePasscodeLeavesItOff() throws {
        let app = try launch()
        let toggle = openSettings(app)
        toggle.tap()
        let cancel = element(app, "groups.passcode.cancel")
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        expectation(for: NSPredicate(format: "value == '0'"), evaluatedWith: toggle)
        waitForExpectations(timeout: 10)
        expectAllChannels(app, 5)
    }
}
