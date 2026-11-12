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

        // The probe reads the engine and the player in one value, so this
        // waits for the paused engine and the cleared spinner together. A
        // timed wait on the spinner alone failed on CI when one accessibility
        // query took longer than the time left.
        let probe = app.element("browse.debug.player")
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'paused loads=1 waiting=none'"), object: probe)
        XCTAssertEqual(XCTWaiter().wait(for: [settled], timeout: 15), .completed, "player is \(probe.value as? String ?? "missing")")
        XCTAssertFalse(app.element("player.buffering").exists, "paused, the spinner stayed")
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
