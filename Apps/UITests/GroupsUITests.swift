import XCTest

/// The Groups screen and the passcode prompt on iPhone and iPad.
@MainActor
final class GroupsUITests: XCTestCase {
    private static let sport = "groups.row.named.00000000-0000-0000-0000-0000000000D1.Sport"
    private static let news = "groups.row.named.00000000-0000-0000-0000-0000000000D1.News"

    private func openGroups(_ arguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"] + arguments
        app.launch()
        let tab = app.tabBars.buttons["Settings"]
        let button = tab.waitForExistence(timeout: 10) ? tab : app.buttons["Settings"].firstMatch
        button.tap()
        let row = element(app, "settings.groups")
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func type(_ app: XCUIApplication, _ digits: String) {
        for digit in digits { element(app, "groups.passcode.key.\(digit)").tap() }
    }

    // group-management/unlock-with-the-passcode
    func testTheGroupsScreenAsksForThePasscodeFirst() {
        let app = openGroups(["-ui-testing-groups", "locked"])
        XCTAssertTrue(element(app, "groups.passcode").waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, Self.news).exists)
        type(app, "0000")
        let error = element(app, "groups.passcode.error")
        expectation(for: NSPredicate(format: "label == 'Wrong passcode'"), evaluatedWith: error)
        waitForExpectations(timeout: 5)
        type(app, "2580")
        XCTAssertTrue(element(app, Self.sport + ".locked").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, Self.news).exists)
    }

    // group-management/reset-a-forgotten-passcode
    func testForgotPasscodeSetsANewOneAndKeepsTheLocks() {
        let app = openGroups(["-ui-testing-groups", "locked", "-ui-testing-groups-owner"])
        let forgot = element(app, "groups.passcode.forgot")
        XCTAssertTrue(forgot.waitForExistence(timeout: 10))
        forgot.tap()
        let one = app.descendants(matching: .any).matching(identifier: "groups.passcode.key.1")
        expectation(for: NSPredicate(format: "count == 2"), evaluatedWith: one)
        waitForExpectations(timeout: 5)
        for _ in 0..<8 { one.element(boundBy: 1).tap() }
        XCTAssertTrue(element(app, Self.sport + ".locked").waitForExistence(timeout: 10))
    }

    // group-management/lock-a-group-with-a-passcode
    func testLockingTheFirstGroupSetsThePasscode() {
        let app = openGroups()
        let news = element(app, Self.news)
        XCTAssertTrue(news.waitForExistence(timeout: 10))
        news.tap()
        let lock = element(app, "groups.lock")
        XCTAssertTrue(lock.waitForExistence(timeout: 5))
        lock.switches.firstMatch.tap()
        XCTAssertTrue(element(app, "groups.passcode").waitForExistence(timeout: 5))
        type(app, "1234")
        type(app, "4321")
        let error = element(app, "groups.passcode.error")
        expectation(for: NSPredicate(format: "label CONTAINS 'did not match'"), evaluatedWith: error)
        waitForExpectations(timeout: 5)
        type(app, "1234")
        type(app, "1234")
        expectation(for: NSPredicate(format: "value == '1'"), evaluatedWith: lock.switches.firstMatch)
        waitForExpectations(timeout: 5)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(element(app, Self.news + ".locked").waitForExistence(timeout: 5))
    }

    // group-management/build-your-own-group-from-any-playlist
    func testAnOwnGroupTakesChannelsFromTwoPlaylists() {
        let app = openGroups()
        let new = element(app, "groups.new")
        XCTAssertTrue(new.waitForExistence(timeout: 10))
        new.tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("Weekend")
        app.alerts.buttons["Create"].tap()
        let own = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'groups.row.own.'")).firstMatch
        XCTAssertTrue(own.waitForExistence(timeout: 5))
        XCTAssertTrue(own.identifier.hasSuffix(".custom"))
        own.tap()
        element(app, "groups.addChannels").tap()
        let sportOne = element(app, "groups.picker.row.00000000-0000-0000-0000-0000000000D1.2")
        let cabinFilm = element(app, "groups.picker.row.00000000-0000-0000-0000-0000000000D2.0")
        XCTAssertTrue(sportOne.waitForExistence(timeout: 5))
        sportOne.tap()
        cabinFilm.tap()
        element(app, "groups.picker.done").tap()
        XCTAssertTrue(element(app, "groups.member.00000000-0000-0000-0000-0000000000D1.2").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "groups.member.00000000-0000-0000-0000-0000000000D2.0").exists)
    }
}
