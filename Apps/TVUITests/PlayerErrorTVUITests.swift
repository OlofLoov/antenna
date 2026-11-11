import XCTest

/// The error in place of the full-screen picture on Apple TV
/// (player-controls-and-playback-errors capability), on
/// `-ui-testing-shell channels`. `UITESTING_PLAYBACK=fail-<reason>` fails
/// the first load of each channel; the probe reads
/// `"<state> loads=<n> file=<name>"`.
@MainActor
final class PlayerErrorTVUITests: XCTestCase {
    let remote = XCUIRemote.shared
    var app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
    }

    func launchFailing(_ reason: String) {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels"]
        app.launchEnvironment["UITESTING_PLAYBACK"] = "fail-\(reason)"
        app.launch()
        XCTAssertTrue(element("player.error").waitForExistence(timeout: 15), "no error")
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    func expect(
        _ element: XCUIElement, _ predicate: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    func expectEngine(_ summary: String, file: StaticString = #filePath, line: UInt = #line) {
        expect(element("shell.debug.engine"), "value == '\(summary)'", timeout: 15, file: file, line: line)
    }

    // player-controls-and-playback-errors/a-failed-stream-says-what-went-wrong
    // player-controls-and-playback-errors/error-messages-for-each-reason
    func testTheErrorSaysWhatWentWrongWithTryAgainFocused() {
        launchFailing("notFound")

        XCTAssertEqual(element("player.error.title").label, "Stream not found")
        XCTAssertTrue(element("player.error.body").label.hasPrefix("Home playlist returned 404"))
        XCTAssertTrue(element("player.error.detail").label.hasPrefix("Source: Home playlist · Attempted at "))
        XCTAssertTrue(element("player.error.hint").exists)
        expect(element("player.retry"), "hasFocus == true")
        XCTAssertFalse(element("player.signIn").exists, "a playlist has no login to sign in to")
    }

    // player-controls-and-playback-errors/try-again-or-recover-on-its-own
    func testSelectOnTryAgainLoadsTheSameChannel() {
        launchFailing("notFound")
        expect(element("player.retry"), "hasFocus == true")

        remote.press(.select)

        expectEngine("playing loads=2 file=a1.ts")
        expect(element("player.error"), "exists == false")
    }

    // player-controls-and-playback-errors/try-again-or-recover-on-its-own, play/pause
    func testPlayPauseOnTheErrorTriesAgain() {
        launchFailing("notFound")

        remote.press(.playPause)

        expectEngine("playing loads=2 file=a1.ts")
        expect(element("player.error"), "exists == false")
    }

    // player-controls-and-playback-errors/a-failed-stream-says-what-went-wrong, swiping still changes channel
    // player-controls-and-playback-errors/try-again-or-recover-on-its-own, changing channel from the error
    func testSwipingDownFromTheErrorChangesChannel() {
        launchFailing("unreadable")
        expect(element("player.retry"), "hasFocus == true")

        remote.press(.down)

        expectEngine("failed loads=2 file=a3.ts")
        expect(element("player.retry"), "hasFocus == true")
    }

    // player-controls-and-playback-errors/try-again-or-recover-on-its-own, sign in on Apple TV
    func testSignInFromTheErrorComesBackToTheChannel() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels"]
        app.launchEnvironment["UITESTING_PLAYBACK"] = "fail-loginNotOnDevice"
        app.launchEnvironment["UITESTING_LAST_CHANNEL"] = "b1"
        app.launch()
        expectEngine("failed loads=1 file=b1.ts")
        XCTAssertEqual(element("player.error.title").label, "Sign in needed")
        let signIn = element("player.signIn")
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        remote.press(.right)
        expect(signIn, "hasFocus == true")

        remote.press(.select)
        let username = element("signIn.username")
        XCTAssertTrue(username.waitForExistence(timeout: 5), "the sign-in step never opened")
        expect(username, "hasFocus == true")
        remote.press(.select)
        app.typeText("viewer")
        remote.press(.menu)
        expect(app.keyboards.firstMatch, "exists == false")
        remote.press(.down)
        expect(element("signIn.password"), "hasFocus == true")
        remote.press(.select)
        app.typeText("secret")
        remote.press(.menu)
        expect(app.keyboards.firstMatch, "exists == false")
        remote.press(.down)
        remote.press(.select)

        expectEngine("playing loads=2 file=b1.ts")
        expect(element("player.error"), "exists == false")
    }
}
