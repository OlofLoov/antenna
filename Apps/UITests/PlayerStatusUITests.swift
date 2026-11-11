import XCTest

/// The spinner, the slow-source line and the reconnect count over the
/// in-place player on iPhone (player-controls-and-playback-errors
/// capability), on the scripted launch of `LiveUITests` with
/// `UITESTING_PLAYBACK` picking how the engine plays.
@MainActor
final class PlayerStatusUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ playback: String) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"]
        app.launchEnvironment["UITESTING_PLAYBACK"] = playback
        app.launchEnvironment["UITESTING_SLOW_SECONDS"] = "2"
        app.launch()
        XCTAssertTrue(app.row(0).waitForExistence(timeout: 10), "the channel list never appeared")
        app.row(0).tap()
        return app
    }

    // player-controls-and-playback-errors/a-spinner-while-waiting-and-a-reason-if-it-is-slow
    func testASlowChannelShowsTheSpinnerThenNamesTheSource() throws {
        let app = try launch("stall")
        XCTAssertTrue(app.element("player.buffering").waitForExistence(timeout: 5), "no spinner")

        let caption = app.element("player.buffering.caption")
        XCTAssertTrue(caption.waitForExistence(timeout: 10), "no slow-source line")
        XCTAssertEqual(caption.label, "Still buffering. Home is sending data slowly.")
    }

    // player-controls-and-playback-errors/a-spinner-while-waiting-and-a-reason-if-it-is-slow, play/pause while spinning
    func testPlayPauseWorksWhileTheSpinnerShows() throws {
        let app = try launch("stall")
        XCTAssertTrue(app.element("player.buffering").waitForExistence(timeout: 5))

        app.element("browse.player.surface").tap()
        let playPause = app.element("browse.player.playPause")
        XCTAssertTrue(playPause.waitForExistence(timeout: 3))
        playPause.tap()

        app.waitForEngine("paused loads=1")
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.element("player.buffering"))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 3), .completed, "paused, the spinner stayed")
    }

    // player-controls-and-playback-errors/a-dropped-stream-shows-that-it-is-reconnecting
    func testADroppedStreamShowsTheReconnectCount() throws {
        let app = try launch("reconnect")
        let reconnecting = app.element("player.reconnecting")
        XCTAssertTrue(reconnecting.waitForExistence(timeout: 10), "no reconnect count")
        XCTAssertEqual(reconnecting.label, "Reconnecting… attempt 2 of 3")
        XCTAssertFalse(app.element("player.buffering").exists, "the count shows in place of the spinner")
    }
}
