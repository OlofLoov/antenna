import XCTest

/// AirPlay and the picker footer on iPhone (player-controls-and-playback-errors
/// capability), on the scripted launch of `LiveUITests`. `UITESTING_HLS=1`
/// gives every channel an HLS address, which Apple's player plays.
@MainActor
final class PlayerExtrasUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    private func launchPlaying(hls: Bool) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"]
        if hls { app.launchEnvironment["UITESTING_HLS"] = "1" }
        app.launch()
        XCTAssertTrue(app.row(0).waitForExistence(timeout: 10), "the channel list never appeared")
        app.row(0).tap()
        app.waitForEngine("playing loads=1")
        return app
    }

    private func showControls(_ app: XCUIApplication) {
        if !app.element("browse.player.controls").exists { app.element("browse.player.surface").tap() }
        XCTAssertTrue(app.element("browse.player.controls").waitForExistence(timeout: 3))
    }

    // player-controls-and-playback-errors/extra-buttons-on-iphone-ipad-and-mac, a stream that cannot go to AirPlay
    func testAStreamAntennaReadsItselfHasNoAirPlay() throws {
        let app = try launchPlaying(hls: false)
        showControls(app)
        XCTAssertFalse(app.element("player.airplay").exists)

        app.element("player.tracks").tap()

        XCTAssertTrue(app.element("player.trackPicker").waitForExistence(timeout: 3))
        XCTAssertTrue(app.element("player.trackPicker.stream").label.contains("AirPlay not available for this stream"))
    }

    // player-controls-and-playback-errors/extra-buttons-on-iphone-ipad-and-mac
    func testAirPlayShowsInFullScreenForAStreamApplesPlayerPlays() throws {
        let app = try launchPlaying(hls: true)
        showControls(app)
        XCTAssertFalse(app.element("player.airplay").exists, "no room at compact width")

        XCUIDevice.shared.orientation = .landscapeLeft
        showControls(app)

        let airPlay = app.element("player.airplay")
        XCTAssertTrue(airPlay.waitForExistence(timeout: 3), "no AirPlay button in full screen")
        XCTAssertEqual(airPlay.label, "AirPlay")
        XCTAssertEqual(app.element("player.tracks").label, "Audio and subtitles")
    }
}
