import XCTest

/// Pausing, rewinding and going back to live on iPhone
/// (timeshift-catch-up-and-start-over capability), on the scripted launch of
/// `LiveUITests` with a buffer scripted by `UITESTING_TIMESHIFT`.
@MainActor
final class TimeshiftUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Launches with `script`, plays News One and shows the controls.
    private func launch(_ script: String) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"]
        app.launchEnvironment["UITESTING_TIMESHIFT"] = script
        // Behind is rounded up to the minute. A buffer of exactly 20 minutes
        // reads 20 or 21 at its start, depending on the last tick; 20.5 always reads 21.
        app.launchEnvironment["UITESTING_TIMESHIFT_MINUTES"] = "20.5"
        app.launchEnvironment["TZ"] = "UTC"
        app.launch()
        XCTAssertTrue(app.row(0).waitForExistence(timeout: 10), "the channel list never appeared")
        app.row(0).tap()
        app.waitForEngine("playing loads=1")
        showControls(app)
        return app
    }

    private func showControls(_ app: XCUIApplication) {
        if !app.element("browse.player.controls").exists { app.element("browse.player.surface").tap() }
        XCTAssertTrue(app.element("browse.player.controls").waitForExistence(timeout: 3), "no controls")
    }

    private func label(_ app: XCUIApplication, _ id: String, is expected: String, timeout: TimeInterval = 5) {
        let element = app.element(id)
        let matches = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", expected), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [matches], timeout: timeout), .completed, "\(id) is \(element.label), expected \(expected)")
    }

    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    // timeshift-catch-up-and-start-over/pause-live-tv-and-pick-up-where-you-left-off
    func testPauseShowsTheBufferAndPlayGoesOnWithNoReload() throws {
        let app = try launch("buffer")
        XCTAssertTrue(app.element("timeshift.scrubber").exists, "a recording channel shows the two-row strip")
        XCTAssertTrue(app.element("timeshift.positionTime").exists)
        XCTAssertFalse(app.element("timeshift.behindLive").exists, "nothing is behind at live")

        app.element("browse.player.playPause").tap()
        app.waitForEngine("paused loads=1")
        // Paused, the marker stays while live moves on.
        label(app, "timeshift.behindLive", is: "1 min behind", timeout: 15)
        XCTAssertTrue(app.element("timeshift.knob").exists)
        XCTAssertEqual(app.element("browse.player.live").label, "Go to live")

        app.element("browse.player.playPause").tap()
        app.waitForEngine("playing loads=1")
        XCTAssertTrue(app.element("timeshift.behindLive").exists, "play goes on from the frozen frame, behind live")
    }

    // timeshift-catch-up-and-start-over/skip-scan-and-drag
    func testSkipsMoveBackAndForwardAndReachingNowIsLive() throws {
        let app = try launch("buffer")
        app.element("timeshift.skipBack").tap()
        label(app, "timeshift.behindLive", is: "1 min behind")
        app.element("timeshift.skipForward").tap()
        XCTAssertTrue(waitUntilGone(app.element("timeshift.behindLive")), "a skip past now returns to live")
        app.waitForEngine("playing loads=1")
    }

    // timeshift-catch-up-and-start-over/skip-scan-and-drag
    func testDraggingToTheStartSeeksOnceOnRelease() throws {
        let app = try launch("buffer")
        let scrubber = app.element("timeshift.scrubber")
        let start = scrubber.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5))
        let middle = scrubber.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        middle.press(forDuration: 0.1, thenDragTo: start)
        label(app, "timeshift.behindLive", is: "21 min behind")
        app.waitForEngine("playing loads=1")
    }

    // timeshift-catch-up-and-start-over/back-to-live
    func testTappingLiveGoesBackToLive() throws {
        let app = try launch("buffer")
        app.element("timeshift.skipBack").tap()
        label(app, "browse.player.live", is: "Go to live")
        app.element("browse.player.live").tap()
        XCTAssertTrue(waitUntilGone(app.element("timeshift.behindLive")))
        app.waitForEngine("playing loads=1")
    }

    // timeshift-catch-up-and-start-over/when-the-stream-cannot-be-recorded
    func testAStreamThatCannotBeRecordedHasNoRewindRow() throws {
        let app = try launch("none")
        XCTAssertFalse(app.element("timeshift.scrubber").exists)
        app.element("browse.player.playPause").tap()
        app.waitForEngine("paused loads=1")
        XCTAssertFalse(app.element("timeshift.notice").exists)
        app.element("browse.player.playPause").tap()
        app.waitForEngine("playing loads=1")
    }

    // timeshift-catch-up-and-start-over/when-the-stream-cannot-be-recorded
    func testTheFirstPauseOnShortStorageSaysSo() throws {
        let app = try launch("short")
        app.element("browse.player.playPause").tap()
        label(app, "timeshift.notice", is: "Not enough free storage to rewind live TV")
        XCTAssertFalse(app.element("timeshift.scrubber").exists)
    }

    // timeshift-catch-up-and-start-over/when-the-stream-cannot-be-recorded
    func testAFailedWriteSaysSoOnce() throws {
        let app = try launch("fail")
        label(app, "timeshift.notice", is: "Storage is full", timeout: 10)
        XCTAssertTrue(waitUntilGone(app.element("timeshift.scrubber")), "the rewind row goes")
        app.waitForEngine("playing loads=1")
    }

    // timeshift-catch-up-and-start-over/when-the-buffer-runs-out
    func testAPauseThatOutlastsTheBufferPlaysFromTheEarliestPoint() throws {
        let app = try launch("full")
        app.element("browse.player.playPause").tap()
        app.waitForEngine("paused loads=1")
        label(app, "timeshift.notice", is: "Buffer full. Playing from the earliest point", timeout: 10)
        app.waitForEngine("playing loads=1")
        label(app, "timeshift.behindLive", is: "21 min behind")
    }

    // live-tv-on-iphone-ipad-mac/double-tap-to-skip
    func testDoubleTapsOnEachHalfSkipFifteenSeconds() throws {
        let app = try launch("buffer")
        let surface = app.element("browse.player.surface")
        surface.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.3)).doubleTap()
        label(app, "timeshift.behindLive", is: "1 min behind")

        surface.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.3)).doubleTap()
        XCTAssertTrue(waitUntilGone(app.element("timeshift.behindLive")), "15 seconds forward reaches live again")

        surface.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.3)).doubleTap()
        label(app, "timeshift.notice", is: "Already live")
        app.waitForEngine("playing loads=1")
    }
}
