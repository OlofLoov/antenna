import XCTest

/// The player over the full-screen picture on Apple TV
/// (player-controls-and-playback-errors capability), on
/// `-ui-testing-shell channels` with `UITESTING_PLAYBACK` picking how the
/// engine plays.
@MainActor
final class PlayerTVUITests: XCTestCase {
    var app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
    }

    func launch(_ playback: String) {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels"]
        app.launchEnvironment["UITESTING_PLAYBACK"] = playback
        app.launchEnvironment["UITESTING_SLOW_SECONDS"] = "2"
        app.launch()
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    // player-controls-and-playback-errors/a-spinner-while-waiting-and-a-reason-if-it-is-slow
    func testASlowChannelShowsTheSpinnerThenNamesTheSource() {
        launch("stall")
        XCTAssertTrue(element("player.buffering").waitForExistence(timeout: 15), "no spinner")

        let caption = element("player.buffering.caption")
        XCTAssertTrue(caption.waitForExistence(timeout: 10), "no slow-source line")
        XCTAssertEqual(caption.label, "Still buffering. Home playlist is sending data slowly.")
    }

    // player-controls-and-playback-errors/a-dropped-stream-shows-that-it-is-reconnecting
    func testADroppedStreamShowsTheReconnectCount() {
        launch("reconnect")
        let reconnecting = element("player.reconnecting")
        XCTAssertTrue(reconnecting.waitForExistence(timeout: 15), "no reconnect count")
        XCTAssertEqual(reconnecting.label, "Reconnecting… attempt 2 of 3")
        XCTAssertFalse(element("player.buffering").exists, "the count shows in place of the spinner")
    }
}
