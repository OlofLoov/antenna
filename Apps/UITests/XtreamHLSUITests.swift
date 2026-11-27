import XCTest

/// AirPlay for an Xtream channel on iPhone, on the scripted launch of
/// `LiveUITests` with `UITESTING_XTREAM_HLS`: Cabin Film plays `5.ts` on the
/// device, its source offers `5.m3u8` (or does not, with `ts-only`), a
/// scripted engine stands on each route and the probe's
/// `browse.debug.airPlayRoute` button stands in for picking an AirPlay device.
@MainActor
final class XtreamHLSUITests: XCTestCase {
    static let cabin = "00000000-0000-0000-0000-0000000000D2"
    nonisolated let log = FileManager.default.temporaryDirectory.appending(path: "hls-engine-\(UUID().uuidString).log")

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: log)
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
    }

    private func launch(offers: String = "1", environment: [String: String] = [:]) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"]
        app.launchEnvironment["UITESTING_ENGINE_LOG"] = log.path
        app.launchEnvironment["UITESTING_XTREAM_HLS"] = offers
        environment.forEach { app.launchEnvironment[$0.key] = $0.value }
        app.launchInEnglish()
        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 10), "the channel list never appeared")
        let film = app.element("browse.row.\(Self.cabin).0")
        XCTAssertTrue(film.waitForExistence(timeout: 10), "Cabin Film never appeared")
        film.tap()
        app.waitForEngine("playing loads=1")
        XCTAssertEqual(loaded, ["5.ts"])
        return app
    }

    /// The streams the engines loaded, in order.
    private var loaded: [String] {
        ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    /// Turns the phone so the picture fills the screen, and shows the controls.
    private func fullScreenControls(_ app: XCUIApplication) {
        XCUIDevice.shared.orientation = .landscapeLeft
        if !app.element("browse.player.controls").waitForExistence(timeout: 2) { app.element("browse.player.surface").tap() }
        XCTAssertTrue(app.element("player.airplay").waitForExistence(timeout: 5), "no AirPlay button in full screen")
    }

    private func expectNotice(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let notice = app.element("timeshift.notice")
        XCTAssertTrue(notice.waitForExistence(timeout: 5), "no notice", file: file, line: line)
        XCTAssertEqual(notice.label, "AirPlay not available for this stream", file: file, line: line)
    }

    private func switchAirPlayRoute(_ app: XCUIApplication) {
        let button = app.element("browse.debug.airPlayRoute")
        XCTAssertTrue(button.waitForExistence(timeout: 5), "no route switch in the probe")
        button.tap()
    }

    // player-controls-and-playback-errors/extra-buttons-on-iphone-ipad-and-mac, an Xtream channel that can go to AirPlay
    // playback-engine/a-channel-goes-to-airplay-as-hls
    func testAirPlayOnAChannelWhoseSourceOffersHLSOpensTheListAndKeepsMPEGTSPlaying() throws {
        let app = try launch()
        fullScreenControls(app)
        app.element("player.airplay").tap()
        let openings = app.element("browse.debug.airPlayList")
        let opened = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: openings)
        XCTAssertEqual(XCTWaiter().wait(for: [opened], timeout: 5), .completed, "the AirPlay list did not open")
        XCTAssertEqual(loaded, ["5.ts"], "MPEG-TS stopped before a device was picked")
        XCTAssertFalse(app.element("timeshift.notice").exists)
    }

    // playback-engine/a-channel-goes-to-airplay-as-hls
    func testPickingAnAirPlayDeviceMovesTheChannelToHLSAndBack() throws {
        let app = try launch()
        switchAirPlayRoute(app)
        app.waitForEngine("playing loads=1")
        XCTAssertEqual(loaded, ["5.ts", "5.m3u8"])

        app.openTracksMenu()
        XCTAssertFalse(app.tracksRow("AirPlay not available for this stream").exists)
        let hlsLine = app.tracksMenu.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "HLS")).firstMatch
        XCTAssertTrue(hlsLine.exists, "the stream line does not name HLS")
        app.element("browse.player.surface").tap()

        switchAirPlayRoute(app)
        app.waitForEngine("playing loads=2")
        XCTAssertEqual(loaded, ["5.ts", "5.m3u8", "5.ts"])
    }

    // playback-engine/a-source-whose-hls-failed-cannot-airplay
    func testABrokenHLSLinkKeepsMPEGTSAndSaysAirPlayIsNotAvailable() throws {
        let app = try launch(environment: ["UITESTING_PLAYBACK": "fail-unreadable", "UITESTING_FAIL_ONLY": "5.m3u8"])
        switchAirPlayRoute(app)
        expectNotice(app)
        app.waitForEngine("playing loads=2")
        XCTAssertEqual(loaded, ["5.ts", "5.m3u8", "5.ts"])
        XCTAssertFalse(app.element("player.retry").exists, "the HLS failure showed as an error")

        fullScreenControls(app)
        app.element("player.airplay").tap()
        expectNotice(app)
        XCTAssertEqual(app.element("browse.debug.airPlayList").value as? String, "0", "the AirPlay list opened")
    }

    // player-controls-and-playback-errors/extra-buttons-on-iphone-ipad-and-mac, a stream that cannot go to AirPlay
    func testAirPlayOnASourceThatOffersOnlyMPEGTSSaysSo() throws {
        let app = try launch(offers: "ts-only")
        fullScreenControls(app)
        app.element("player.airplay").tap()
        expectNotice(app)
        XCTAssertEqual(app.element("browse.debug.airPlayList").value as? String, "0", "the AirPlay list opened")
        XCTAssertEqual(loaded, ["5.ts"])
    }
}
