import XCTest

/// Top Shelf tile links on Apple TV. `-antenna.openURL <url>` delivers a
/// link as selecting a tile would, at launch, or once a channel plays with
/// `-ui-testing-open-url-running`. The shell's scripted sources
/// (`UITestingShell`) remember channel b1 as the last channel, and the
/// `shell.debug.engine` probe records what loads as
/// `"<state> loads=<n> file=<name>"`.
@MainActor
final class TopShelfTVUITests: XCTestCase {
    var app = XCUIApplication()

    /// Item ids of the Home playlist's channels: a version 5 UUID over the
    /// source id and the SHA-256 of the channel id (`TopShelfItemID`).
    static let a2 = "antenna://topShelf/68b168ef-4c9e-5e3e-8151-54f599bd97b7"
    static let removed = "antenna://topShelf/2fd953a5-02de-5f4a-bc8d-2f6d1ea6e57a"

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(link: String, running: Bool = false, extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments =
            ["-ui-testing-shell", "channels", "-antenna.openURL", link] + (running ? ["-ui-testing-open-url-running"] : []) + extra
        app.launchEnvironment["UITESTING_LAST_CHANNEL"] = "b1"
        app.launch()
    }

    private var engine: XCUIElement {
        app.descendants(matching: .any)["shell.debug.engine"].firstMatch
    }

    private func expectEngine(contains text: String, timeout: TimeInterval = 15, line: UInt = #line) {
        let predicate = NSPredicate(format: "value CONTAINS %@", text)
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: engine)], timeout: timeout)
        XCTAssertEqual(result, .completed, "the engine never showed \(text); it shows \(engine.value ?? "nothing")", line: line)
    }

    /// Waits `seconds` and fails if the engine ever loads more than `loads` streams.
    private func expectNoMoreLoads(than loads: Int, for seconds: TimeInterval, line: UInt = #line) {
        let predicate = NSPredicate(format: "NOT (value CONTAINS %@)", "loads=\(loads) ")
        let changed = XCTNSPredicateExpectation(predicate: predicate, object: engine)
        XCTAssertEqual(XCTWaiter().wait(for: [changed], timeout: seconds), .timedOut, "another stream loaded", line: line)
    }

    // tvos-shell/play-or-resume-from-a-shelf-link
    // top-shelf/select-a-tile-to-watch
    func testALinkAtLaunchPlaysItsChannelAndNeverTheLastOne() {
        launch(link: Self.a2)
        expectEngine(contains: "loads=1 file=a2.ts")
        expectNoMoreLoads(than: 1, for: 2)
    }

    // tvos-shell/play-or-resume-from-a-shelf-link
    // top-shelf/select-a-tile-to-watch
    func testALinkWhileRunningPlaysTheChannel() {
        launch(link: Self.a2, running: true)
        expectEngine(contains: "file=a2.ts")
        expectEngine(contains: "loads=2 ")
    }

    // top-shelf/a-tile-that-no-longer-matches-opens-antenna-as-it-was
    func testARemovedFavoriteAtLaunchOpensAsUsual() {
        launch(link: Self.removed)
        expectEngine(contains: "loads=1 file=b1.ts")
    }

    // top-shelf/a-tile-that-no-longer-matches-opens-antenna-as-it-was
    func testADamagedOrEmptyLinkAtLaunchOpensAsUsual() {
        for link in ["antenna://topShelf/not-an-id", "antenna://topShelf/empty"] {
            launch(link: link)
            expectEngine(contains: "loads=1 file=b1.ts")
            app.terminate()
        }
    }

    // top-shelf/a-tile-that-no-longer-matches-opens-antenna-as-it-was
    // tvos-shell/play-or-resume-from-a-shelf-link
    func testARemovedFavoriteWhileRunningChangesNothing() {
        launch(link: Self.removed, running: true)
        expectEngine(contains: "loads=1 file=b1.ts")
        expectNoMoreLoads(than: 1, for: 3)
    }

    // top-shelf/the-paywall-and-setup-come-first
    func testThePaywallComesFirstAndTheLinkIsDropped() {
        launch(link: Self.a2, extra: ["-antenna.entitlement", "locked", "-antenna.store", "products"])
        XCTAssertTrue(app.descendants(matching: .any)["paywall.product.lifetime"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(engine.exists, "the shell waits for the unlock")
        XCUIRemote.shared.press(.select)
        expectEngine(contains: "loads=1 file=b1.ts")
    }

    // top-shelf/the-paywall-and-setup-come-first
    func testSetupComesFirstWithNoSources() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-onboarding", "signedIn", "-antenna.openURL", Self.a2]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.welcome"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["shell.player"].firstMatch.exists, "the link does not skip setup")
    }
}
