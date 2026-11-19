import XCTest

/// The Apple TV app in Arabic, on the shell's scripted `channels` scenario,
/// the one Apple TV test class that does not launch in English. It checks
/// by identifier and frame that the guide and the tab bar read from the
/// right and that the remote moves focus to what is drawn on that side, and
/// attaches a screenshot of each screen for review.
@MainActor
final class LocalizationRTLTVUITests: XCTestCase {
    let remote = XCUIRemote.shared
    var app = XCUIApplication()
    let home = "00000000-0000-0000-0000-00000000000A"

    override func setUp() {
        continueAfterFailure = false
    }

    /// Launches in Arabic with the first channel playing full screen.
    private func launch(timeshift: String? = nil) {
        if let timeshift { app.launchEnvironment["UITESTING_TIMESHIFT"] = timeshift }
        app.launchArguments = ["-ui-testing-shell", "channels", "-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA"]
        app.launchInEnglish()
        expectFocus("shell.picture")
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element("zapBar.bar"))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 15), .completed, "the info bar never went away")
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func expectFocus(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasFocus == true"), object: element(identifier))
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 10), .completed, "\(identifier) never took focus", file: file, line: line)
    }

    /// The guide block the panel describes.
    private func highlighted() -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'guide.block.' AND isSelected == true")).firstMatch
    }

    private func snap(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Opens the tab `steps` to the left of Live, the next one in reading order.
    private func openTab(_ identifier: String, steps: Int) {
        launch()
        remote.press(.menu)
        expectFocus("shell.tab.live")
        for _ in 0..<steps { remote.press(.left) }
        expectFocus(identifier)
        remote.press(.select)
    }

    // design-system/the-guide-s-time-axis-follows-the-reading-direction
    // design-system/focus-moves-where-the-remote-points
    func testTheGuideRunsFromTheRightAndLeftGoesLater() throws {
        openTab("shell.tab.guide", steps: 1)
        expectFocus("guide.grid")
        let now = highlighted()
        XCTAssertTrue(now.waitForExistence(timeout: 10), "nothing highlighted")
        XCTAssertTrue(now.label.contains("Morning News"), now.label)
        let channel = element("guide.channel.\(home).0")
        XCTAssertGreaterThan(channel.frame.minX, now.frame.maxX, "the channel column sits right of the programme on now")
        let nowFrame = now.frame
        snap("guide")

        remote.press(.left)
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "NOT (label CONTAINS 'Morning News')"), object: highlighted())
        XCTAssertEqual(XCTWaiter().wait(for: [moved], timeout: 10), .completed, "left never moved the highlight")
        let next = highlighted()
        XCTAssertTrue(next.identifier.hasPrefix("guide.block.\(home).0."), "the highlight stays on the row: \(next.identifier)")
        XCTAssertLessThanOrEqual(next.frame.maxX, nowFrame.minX + 1, "the next programme is drawn to the left")
        snap("guide-later")
    }

    // design-system/layouts-mirror-in-right-to-left-languages
    // design-system/focus-moves-where-the-remote-points
    func testMoviesStartsOnTheRightmostButton() throws {
        openTab("shell.tab.movies", steps: 2)
        expectFocus("movies.hero.play")
        let play = element("movies.hero.play").frame
        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThan(play.midX, screen.midX, "first focus sits in the right half")
        snap("movies")
    }

    // design-system/layouts-mirror-in-right-to-left-languages
    func testTheTabBarReadsFromTheRight() {
        launch()
        remote.press(.menu)
        expectFocus("shell.tab.live")
        XCTAssertGreaterThan(element("shell.tab.live").frame.minX, element("shell.tab.guide").frame.maxX, "Live is the rightmost tab")
        snap("tabs")
    }

    // design-system/progress-runs-in-the-reading-direction
    // design-system/focus-moves-where-the-remote-points
    func testRightSkipsBackOnThePausedScrubber() {
        launch(timeshift: "buffer")
        remote.press(.playPause)
        XCTAssertTrue(element("timeshift.row").waitForExistence(timeout: 5), "the zap bar shows the rewind row")
        remote.press(.right)
        let behind = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "متأخر بـ ١ د"), object: element("timeshift.behindLive"))
        XCTAssertEqual(XCTWaiter().wait(for: [behind], timeout: 10), .completed, element("timeshift.behindLive").label)
        snap("scrubber")
    }
}
