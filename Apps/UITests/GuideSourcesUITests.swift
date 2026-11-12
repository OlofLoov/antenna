import XCTest

/// Settings › Sport Pack › Guide on iPhone, on the `-ui-testing-guide-sources`
/// seed: News Now has a guide, Sport One's id is not in it, Arena HD has no
/// id, and Nordic One HD is matched by name.
@MainActor
final class GuideSourcesUITests: XCTestCase {
    private static let source = "settings.source.00000000-0000-0000-0000-0000000000E1"

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func openGuideSources() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-guide-sources"]
        app.launch()
        let tab = app.tabBars.buttons["Settings"]
        let button = tab.waitForExistence(timeout: 15) ? tab : app.buttons["Settings"].firstMatch
        button.tap()
        let source = element(app, Self.source)
        XCTAssertTrue(source.waitForExistence(timeout: 10))
        source.tap()
        let guide = element(app, "settings.details.guide.sources")
        if !guide.waitForExistence(timeout: 5) { app.swipeUp() }
        XCTAssertTrue(guide.waitForExistence(timeout: 5))
        guide.tap()
        return app
    }

    /// Waits for the header to read "Channels without guide · <count>".
    private func expectHeader(_ app: XCUIApplication, count: Int) {
        let header = element(app, "guideSources.channels.header")
        expectation(for: NSPredicate(format: "label == %@", "Channels without guide · \(count)"), evaluatedWith: header)
        waitForExpectations(timeout: 15)
    }

    private func scrollTo(_ app: XCUIApplication, _ item: XCUIElement) {
        for _ in 0..<4 where !item.isHittable { app.swipeUp() }
    }

    // guide-sources-and-channel-mapping/find-the-channels-without-a-guide
    func testChannelsWithoutAGuideShowWithReasons() {
        let app = openGuideSources()
        expectHeader(app, count: 2)
        XCTAssertTrue(element(app, "guideSources.row.0.status").label.hasPrefix("Loaded · 2 of 4 channels"))
        let first = element(app, "guideSources.channels.row.0")
        XCTAssertTrue(first.label.contains("Sport One"), first.label)
        XCTAssertTrue(first.label.contains("Id not found"), first.label)
        let second = element(app, "guideSources.channels.row.1")
        XCTAssertTrue(second.label.contains("Arena HD"), second.label)
        XCTAssertTrue(second.label.contains("No guide id"), second.label)
        let named = element(app, "guideSources.named.header")
        scrollTo(app, named)
        XCTAssertEqual(named.label, "Matched by name · 1")
        XCTAssertTrue(element(app, "guideSources.named.row.0").label.contains("Nordic One HD"))

        let filter = element(app, "guideSources.channels.filter")
        scrollTo(app, filter)
        filter.tap()
        filter.typeText("arena")
        XCTAssertTrue(element(app, "guideSources.channels.row.0").label.contains("Arena HD"))
        XCTAssertFalse(element(app, "guideSources.channels.row.1").exists)
        XCTAssertEqual(element(app, "guideSources.channels.header").label, "Channels without guide · 2")
    }

    // guide-sources-and-channel-mapping/pick-the-right-guide-entry-by-hand
    // guide-sources-and-channel-mapping/undo-a-hand-picked-match
    func testPickingAnEntryMapsTheChannelAndRemovingItUndoes() {
        let app = openGuideSources()
        expectHeader(app, count: 2)
        element(app, "guideSources.channels.row.0").tap()
        XCTAssertEqual(element(app, "guideSources.reason.title").label, "Guide id “sport1” is not in the guide")
        let field = element(app, "guideSources.picker.field")
        XCTAssertEqual(field.value as? String, "Sport One")
        let top = element(app, "guideSources.picker.row.0")
        XCTAssertTrue(top.waitForExistence(timeout: 5))
        XCTAssertTrue(top.label.contains("sportone · From the playlist · 1 programme"), top.label)
        top.tap()

        let title = element(app, "guideSources.reason.title")
        expectation(for: NSPredicate(format: "label == %@", "Guide from From the playlist"), evaluatedWith: title)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(element(app, "guideSources.reason.body").label.contains("Mapped by you"))

        element(app, "guideSources.removeMatch").tap()
        expectation(for: NSPredicate(format: "label == %@", "Guide id “sport1” is not in the guide"), evaluatedWith: title)
        waitForExpectations(timeout: 10)
        app.navigationBars.buttons.firstMatch.tap()
        expectHeader(app, count: 2)
    }

    // guide-sources-and-channel-mapping/channels-matched-by-name
    func testUndoingAMatchByNameListsTheChannel() {
        let app = openGuideSources()
        expectHeader(app, count: 2)
        let named = element(app, "guideSources.named.row.0")
        scrollTo(app, named)
        named.tap()
        XCTAssertTrue(element(app, "guideSources.reason.body").label.contains("Matched by name"))
        element(app, "guideSources.removeMatch").tap()
        let title = element(app, "guideSources.reason.title")
        expectation(for: NSPredicate(format: "label == %@", "The source gives this channel no guide id"), evaluatedWith: title)
        waitForExpectations(timeout: 10)
        app.navigationBars.buttons.firstMatch.tap()
        expectHeader(app, count: 3)
    }

    // guide-sources-and-channel-mapping/add-a-guide-link
    func testAddingAGuideLinkChecksItAndAddsItLast() {
        let app = openGuideSources()
        expectHeader(app, count: 2)
        element(app, "guideSources.add").tap()
        let field = element(app, "guideSources.addForm.field")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("not a link")
        element(app, "guideSources.addForm.save").tap()
        let error = element(app, "guideSources.addForm.error")
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertEqual(error.label, "Enter a valid URL.")

        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) + "http://guide-sources.invalid/epg.xml")
        element(app, "guideSources.addForm.save").tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))

        let added = element(app, "guideSources.row.1")
        XCTAssertTrue(added.waitForExistence(timeout: 5))
        XCTAssertTrue(added.label.contains("guide-sources.invalid"), added.label)
    }
}
