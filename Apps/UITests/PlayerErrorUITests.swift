import XCTest

/// The error in place of the in-place player on iPhone, with Try again
/// (player-controls-and-playback-errors capability), on the scripted launch
/// of `LiveUITests`. `UITESTING_PLAYBACK=fail-<reason>` fails the first
/// load of each channel.
@MainActor
final class PlayerErrorUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    private func launchFailing(_ reason: String, environment: [String: String] = [:]) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"]
        app.launchEnvironment["UITESTING_PLAYBACK"] = "fail-\(reason)"
        app.launchEnvironment.merge(environment) { _, new in new }
        app.launch()
        XCTAssertTrue(app.row(0).waitForExistence(timeout: 10), "the channel list never appeared")
        app.row(0).tap()
        XCTAssertTrue(app.element("player.error").waitForExistence(timeout: 10), "no error")
        return app
    }

    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    // player-controls-and-playback-errors/a-failed-stream-says-what-went-wrong
    // player-controls-and-playback-errors/error-messages-for-each-reason
    func testAFailedChannelSaysWhatWentWrong() throws {
        let app = try launchFailing("notFound")

        XCTAssertEqual(app.element("player.error.title").label, "Stream not found")
        XCTAssertEqual(
            app.element("player.error.body").label,
            "Home returned 404 for this channel. The channel may have moved or been removed by the provider.")
        XCTAssertTrue(app.element("player.retry").exists)
        XCTAssertTrue(app.element("browse.nowPlaying").exists, "the channel name stays under the error")
        XCTAssertFalse(app.element("browse.player.controls").exists, "no controls over the error")
    }

    // player-controls-and-playback-errors/try-again-or-recover-on-its-own
    func testTryAgainLoadsTheSameChannel() throws {
        let app = try launchFailing("notFound")

        app.element("player.retry").tap()

        app.waitForEngine("playing loads=2")
        XCTAssertTrue(waitUntilGone(app.element("player.error")), "the error stayed")
    }

    // player-controls-and-playback-errors/try-again-or-recover-on-its-own, the network returns
    func testTheConnectionComingBackLoadsAgain() throws {
        let app = try launchFailing("offline", environment: ["UITESTING_NETWORK_SECONDS": "4"])
        XCTAssertEqual(app.element("player.error.title").label, "You're offline")

        app.waitForEngine("playing loads=2")
        XCTAssertTrue(waitUntilGone(app.element("player.error")), "the error stayed")
    }

    // player-controls-and-playback-errors/a-failed-stream-says-what-went-wrong, full screen
    func testInFullScreenTheErrorNamesTheChannelAndKeepsExit() throws {
        let app = try launchFailing("notFound")

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(waitUntilGone(app.element("browse.list")), "the list stayed on screen")
        XCTAssertTrue(app.element("player.error.channel").label.hasSuffix("News One"))
        let exit = app.element("browse.player.fullscreen")
        XCTAssertTrue(exit.waitForExistence(timeout: 3))
        XCTAssertEqual(exit.label, "Exit full screen")
    }
}
