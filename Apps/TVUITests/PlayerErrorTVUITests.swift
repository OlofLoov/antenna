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

    func launchFailing(_ reason: String, only files: String? = nil) {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels"]
        app.launchEnvironment["UITESTING_PLAYBACK"] = "fail-\(reason)"
        app.launchEnvironment["UITESTING_FAIL_ONLY"] = files
        app.launchInEnglish()
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

    // player-controls-and-playback-errors/try-again-or-recover-on-its-own, holding select
    func testHoldingSelectOnTheErrorTriesAgainWithoutAPanel() {
        launchFailing("notFound")

        remote.press(.select, forDuration: 1)

        expectEngine("playing loads=2 file=a1.ts")
        expect(element("player.error"), "exists == false")
        XCTAssertFalse(element("player.panel").exists, "no panel opens over the error")
        // tvos-shell/one-press-does-one-thing: the hold tries again once, its release adds nothing.
        sleep(2)
        expectEngine("playing loads=2 file=a1.ts")
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

    // player-controls-and-playback-errors/a-failed-stream-says-what-went-wrong, Channels beside Try again
    // player-controls-and-playback-errors/go-to-another-group-from-the-error
    func testChannelsOpensTheOverlayOnTheGroupAndPlaysAChannelFromAnother() {
        launchFailing("notFound", only: "a1.ts")
        expectEngine("failed loads=1 file=a1.ts")
        let channels = element("player.channels")
        XCTAssertTrue(channels.waitForExistence(timeout: 5))
        expect(element("player.retry"), "hasFocus == true")

        remote.press(.right)
        expect(channels, "hasFocus == true")
        remote.press(.select)
        XCTAssertTrue(element("overlay.root").waitForExistence(timeout: 5), "no overlay")
        // Home's Ungrouped, the playing channel's own group, has the highlight in the group column.
        expect(element("overlay.group.2"), "hasFocus == true")

        remote.press(.up)
        expect(element("overlay.group.1"), "hasFocus == true")
        remote.press(.right)
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "overlay.channel."))
        expect(rows.matching(NSPredicate(format: "label CONTAINS %@", "Channel a1")).firstMatch, "hasFocus == true")
        remote.press(.down)
        expect(rows.matching(NSPredicate(format: "label CONTAINS %@", "Channel a2")).firstMatch, "hasFocus == true")
        remote.press(.select)

        expectEngine("playing loads=2 file=a2.ts")
        expect(element("overlay.root"), "exists == false")
        expect(element("player.error"), "exists == false")
    }

    // player-controls-and-playback-errors/go-to-another-group-from-the-error, Menu after Channels
    func testMenuClosesTheOverlayFromChannelsAndFocusIsBackOnTryAgain() {
        launchFailing("notFound")
        expect(element("player.retry"), "hasFocus == true")
        remote.press(.right)
        expect(element("player.channels"), "hasFocus == true")
        remote.press(.select)
        XCTAssertTrue(element("overlay.root").waitForExistence(timeout: 5), "no overlay")

        remote.press(.menu)

        expect(element("overlay.root"), "exists == false")
        expect(element("player.retry"), "hasFocus == true")
        expectEngine("failed loads=1 file=a1.ts")
    }

    // player-controls-and-playback-errors/try-again-or-recover-on-its-own, sign in on Apple TV
    // player-controls-and-playback-errors/go-to-another-group-from-the-error, a login error on Apple TV
    func testSignInFromTheErrorComesBackToTheChannel() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels"]
        app.launchEnvironment["UITESTING_PLAYBACK"] = "fail-loginNotOnDevice"
        app.launchEnvironment["UITESTING_LAST_CHANNEL"] = "b1"
        app.launchInEnglish()
        expectEngine("failed loads=1 file=b1.ts")
        XCTAssertEqual(element("player.error.title").label, "Sign in needed")
        let signIn = element("player.signIn")
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        XCTAssertFalse(element("player.channels").exists, "Sign in takes the second place")
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
