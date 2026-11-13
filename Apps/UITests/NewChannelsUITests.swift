import XCTest

/// The New group on iPhone, iPad and Mac (new-channels capability), on
/// `-ui-testing-live channels`. `UITESTING_NEW_CHANNEL` names the channel
/// Home gained since a load the day before (`UITestingRecents`).
@MainActor
final class NewChannelsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func launch(newChannel: String?, recents: String? = nil) -> XCUIApplication {
        // The iPad sidebar lists the groups in a landscape window.
        if UIDevice.current.userInterfaceIdiom == .pad { XCUIDevice.shared.orientation = .landscapeLeft }
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"]
        if let newChannel { app.launchEnvironment["UITESTING_NEW_CHANNEL"] = newChannel }
        if let recents { app.launchEnvironment["UITESTING_RECENTS"] = recents }
        app.launch()
        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 10), "the channel list never appeared")
        return app
    }

    /// The rows of the open list, top to bottom, by identifier.
    func rows(_ app: XCUIApplication) -> [String] {
        let rows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'browse.row.'"))
        return rows.allElementsBoundByIndex.filter(\.isHittable).sorted { $0.frame.minY < $1.frame.minY }.map(\.identifier)
    }

    // new-channels/a-new-group-lists-channels-added-lately
    func testNewSitsAfterRecentsAndListsTheGainedChannel() {
        let app = launch(newChannel: "kids-one", recents: "sport-one")
        let new = app.element("groups.new")
        XCTAssertTrue(new.waitForExistence(timeout: 10))
        XCTAssertTrue(new.label.hasPrefix("New, 1 channel"), "label is \(new.label)")
        XCTAssertTrue(app.element("browse.group.1").label.hasPrefix("Recents"))
        XCTAssertTrue(app.element("browse.group.3").label.hasPrefix("All channels"))
        new.tap()
        XCTAssertEqual(rows(app), ["browse.row.\(LiveUITests.home).3"], "only Kids One; the channels seen before stay out")
    }

    // new-channels/a-new-source-starts-with-nothing-new
    func testAFirstLoadHasNoNewGroup() {
        let app = launch(newChannel: nil)
        XCTAssertTrue(app.element("browse.group.1").waitForExistence(timeout: 5))
        XCTAssertTrue(app.element("browse.group.1").label.hasPrefix("All channels"))
        XCTAssertFalse(app.element("groups.new").exists)
    }
}
