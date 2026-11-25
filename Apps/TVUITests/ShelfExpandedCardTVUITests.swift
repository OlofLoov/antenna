import XCTest

/// The focused poster growing into a card in its row of Movies and Series
/// on Apple TV (movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv).
/// Launches the shell's `channels` scenario, whose Movies are Night Ferry,
/// Snow Day and Copper Hills, or the shelf's `titles` script.
@MainActor
final class ShelfExpandedCardTVUITests: XCTestCase {
    let remote = XCUIRemote.shared
    var app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    func press(_ button: XCUIRemote.Button, times: Int = 1) {
        for _ in 0..<times { remote.press(button) }
    }

    func expect(
        _ element: XCUIElement, _ predicate: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    func expectFocus(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        expect(element(identifier), "hasFocus == true", file: file, line: line)
    }

    /// The identifier of the element with focus, for failure messages.
    var focused: String {
        let match = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
        return match.exists ? match.identifier : "nothing"
    }

    /// The number of info calls the scripted shelf has been asked.
    var infoLoads: Int {
        Int(element("shelf.debug.infoLoads").value as? String ?? "") ?? -1
    }

    /// Movies open from the bar in the shell's `channels` scenario, with
    /// focus on the banner's Play button.
    func openMovies() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels"]
        app.launchInEnglish()
        expectFocus("shell.picture")
        expect(element("zapBar.bar"), "exists == false")
        press(.menu)
        moveAlongTheBar(.right, to: "shell.tab.movies")
        press(.select)
        expectFocus("movies.hero.play")
        // Play takes focus a second time once the titles have loaded.
        Thread.sleep(forTimeInterval: 1)
    }

    /// A section opened from the bar with the shelf's `titles` script.
    func open(_ tab: String, rights: Int) {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", "titles"]
        app.launchInEnglish()
        // The system bar takes Menu only once something on the page has focus.
        _ = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch.waitForExistence(timeout: 10)
        press(.menu)
        XCTAssertTrue(element("shell.tab.\(tab)").waitForExistence(timeout: 10))
        expectFocus("shell.tab.live")
        press(.right, times: rights)
        expectFocus("shell.tab.\(tab)")
        press(.select)
        expectFocus("\(tab).hero.play")
        // Play takes focus a second time once the titles have loaded.
        Thread.sleep(forTimeInterval: 1)
    }

    /// The frame of the card with focus, for its size.
    var focusedFrame: CGRect {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch.frame
    }

    // movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv
    func testRestingOnAPosterExpandsItInPlace() {
        openMovies()
        XCTAssertEqual(element("movies.hero.title").label, "Night Ferry")
        press(.down)
        XCTAssertTrue(focused.hasPrefix("movies.card."), focused)
        expect(element("movies.card.focused.title"), "label == 'Night Ferry'")
        XCTAssertFalse(element("movies.preview").exists, "no preview at the top")
        // The row rests just under the tab bar, with room for the rows below.
        let row = element("movies.row.recentlyAdded")
        for _ in 0..<10 where !(120...200).contains(row.frame.minY) {
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTAssertTrue((120...200).contains(row.frame.minY), "the row's top is at \(row.frame.minY)")
        XCTAssertGreaterThan(focusedFrame.width, 500, "the focused poster grew into a landscape card: \(focusedFrame)")

        press(.right)
        expect(element("movies.card.focused.title"), "label == 'Snow Day'")
        expect(element("movies.card.focused.facts"), "label CONTAINS '2002'")
        expect(element("movies.card.focused.plot"), "label == 'The story of Snow Day.'")
        XCTAssertGreaterThan(focusedFrame.width, 500, "the next poster grew in its place: \(focusedFrame)")
    }

    // design-system/apple-tv-content-stays-in-the-safe-area
    // The hero copy and the rows started 64 pt from the side; the safe area is 80.
    func testMoviesKeepsTheSafeEdges() {
        openMovies()
        XCTAssertEqual(element("movies.hero.title").frame.minX, 80, accuracy: 1, "the hero copy starts at the safe edge")
        // Play has focus, and its platter grows a few points past its place at the margin.
        XCTAssertGreaterThanOrEqual(element("movies.hero.play").frame.minX, 72, "Play starts at the safe edge")
        press(.down)
        expect(element("movies.card.focused.title"), "label == 'Night Ferry'")
        // The first card has focus and grows about its middle; its resting frame starts at the margin.
        let frame = focusedFrame
        XCTAssertEqual(frame.minX, 80, accuracy: 40, "the first card starts at the safe edge: \(frame)")
        XCTAssertGreaterThanOrEqual(element("movies.card.focused.title").frame.minX, 80, "the card's copy is inside the safe area")
    }

    // movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv, moving quickly along a row
    // movies-and-series-browsing/title-details-are-asked-once-per-title
    func testAFastSwipeExpandsEachPosterAndAsksOnlyTheLast() {
        open("movies", rights: 2)
        press(.down)
        expect(element("movies.card.focused.title"), "exists == true")
        Thread.sleep(forTimeInterval: 2)
        let before = infoLoads
        XCTAssertGreaterThanOrEqual(before, 0)
        // Each press lands well inside the 0.8 second rest, and each poster grows as the highlight reaches it.
        press(.right, times: 3)
        expect(element("movies.card.focused.title"), "exists == true", timeout: 2)
        Thread.sleep(forTimeInterval: 2)
        XCTAssertLessThanOrEqual(infoLoads, before + 1, "only the poster the highlight stopped on is asked about")
        XCTAssertGreaterThan(focusedFrame.width, 500, "the poster it stopped on is a card: \(focusedFrame)")
    }

    // movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv, back to the banner
    func testUpFromTheFirstRowGoesBackToTheBanner() {
        openMovies()
        press(.down)
        expect(element("movies.card.focused.title"), "exists == true")
        press(.up)
        expectFocus("movies.hero.play")
        expect(element("movies.card.focused.title"), "exists == false")
        XCTAssertEqual(element("movies.hero.title").label, "Night Ferry", "the banner shows the title it showed before")
    }

    // movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv, back from a title page or the player
    // movies-and-series-browsing/title-details-are-asked-once-per-title, the page uses the kept answer
    func testBackFromAPageExpandsThePosterAtOnce() {
        open("series", rights: 3)
        press(.down)
        expectFocus("series.card.xtream#cabin#series#2")
        press(.right, times: 2)
        expectFocus("series.card.xtream#cabin#series#1")
        expect(element("series.card.focused.title"), "label == 'Northern Lights'", timeout: 5)
        expect(element("series.card.focused.plot"), "label == 'A series about Northern Lights.'")
        let asked = infoLoads
        press(.select)
        expectFocus("title.play")
        XCTAssertEqual(infoLoads, asked, "the page uses the card's answer")
        press(.menu)
        expectFocus("series.card.xtream#cabin#series#1")
        expect(element("series.card.focused.plot"), "label == 'A series about Northern Lights.'")
        XCTAssertEqual(infoLoads, asked)
    }
}
