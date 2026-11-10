import XCTest

/// Live while sources load, fail, come back empty or wait for a login
/// (live-tv-on-iphone-ipad-mac capability), on scripted sources Home and Cabin.
@MainActor
final class LiveStatesUITests: XCTestCase {
    static let cabin = "00000000-0000-0000-0000-0000000000D2"

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", scenario]
        app.launch()
        return app
    }

    // live-tv-on-iphone-ipad-mac/sources-that-fail-are-empty-or-wait-for-a-login, loading
    func testEachSourceShowsWhileTheyLoad() {
        let app = launch("loading")
        XCTAssertTrue(app.element("browse.loading").waitForExistence(timeout: 10))
        XCTAssertTrue(app.element("browse.loading.\(LiveUITests.home)").label.contains("4 channels"))
        XCTAssertTrue(app.element("browse.loading.\(Self.cabin)").exists)
        XCTAssertFalse(app.element("browse.list").exists)
        XCTAssertTrue(app.element("browse.nothingSelected").exists)
    }

    // live-tv-on-iphone-ipad-mac/sources-that-fail-are-empty-or-wait-for-a-login, offline
    func testOfflineSaysSoWithRetry() {
        let app = launch("offline")
        let error = app.element("browse.error")
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        XCTAssertTrue(error.staticTexts["You're offline."].exists)
        XCTAssertTrue(app.element("browse.retry").exists)
    }

    // live-tv-on-iphone-ipad-mac/sources-that-fail-are-empty-or-wait-for-a-login, nothing loaded
    func testNothingLoadedShowsAMessageWithoutTheSourcesErrorText() {
        let app = launch("error")
        let error = app.element("browse.error")
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        XCTAssertTrue(error.staticTexts["Could not load channels"].exists)
        XCTAssertTrue(error.staticTexts["Cabin: waiting for its login to sync from iCloud"].exists)
        XCTAssertFalse(error.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'hostname'")).firstMatch.exists)
        XCTAssertTrue(app.element("browse.retry").exists)
    }

    // live-tv-on-iphone-ipad-mac/sources-that-fail-are-empty-or-wait-for-a-login, empty
    func testNoChannelsYetOffersRetry() {
        let app = launch("empty")
        let empty = app.element("browse.empty")
        XCTAssertTrue(empty.waitForExistence(timeout: 10))
        XCTAssertTrue(empty.staticTexts["No channels yet"].exists)
        XCTAssertTrue(app.element("browse.retry").exists)
    }

    // live-tv-on-iphone-ipad-mac/sources-that-fail-are-empty-or-wait-for-a-login, some sources failed
    func testABannerNamesTheFailedSourceAndRetryKeepsTheChannelPlaying() {
        let app = launch("failing")
        XCTAssertTrue(app.row(0).waitForExistence(timeout: 10))
        let banner = app.element("browse.banner.failed")
        XCTAssertTrue(banner.exists)
        XCTAssertEqual(app.element("browse.banner.failed.text").label, "Could not load Cabin")
        app.row(0).tap()
        app.waitForEngine("playing loads=1")

        app.element("browse.banner.failed.retry").tap()

        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: banner)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, "the banner stayed")
        app.waitForEngine("playing loads=1")
    }

    // live-tv-on-iphone-ipad-mac/sources-that-fail-are-empty-or-wait-for-a-login, dismiss
    func testTheBannerCanBeDismissed() {
        let app = launch("failing")
        XCTAssertTrue(app.element("browse.banner.failed").waitForExistence(timeout: 10))

        app.element("browse.banner.failed.dismiss").tap()

        XCTAssertFalse(app.element("browse.banner.failed").waitForExistence(timeout: 2))
        XCTAssertTrue(app.row(0).exists)
    }

    // live-tv-on-iphone-ipad-mac/a-login-that-syncs-later
    func testASourceLoadsOnItsOwnWhenItsLoginArrives() {
        let app = launch("waiting")
        let note = app.element("browse.banner.waiting.\(Self.cabin)")
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCTAssertTrue(app.element("browse.group.waiting.\(Self.cabin)").waitForExistence(timeout: 5))
        } else {
            XCTAssertTrue(note.waitForExistence(timeout: 5))
            XCTAssertEqual(note.label, "Cabin · waiting for login")
        }

        let film = app.element("browse.row.\(Self.cabin).0")
        XCTAssertTrue(film.waitForExistence(timeout: 20), "Cabin never loaded")
        XCTAssertFalse(note.exists)
        XCTAssertFalse(app.element("browse.group.waiting.\(Self.cabin)").exists)
    }
}
