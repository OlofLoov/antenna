import XCTest

/// Importing a playlist file. The system picker and share sheet cannot be
/// driven from here, so `-ui-testing-import-file` and `-ui-testing-open-file`
/// hand fixture files to the same code a picked or shared file goes through.
@MainActor
final class FileImportUITests: XCTestCase {
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// The Settings tab on iPhone, the sidebar's Sources & Settings on iPad.
    private func tapSettings(_ app: XCUIApplication) {
        let tab = app.tabBars.buttons["Settings"]
        if tab.waitForExistence(timeout: 10) {
            tab.tap()
        } else {
            element(app, "browse.section.settings").tap()
        }
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    /// Opens Settings in the `channels` scenario and taps Import a file.
    private func importFromSettings(_ fixtures: String) -> XCUIApplication {
        let app = launch(["-ui-testing-live", "channels", "-ui-testing-import-file", fixtures])
        tapSettings(app)
        let pick = element(app, "import.pickFile")
        XCTAssertTrue(pick.waitForExistence(timeout: 10))
        pick.tap()
        XCTAssertTrue(element(app, "import.sheet").waitForExistence(timeout: 10))
        return app
    }

    // local-m3u-file-import/see-what-s-in-the-file-before-importing
    // local-m3u-file-import/import-and-watch
    func testImportAGoodFileAddsItsChannels() {
        let app = importFromSettings("good")
        let channels = element(app, "import.summary.channels")
        XCTAssertTrue(channels.waitForExistence(timeout: 10))
        XCTAssertTrue(channels.label.contains("3 channels in 2 groups"), channels.label)
        XCTAssertTrue(element(app, "import.summary.guide").label.contains("guide.import.test"))
        XCTAssertTrue(element(app, "import.summary.skipped").label.contains("1 entry skipped"))
        XCTAssertEqual(element(app, "import.field.name").value as? String, "home-playlist")
        XCTAssertEqual(element(app, "import.field.guideURL").value as? String, "http://guide.import.test/epg.xml")
        XCTAssertFalse(element(app, "import.replace").exists)
        app.buttons["import.import"].tap()
        XCTAssertTrue(element(app, "import.sheet").waitForNonExistence(timeout: 10))
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'home-playlist'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "label CONTAINS '3 channels'"), evaluatedWith: row)
        waitForExpectations(timeout: 10)
    }

    // local-m3u-file-import/a-file-too-large-is-refused-before-it-is-read
    func testATooLargeFileIsRefusedAndAnotherCanBePicked() {
        let app = importFromSettings("big,good")
        let error = element(app, "import.error")
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        // The size reads "41.7 MB" or "41,7 MB" by the simulator's region.
        XCTAssertTrue(error.label.hasPrefix("This file is 41"), error.label)
        XCTAssertTrue(error.label.contains("16 MB"), error.label)
        XCTAssertFalse(app.buttons["import.import"].isEnabled)
        element(app, "import.pickFile").tap()
        XCTAssertTrue(element(app, "import.summary.channels").waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["import.import"].isEnabled)
    }

    // local-m3u-file-import/a-file-that-is-not-a-channel-list-is-explained
    func testRefusedKindsSayWhatTheyAre() {
        let app = importFromSettings("empty,links,stream")
        let expected = [
            "No channels found in channels.txt.", "This file is a list of links, not a playlist.",
            "This is a single stream, not a channel list.",
        ]
        for (index, title) in expected.enumerated() {
            let error = element(app, "import.error")
            XCTAssertTrue(error.waitForExistence(timeout: 10))
            let shows = NSPredicate(format: "label CONTAINS %@", title)
            expectation(for: shows, evaluatedWith: error)
            waitForExpectations(timeout: 10)
            XCTAssertFalse(app.buttons["import.import"].isEnabled)
            if index < expected.count - 1 { element(app, "import.pickFile").tap() }
        }
    }

    // local-m3u-file-import/a-file-that-is-not-a-channel-list-is-explained
    func testAFileWithOneLinkOffersToAddIt() {
        let app = importFromSettings("link")
        let add = element(app, "import.addAsURL")
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        XCTAssertEqual(add.label, "Add the link as a source")
        add.tap()
        let playlist = element(app, "onboarding.field.playlist")
        XCTAssertTrue(playlist.waitForExistence(timeout: 10))
        XCTAssertEqual(playlist.value as? String, "http://playlist.import.test/tv.m3u")
    }

    // local-m3u-file-import/bring-a-file-in
    func testAFileOpenedWithAntennaOpensTheSheet() {
        let app = launch(["-ui-testing-live", "channels", "-ui-testing-open-file", "good"])
        XCTAssertTrue(element(app, "import.summary.channels").waitForExistence(timeout: 15))
        element(app, "import.cancel").tap()
        XCTAssertTrue(element(app, "import.sheet").waitForNonExistence(timeout: 10))
    }

    /// Imports `good` from Settings and returns the new source's row.
    private func importGood(_ app: XCUIApplication) -> XCUIElement {
        XCTAssertTrue(element(app, "import.summary.channels").waitForExistence(timeout: 10))
        app.buttons["import.import"].tap()
        XCTAssertTrue(element(app, "import.sheet").waitForNonExistence(timeout: 10))
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'home-playlist'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        return row
    }

    // local-m3u-file-import/re-import-onto-the-same-source
    func testReimportReplacesTheChannels() {
        let app = importFromSettings("good,newer")
        let row = importGood(app)
        row.tap()
        let reimport = element(app, "import.reimport")
        XCTAssertTrue(reimport.waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "settings.details.refresh").exists, "a file source has no Refresh")
        reimport.tap()
        XCTAssertTrue(element(app, "import.summary.channels").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "import.summary.channels").label.contains("4 channels"))
        XCTAssertFalse(element(app, "import.field.name").exists)
        XCTAssertFalse(element(app, "import.replace").exists)
        XCTAssertEqual(app.buttons["import.import"].label, "Replace")
        app.buttons["import.import"].tap()
        XCTAssertTrue(element(app, "import.sheet").waitForNonExistence(timeout: 10))
        let status = element(app, "settings.details.status")
        expectation(for: NSPredicate(format: "label CONTAINS '4 channels'"), evaluatedWith: status)
        waitForExpectations(timeout: 10)
    }

    // local-m3u-file-import/see-what-s-in-the-file-before-importing
    func testTheSameFileNameAsksToReplaceOrImportAsNew() {
        let app = importFromSettings("good,good")
        _ = importGood(app)
        element(app, "import.pickFile").tap()
        let before = element(app, "import.importedBefore")
        XCTAssertTrue(before.waitForExistence(timeout: 10))
        XCTAssertTrue(before.label.contains("You imported home-playlist.m3u before as home-playlist"), before.label)
        XCTAssertEqual(app.buttons["import.replace"].label, "Replace home-playlist")
        XCTAssertEqual(app.buttons["import.import"].label, "Import as new")
    }

    private func openSettings(_ arguments: [String]) -> XCUIApplication {
        let app = launch(["-ui-testing-live", "channels"] + arguments)
        tapSettings(app)
        XCTAssertTrue(element(app, "settings.addSource").waitForExistence(timeout: 10))
        return app
    }

    // local-m3u-file-import/drop-a-file-on-the-window
    func testDroppingAFileOpensTheSheet() {
        let app = openSettings(["-ui-testing-drop", "good"])
        let target = element(app, "import.dropTarget")
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        XCTAssertTrue(target.label.contains("Drop to import home-playlist.m3u"), target.label)
        XCTAssertTrue(target.label.contains("M3U, M3U8 and text files, up to 16 MB"), target.label)
        target.tap()
        XCTAssertTrue(element(app, "import.summary.channels").waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "import.dropTarget").exists)
    }

    // local-m3u-file-import/drop-a-file-on-the-window
    func testDraggingAnImageOrTextShowsNoTarget() {
        for item in ["image", "text"] {
            let app = openSettings(["-ui-testing-drop", item])
            XCTAssertFalse(element(app, "import.dropTarget").waitForExistence(timeout: 3), item)
            app.terminate()
        }
    }

    // local-m3u-file-import/import-during-onboarding
    func testImportAFileInsteadDuringOnboarding() {
        let app = launch(["-ui-testing-onboarding", "connect", "-ui-testing-import-file", "good"])
        XCTAssertTrue(element(app, "onboarding.addSource").waitForExistence(timeout: 10))
        element(app, "onboarding.addSource").tap()
        app.chooseKind("M3U playlist")
        let pick = element(app, "import.pickFile")
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()
        let importButton = app.buttons["import.import"]
        XCTAssertTrue(element(app, "import.summary.channels").waitForExistence(timeout: 10))
        importButton.tap()
        let line = element(app, "onboarding.line.playlist")
        XCTAssertTrue(line.waitForExistence(timeout: 10))
        XCTAssertTrue(line.label.contains("Playlist imported"), line.label)
        XCTAssertTrue(line.label.contains("home-playlist.m3u"), line.label)
        XCTAssertTrue(app.buttons["onboarding.primary"].waitForExistence(timeout: 10))
    }
}
