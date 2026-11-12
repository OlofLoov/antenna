import XCTest

/// What the app does once a Siri or Shortcuts action brought it forward.
/// Siri cannot be driven from a UI test, so `-ui-testing-intent` hands the
/// app the request an action leaves (`UITestingIntents`), on the scripted
/// Live sources of `-ui-testing-live`.
@MainActor
final class IntentRequestUITests: XCTestCase {
    static let home = "00000000-0000-0000-0000-0000000000D1"
    nonisolated let log = FileManager.default.temporaryDirectory.appending(path: "intent-engine-\(UUID().uuidString).log")

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: log)
    }

    private func launch(_ request: String) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels", "-ui-testing-intent", request]
        app.launchEnvironment["UITESTING_ENGINE_LOG"] = log.path
        app.launch()
        return app
    }

    private var loaded: [String] {
        ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    // app-intents/tune-a-channel-by-voice-or-shortcut
    func testTuneChannelPlaysOnLive() throws {
        let app = try launch("tune:\(Self.home)/fixture/news-two")
        let probe = element(app, "browse.debug.engine")
        let playing = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'playing loads=1'"), object: probe)
        XCTAssertEqual(XCTWaiter().wait(for: [playing], timeout: 15), .completed, "engine is \(probe.value as? String ?? "missing")")
        XCTAssertEqual(loaded, ["news-two.ts"])
        XCTAssertTrue(app.tabBars.buttons["Live"].isSelected)
        XCTAssertTrue(element(app, "browse.nowPlaying").exists)
    }

    // app-intents/open-search
    func testOpenSearchWithAQueryShowsResults() throws {
        let app = try launch("search:news")
        let field = element(app, "search.field")
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        let typed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'news'"), object: field)
        XCTAssertEqual(XCTWaiter().wait(for: [typed], timeout: 10), .completed)
        XCTAssertTrue(element(app, "search.chips").waitForExistence(timeout: 10), "no results showed")
        XCTAssertTrue(app.tabBars.buttons["Search"].isSelected)
    }

    // app-intents/open-search
    func testOpenSearchWithoutAQueryFocusesAnEmptyField() throws {
        let app = try launch("search")
        let field = element(app, "search.field")
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Search"].isSelected)
        XCTAssertFalse(element(app, "search.chips").exists)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "the field is not focused")
    }
}
