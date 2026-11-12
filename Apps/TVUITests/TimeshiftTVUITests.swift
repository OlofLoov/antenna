import XCTest

/// Pausing, rewinding and going back to live on Apple TV
/// (timeshift-catch-up-and-start-over capability), on
/// `-ui-testing-shell channels` with a buffer scripted by `UITESTING_TIMESHIFT`.
@MainActor
final class TimeshiftTVUITests: XCTestCase {
    var app = XCUIApplication()
    let remote = XCUIRemote.shared

    override func setUp() {
        continueAfterFailure = false
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    func expect(_ element: XCUIElement, _ format: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: format), object: element)
        let result = XCTWaiter().wait(for: [wait], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(element.identifier) '\(element.label)' is not \(format)", file: file, line: line)
    }

    func expectEngine(_ summary: String, file: StaticString = #filePath, line: UInt = #line) {
        expect(element("shell.debug.engine"), "value == '\(summary)'", timeout: 15, file: file, line: line)
    }

    func launchPlaying(_ script: String = "buffer") {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels"]
        app.launchEnvironment["UITESTING_TIMESHIFT"] = script
        app.launchEnvironment["TZ"] = "UTC"
        app.launch()
        expectEngine("playing loads=1 file=a1.ts")
        expect(element("zapBar.bar"), "exists == false", timeout: 10)
    }

    // timeshift-catch-up-and-start-over/pause-live-tv-and-pick-up-where-you-left-off
    func testPlayPauseFreezesThePictureAndTheBarShowsTheRewindRow() {
        launchPlaying()
        remote.press(.playPause)
        expectEngine("paused loads=1 file=a1.ts")
        XCTAssertTrue(element("timeshift.row").waitForExistence(timeout: 5), "the zap bar shows the rewind row")
        expect(element("timeshift.stateGlyph"), "value == 'paused'")
        XCTAssertTrue(element("timeshift.positionTime").exists)
        expect(element("zapBar.live"), "value == 'behind'")
        // The bar stays while the pause lasts.
        expect(element("timeshift.behindLive"), "label == '1 min behind'", timeout: 15)
        XCTAssertTrue(element("zapBar.bar").exists, "the bar stays up while paused")

        remote.press(.playPause)
        expectEngine("playing loads=1 file=a1.ts")
    }

    // timeshift-catch-up-and-start-over/skip-scan-and-drag
    // timeshift-catch-up-and-start-over/back-to-live
    func testLeftSkipsBackAndHoldingPlayPauseGoesLive() {
        launchPlaying()
        remote.press(.playPause)
        XCTAssertTrue(element("timeshift.row").waitForExistence(timeout: 5))
        remote.press(.left)
        expect(element("timeshift.behindLive"), "label == '1 min behind'")
        expectEngine("paused loads=1 file=a1.ts")
        expect(element("zapBar.hint"), "label == 'Hold play/pause for live'")

        remote.press(.playPause, forDuration: 1)
        expectEngine("playing loads=1 file=a1.ts")
        expect(element("timeshift.row"), "exists == false")
    }

    // timeshift-catch-up-and-start-over/start-over-shows-only-when-it-can-work
    // timeshift-catch-up-and-start-over/start-the-programme-from-the-beginning
    func testStartOverFromTheOverlayPlaysCatchUp() {
        launchPlaying("catchup")
        remote.press(.select)
        XCTAssertTrue(element("overlay.root").waitForExistence(timeout: 10))
        remote.press(.right)
        expect(element("overlay.watch"), "hasFocus == true")
        remote.press(.right)
        expect(element("overlay.startOver"), "hasFocus == true")
        remote.press(.select)
        expect(element("overlay.root"), "exists == false")
        expect(element("shell.debug.engine"), "value BEGINSWITH 'playing loads=2'", timeout: 15)
        XCTAssertTrue(element("zapBar.catchupBadge").waitForExistence(timeout: 10), "the bar shows CATCH-UP")
        XCTAssertFalse(element("zapBar.live").exists)
        // timeshift-catch-up-and-start-over/logins-stay-private
        XCTAssertFalse(app.debugDescription.contains("secret"), "the catch-up login shows in the hierarchy")

        remote.press(.playPause, forDuration: 1)
        // Back to live reloads the channel with a new buffer.
        expectEngine("playing loads=3 file=a1.ts")
    }

    // timeshift-catch-up-and-start-over/start-over-shows-only-when-it-can-work
    func testStartOverIsAbsentOnAnotherChannel() {
        launchPlaying("catchup")
        remote.press(.select)
        XCTAssertTrue(element("overlay.root").waitForExistence(timeout: 10))
        remote.press(.down)
        remote.press(.right)
        expect(element("overlay.watch"), "hasFocus == true")
        XCTAssertFalse(element("overlay.startOver").exists, "only the playing channel offers Start over")
    }

    // timeshift-catch-up-and-start-over/leaving-the-app-calls-and-other-interruptions
    func testOpeningTheGuideKeepsTheUsersPause() {
        launchPlaying()
        remote.press(.playPause)
        expectEngine("paused loads=1 file=a1.ts")
        // The first Menu hides the zap bar the pause keeps up.
        remote.press(.menu)
        expect(element("zapBar.bar"), "exists == false")
        remote.press(.menu)
        expect(element("shell.tab.live"), "hasFocus == true")
        remote.press(.right)
        expect(element("shell.tab.guide"), "hasFocus == true")
        remote.press(.select)
        XCTAssertTrue(element("guide.grid").waitForExistence(timeout: 10))
        expectEngine("paused loads=1 file=a1.ts")
    }

    // timeshift-catch-up-and-start-over/skip-scan-and-drag
    func testHoldingLeftScansBackAndSeeksOnRelease() {
        launchPlaying()
        remote.press(.playPause)
        XCTAssertTrue(element("timeshift.row").waitForExistence(timeout: 5))
        // A click first, then 60 times real time while held.
        remote.press(.left, forDuration: 2)
        expect(element("timeshift.behindLive"), "label IN {'2 min behind', '3 min behind'}")
        expectEngine("paused loads=1 file=a1.ts")
    }

    // timeshift-catch-up-and-start-over/when-the-stream-cannot-be-recorded
    func testAStreamThatCannotBeRecordedPausesWithNoRewindRow() {
        launchPlaying("none")
        remote.press(.playPause)
        expectEngine("paused loads=1 file=a1.ts")
        XCTAssertTrue(element("zapBar.bar").waitForExistence(timeout: 5))
        XCTAssertFalse(element("timeshift.row").exists)
        remote.press(.playPause)
        expectEngine("playing loads=1 file=a1.ts")
    }

    // timeshift-catch-up-and-start-over/skip-scan-and-drag
    func testLeftAtLiveStillGoesToThePreviousChannel() {
        launchPlaying()
        remote.press(.left)
        XCTAssertFalse(element("timeshift.row").waitForExistence(timeout: 2), "left at live keeps its usual meaning")
    }
}
