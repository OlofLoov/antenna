import XCTest

/// A request from a phone arriving on the Apple TV over the network
/// (play-on-apple-tv capability). `-ui-testing-play-request <source>/<id>`
/// delivers one from "Anna's iPhone" a few seconds after launch, on the
/// shell's scripted sources (`UITestingShell`); `playOn.probe` reads the
/// TV's answer and `shell.debug.engine` what loads.
@MainActor
final class PlayOnTVUITests: XCTestCase {
    var app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(request: String, extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels", "-ui-testing-play-request", request] + extra
        app.launchEnvironment["UITESTING_LAST_CHANNEL"] = "a1"
        app.launchInEnglish()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func expect(_ identifier: String, _ predicate: String, timeout: TimeInterval = 20, line: UInt = #line) {
        let target = element(identifier)
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: target)
        XCTAssertEqual(
            XCTWaiter().wait(for: [wait], timeout: timeout), .completed,
            "\(identifier) never matched \(predicate); label \(target.label), value \(target.value ?? "none")", line: line)
    }

    // play-on-apple-tv/starts-at-once-on-the-same-network
    func testARequestTunesTheChannelAndShowsWhoSentIt() {
        launch(request: "playlist/a2")
        expect("playOn.banner", "label CONTAINS 'From Anna' AND label CONTAINS 'Channel a2'")
        expect("playOn.probe", "label == 'answer started'")
        expect("shell.debug.engine", "value CONTAINS 'file=a2'")
    }

    // play-on-apple-tv/the-tv-keeps-its-own-locks-and-profile
    func testALockedChannelAsksForThePasscodeOnTheTV() {
        launch(request: "xtream/b1", extra: ["-ui-testing-groups", "locked"])
        expect("playOn.probe", "label == 'answer needsPasscode'")
        XCTAssertTrue(element("groups.passcode").waitForExistence(timeout: 10), "the TV asks for its passcode")
    }

    private func launch(offer: String) {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels", "-ui-testing-play-offer", offer]
        app.launchEnvironment["UITESTING_LAST_CHANNEL"] = "a1"
        app.launchInEnglish()
    }

    // play-on-apple-tv/the-tv-offers-a-waiting-request
    func testAWaitingRequestIsOfferedWithFocusOnPlay() {
        launch(offer: "playlist/a2")
        XCTAssertTrue(element("playOn.offer").waitForExistence(timeout: 20))
        expect("playOn.offer.sender", "label CONTAINS 'From Anna'")
        expect("playOn.offer.title", "label == 'Channel a2'")
        expect("playOn.offer.play", "hasFocus == true")
        XCUIRemote.shared.press(.select)
        expect("shell.debug.engine", "value CONTAINS 'file=a2'")
        XCTAssertFalse(element("playOn.offer").exists)
    }

    // play-on-apple-tv/the-tv-offers-a-waiting-request
    func testMenuOnTheOfferIsNotNow() {
        launch(offer: "playlist/a2")
        XCTAssertTrue(element("playOn.offer").waitForExistence(timeout: 20))
        expect("playOn.offer.play", "hasFocus == true")
        XCUIRemote.shared.press(.menu)
        expect("playOn.offer", "exists == false")
        expect("shell.debug.engine", "value CONTAINS 'file=a1'")
    }

    // play-on-apple-tv/requests-expire-and-leave-no-trace
    func testARequestSentAnHourAgoIsNotOffered() {
        launch(offer: "playlist/a2:old")
        expect("shell.debug.engine", "value CONTAINS 'file=a1'")
        XCTAssertFalse(element("playOn.offer").waitForExistence(timeout: 5))
    }

    // play-on-apple-tv/the-phone-says-why-the-tv-cannot-play
    func testAChannelTheSourceLacksIsNotFound() {
        launch(request: "playlist/gone")
        expect("playOn.probe", "label == 'answer notFound'", timeout: 30)
        expect("playOn.banner", "label CONTAINS 'find Channel gone'", timeout: 5)
    }
}
