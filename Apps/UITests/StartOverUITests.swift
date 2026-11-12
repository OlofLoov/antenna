import XCTest

/// Start over on iPhone (timeshift-catch-up-and-start-over capability), on
/// the scripted launch of `LiveUITests`. News One's Morning News began 30
/// minutes before launch; the scripted buffer holds 20 minutes unless a
/// test asks for 40. Kids One has no guide data.
@MainActor
final class StartOverUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ script: String, row: Int = 0, minutes: Int = 20) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"]
        app.launchEnvironment["UITESTING_TIMESHIFT"] = script
        app.launchEnvironment["UITESTING_TIMESHIFT_MINUTES"] = String(minutes)
        app.launch()
        XCTAssertTrue(app.row(row).waitForExistence(timeout: 10), "the channel list never appeared")
        app.row(row).tap()
        app.waitForEngine("playing loads=1")
        if !app.element("browse.player.controls").exists { app.element("browse.player.surface").tap() }
        XCTAssertTrue(app.element("browse.player.controls").waitForExistence(timeout: 3))
        return app
    }

    private func label(_ app: XCUIApplication, _ id: String, is expected: String, timeout: TimeInterval = 8) {
        let element = app.element(id)
        let matches = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", expected), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [matches], timeout: timeout), .completed, "\(id) is \(element.label), expected \(expected)")
    }

    // timeshift-catch-up-and-start-over/start-over-shows-only-when-it-can-work
    // timeshift-catch-up-and-start-over/start-the-programme-from-the-beginning
    func testStartOverPlaysCatchUpAndLiveComesBack() throws {
        let app = try launch("catchup")
        XCTAssertTrue(app.element("timeshift.startOver").waitForExistence(timeout: 8), "catch-up can be built")
        app.element("timeshift.startOver").tap()
        XCTAssertTrue(app.element("timeshift.catchupBadge").waitForExistence(timeout: 5), "the CATCH-UP badge shows")
        app.waitForEngine("playing loads=2")
        label(app, "timeshift.behindLive", is: "31 min behind")
        // timeshift-catch-up-and-start-over/logins-stay-private: the address's login is in no label, value or identifier.
        XCTAssertFalse(app.debugDescription.contains("secret"), "the catch-up login shows in the hierarchy")

        app.element("browse.player.live").tap()
        // From catch-up the live channel loads again with a new buffer.
        app.waitForEngine("playing loads=3")
        XCTAssertFalse(app.element("timeshift.catchupBadge").waitForExistence(timeout: 2))
    }

    // timeshift-catch-up-and-start-over/when-the-provider-s-catch-up-fails
    func testFailedCatchUpWithoutTheStartInTheBufferSaysSo() throws {
        let app = try launch("catchup-fail")
        XCTAssertTrue(app.element("timeshift.startOver").waitForExistence(timeout: 8))
        app.element("timeshift.startOver").tap()
        label(app, "timeshift.notice", is: "Start over isn't available for this programme")
        XCTAssertFalse(app.element("player.error").exists, "no error shows")
        XCTAssertFalse(app.element("timeshift.catchupBadge").exists)
    }

    // timeshift-catch-up-and-start-over/when-the-provider-s-catch-up-fails
    func testFailedCatchUpWithTheStartInTheBufferGoesThere() throws {
        let app = try launch("catchup-fail", minutes: 40)
        XCTAssertTrue(app.element("timeshift.startOver").waitForExistence(timeout: 8))
        app.element("timeshift.startOver").tap()
        label(app, "timeshift.behindLive", is: "31 min behind")
        XCTAssertFalse(app.element("player.error").exists, "no error shows")
    }

    // timeshift-catch-up-and-start-over/start-over-shows-only-when-it-can-work
    // timeshift-catch-up-and-start-over/start-the-programme-from-the-beginning
    func testWithoutCatchUpTheBufferJumpsToTheStart() throws {
        let app = try launch("buffer", minutes: 40)
        XCTAssertTrue(app.element("timeshift.startOver").waitForExistence(timeout: 8), "the buffer reaches the start")
        app.element("timeshift.startOver").tap()
        label(app, "timeshift.behindLive", is: "31 min behind")
        app.waitForEngine("playing loads=1")
    }

    // timeshift-catch-up-and-start-over/start-over-shows-only-when-it-can-work
    func testStartOverIsAbsentWhenNothingReachesTheStart() throws {
        let app = try launch("buffer")
        XCTAssertTrue(app.element("timeshift.scrubber").waitForExistence(timeout: 5))
        XCTAssertFalse(app.element("timeshift.startOver").waitForExistence(timeout: 5), "the buffer does not reach Morning News's start")
    }

    // timeshift-catch-up-and-start-over/start-over-shows-only-when-it-can-work, no guide data
    func testStartOverIsAbsentWithoutGuideData() throws {
        let app = try launch("catchup", row: 3, minutes: 40)
        XCTAssertTrue(app.element("timeshift.scrubber").waitForExistence(timeout: 5))
        XCTAssertFalse(app.element("timeshift.startOver").waitForExistence(timeout: 5))
    }
}
