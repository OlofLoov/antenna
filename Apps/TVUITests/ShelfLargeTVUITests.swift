import XCTest

/// Movies and Series on Apple TV with the shelf's `large` script: 9 000
/// movies and 3 500 series from two sources, in 80 and 40 categories
/// (movies-and-series-browsing/browsing-stays-responsive).
///
/// The `measure` tests count hitches with `XCTHitchMetric` and run only with
/// `TEST_RUNNER_ANTENNA_BENCHMARKS=1`. With
/// `TEST_RUNNER_ANTENNA_POSTER_HOST=http://127.0.0.1:<port>` posters and
/// backdrops load from a fixture server on the Mac; without it every poster
/// shows its name tile. `TEST_RUNNER_ANTENNA_NO_PREFETCH=1` turns off
/// loading posters ahead, to compare.
@MainActor
final class ShelfLargeTVUITests: XCTestCase {
    let remote = XCUIRemote.shared
    var app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
    }

    var benchmarks: Bool {
        ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    var focusedElement: XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
    }

    /// The identifier of the element with focus, for failure messages.
    var focused: String {
        focusedElement.exists ? focusedElement.identifier : "nothing"
    }

    func expect(
        _ element: XCUIElement, _ predicate: String, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(element) never matched \(predicate); focus is on \(focused)", file: file, line: line)
    }

    func expectFocus(_ identifier: String, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) {
        expect(element(identifier), "hasFocus == true", timeout: timeout, file: file, line: line)
    }

    func press(_ button: XCUIRemote.Button, times: Int = 1) {
        for _ in 0..<times { remote.press(button) }
    }

    /// The count the probe `identifier` shows. Movies and Series each hold
    /// a probe and only the open one reads the counts again, so the
    /// highest is the current one.
    func probe(_ identifier: String) -> Int {
        // The probe reads the counts twice a second.
        Thread.sleep(forTimeInterval: 0.7)
        let probes = app.descendants(matching: .any).matching(identifier: identifier).allElementsBoundByIndex
        return probes.compactMap { Int($0.value as? String ?? "") }.max() ?? -1
    }

    /// How many times `part` of the section drew its body since launch.
    func redraws(_ part: String) -> Int {
        probe("shelf.debug.redraws.\(part)")
    }

    func launch(arguments: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", "large"] + arguments
        if let host = ProcessInfo.processInfo.environment["ANTENNA_POSTER_HOST"] {
            app.launchArguments += ["-ui-testing-poster-host", host]
        }
        // For a run to compare with posters loading only as their cards show.
        if ProcessInfo.processInfo.environment["ANTENNA_NO_PREFETCH"] == "1" {
            app.launchArguments.append("-ui-testing-no-prefetch")
        }
        app.launchInEnglish()
        // The system bar takes Menu only once something on the page has focus.
        _ = focusedElement.waitForExistence(timeout: 10)
    }

    /// The section's tab opened from the bar, with focus on the banner's Play button.
    func open(_ tab: String, arguments: [String] = []) {
        launch(arguments: arguments)
        showBar(tab)
        moveAlongTheBar(.right, to: "shell.tab.\(tab)")
        press(.select)
        expectFocus("\(tab).hero.play")
        // Play takes focus a second time once the titles have loaded.
        Thread.sleep(forTimeInterval: 1)
    }

    /// Presses Menu until the tab bar shows. A first launch on a slow
    /// simulator can take Menu before the page has the highlight.
    func showBar(_ tab: String, file: StaticString = #filePath, line: UInt = #line) {
        let item = element("shell.tab.\(tab)")
        for _ in 0..<3 where !item.exists {
            press(.menu)
            _ = item.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(item.exists, "the tab bar never showed; focus is on \(focused)", file: file, line: line)
    }

    /// Waits for Office's titles, which arrive 5 seconds after Cabin's, to join Recently added.
    func expectBothSources(_ tab: String) {
        let office = element("\(tab).row.recentlyAdded").descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "\(tab).card.xtream#office#")).firstMatch
        XCTAssertTrue(office.waitForExistence(timeout: 15), "Office's titles never reached Recently added")
    }

    /// Down from the banner into Recently added, with the focused poster grown into its card.
    func enterRows(_ tab: String) {
        press(.down)
        expect(focusedElement, "identifier BEGINSWITH '\(tab).card.'")
        expect(element("\(tab).card.focused.title"), "exists == true")
    }

    // MARK: Focus

    // movies-and-series-browsing/browsing-stays-responsive
    // Tester-found on 2026-11-23, browsing lagged: moving across posters redrew the screen and every row on it.
    func testMovingAcrossPostersRedrawsNoRow() {
        open("movies")
        enterRows("movies")
        expectBothSources("movies")
        press(.right)
        // Series builds its rows for Office too, which Continue watching reads.
        var rows = redraws("rows")
        for _ in 0..<10 {
            Thread.sleep(forTimeInterval: 1)
            let now = redraws("rows")
            if now == rows { break }
            rows = now
        }
        let screen = redraws("screen")
        let banner = redraws("banner")
        for _ in 0..<8 {
            press(.right)
            Thread.sleep(forTimeInterval: 0.3)
        }
        expect(focusedElement, "identifier BEGINSWITH 'movies.card.'")
        // The rested poster's details arriving may redraw them once or twice; the moves do not.
        XCTAssertLessThanOrEqual(redraws("rows") - rows, 2, "the rows redrew as the highlight moved across posters")
        // The banner may redraw once for its own clock, as its picture's wait runs out.
        XCTAssertLessThanOrEqual(redraws("banner") - banner, 1, "the banner redrew as the highlight moved across posters")
        // Nothing on the screen changes for a move between posters; only the cards do.
        XCTAssertLessThanOrEqual(redraws("screen") - screen, 1, "the screen redrew as the highlight moved across posters")
    }

    /// Opens the page of the fourth poster in the third row of `tab`, goes
    /// back with Menu, and expects that poster focused with its card.
    func backFromAPageOpenedFromTheThirdRow(_ tab: String, arguments: [String] = []) {
        open(tab, arguments: arguments)
        enterRows(tab)
        expectBothSources(tab)
        press(.down, times: 2)
        press(.right, times: 3)
        Thread.sleep(forTimeInterval: 1.5)
        let poster = focused
        XCTAssertTrue(poster.hasPrefix("\(tab).card."), "focus is on \(poster)")
        press(.select)
        XCTAssertTrue(element("title.root").waitForExistence(timeout: 10), "the poster opens the title's page")
        XCTAssertFalse(element("\(tab).player").exists, "nothing plays from the poster")
        Thread.sleep(forTimeInterval: 2)
        press(.menu)
        expectFocus(poster)
        expect(element("\(tab).card.focused.title"), "exists == true")
        // The highlight stays on the poster once the section has settled.
        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(focused, poster)
    }

    // title-detail-and-episode-picker/back-to-where-you-were
    // movies-and-series-browsing/a-poster-opens-its-page, back to the poster on Apple TV
    // Found on 2026-11-23 with the large library: back from a movie started from a row, the highlight was on the banner.
    func testBackFromAMoviePageOpenedFromARowFocusesItsPoster() {
        backFromAPageOpenedFromTheThirdRow("movies")
    }

    // title-detail-and-episode-picker/back-to-where-you-were
    func testBackFromASeriesPageOpenedFromARowFocusesItsPoster() {
        backFromAPageOpenedFromTheThirdRow("series")
    }

    // title-detail-and-episode-picker/back-to-where-you-were
    // Found on 2026-11-27: as the page closed, the focus engine's own pick in the section
    // sometimes landed after the poster's and left the highlight on Play or another poster.
    // The launch argument moves the highlight after the poster has asked, every time.
    func testBackFromASeriesPageFocusesItsPosterWhenTheSectionTakesFocusLast() {
        backFromAPageOpenedFromTheThirdRow("series", arguments: ["-ui-testing-section-focus-lands-last"])
    }

    // movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv, moving to another row
    // Found on 2026-11-25: each move up or down landed the highlight a poster to the right, so a walk six rows
    // down and back up ended on the eighth poster of Recently added instead of the first.
    func testDownAndUpTheRowsKeepsTheColumn() {
        open("movies")
        enterRows("movies")
        expectBothSources("movies")
        let start = focused
        XCTAssertTrue(start.hasPrefix("movies.card."), "focus is on \(start)")
        for _ in 0..<6 {
            press(.down)
            Thread.sleep(forTimeInterval: 0.6)
        }
        for _ in 0..<6 {
            press(.up)
            Thread.sleep(forTimeInterval: 0.6)
        }
        expectFocus(start)
    }

    // tvos-shell/back-from-a-tab-goes-to-the-tab-bar
    // Found on 2026-11-23 with the large library: down from the bar after visiting Series landed on My list.
    func testDownFromTheBarAfterSeriesLandsOnPlay() {
        open("movies")
        press(.menu)
        expectFocus("shell.tab.movies")
        moveAlongTheBar(.right, to: "shell.tab.series")
        press(.down)
        expectFocus("series.hero.play")
        press(.menu)
        expectFocus("shell.tab.series")
        moveAlongTheBar(.left, to: "shell.tab.movies")
        press(.down)
        expectFocus("movies.hero.play")
        press(.menu)
        expectFocus("shell.tab.movies")
        // The bar takes a moment to come in before it passes a swipe on.
        Thread.sleep(forTimeInterval: 1)
        press(.down)
        expectFocus("movies.hero.play")
    }

    // MARK: Hitches

    var gaps: Gaps {
        Gaps(
            frames: probe("shelf.debug.frames"), dropped: probe("shelf.debug.dropped"), hitchMs: probe("shelf.debug.hitchMs"),
            posterMisses: probe("shelf.debug.posterMisses"), posterAsks: probe("shelf.debug.posterAsks"))
    }

    /// Where posters went between loading ahead and showing, as the
    /// section's probe reads it.
    var trace: String {
        Thread.sleep(forTimeInterval: 0.7)
        let probe = app.descendants(matching: .any).matching(identifier: "shelf.debug.posterTrace").firstMatch
        return probe.exists ? (probe.value as? String ?? "") : "none"
    }

    /// Runs `walk` `times` times and reports the frames each run missed.
    func measureGaps(_ label: String, times: Int = 3, walk: () -> Void) {
        var runs: [Gaps] = []
        for run in 0..<times {
            let before = gaps
            print("TRACE \(label) \(run) before: \(trace) focus=\(focused)")
            walk()
            runs.append(gaps - before)
            print("TRACE \(label) \(run) after: \(trace) focus=\(focused)")
        }
        let line = runs.map {
            "\($0.dropped) dropped, \($0.hitchMs) ms over \($0.frames) frames, \($0.posterMisses) of \($0.posterAsks) posters not ready"
        }
        .joined(separator: "; ")
        print("HITCHES \(label): \(line)")
        let attachment = XCTAttachment(string: line)
        attachment.name = "hitches \(label)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The floor: reading the probe and the clock ticking, with no press.
    func testHitchesStandingStill() throws {
        try XCTSkipUnless(benchmarks, "runs with TEST_RUNNER_ANTENNA_BENCHMARKS=1")
        open("movies")
        enterRows("movies")
        expectBothSources("movies")
        measureGaps("standing still") {
            Thread.sleep(forTimeInterval: 6)
        }
    }

    func testHitchesOpeningMovies() throws {
        try XCTSkipUnless(benchmarks, "runs with TEST_RUNNER_ANTENNA_BENCHMARKS=1")
        launch()
        showBar("movies")
        // The tab opens, and the titles start loading, as the highlight lands on it.
        moveAlongTheBar(.right, to: "shell.tab.movies")
        measureGaps("opening Movies", times: 1) {
            press(.down)
            expectFocus("movies.hero.play")
            Thread.sleep(forTimeInterval: 4)
        }
    }

    func testHitchesMovingAcrossPosters() throws {
        try XCTSkipUnless(benchmarks, "runs with TEST_RUNNER_ANTENNA_BENCHMARKS=1")
        open("movies")
        enterRows("movies")
        expectBothSources("movies")
        measureGaps("across posters") {
            for _ in 0..<10 { remote.press(.right) }
            for _ in 0..<10 { remote.press(.left) }
            Thread.sleep(forTimeInterval: 1)
        }
    }

    func testHitchesMovingDownTheRows() throws {
        try XCTSkipUnless(benchmarks, "runs with TEST_RUNNER_ANTENNA_BENCHMARKS=1")
        open("movies")
        enterRows("movies")
        expectBothSources("movies")
        measureGaps("down the rows") {
            for _ in 0..<6 {
                remote.press(.down)
                Thread.sleep(forTimeInterval: 0.4)
            }
            for _ in 0..<6 {
                remote.press(.up)
                Thread.sleep(forTimeInterval: 0.4)
            }
            Thread.sleep(forTimeInterval: 1)
        }
    }

    func testHitchesSwitchingTabs() throws {
        try XCTSkipUnless(benchmarks, "runs with TEST_RUNNER_ANTENNA_BENCHMARKS=1")
        open("movies")
        press(.menu)
        expectFocus("shell.tab.movies")
        Thread.sleep(forTimeInterval: 2)
        measureGaps("Movies to Series and back") {
            remote.press(.right)
            Thread.sleep(forTimeInterval: 1.5)
            remote.press(.left)
            Thread.sleep(forTimeInterval: 1.5)
        }
    }

    func testHitchesOpeningASeries() throws {
        try XCTSkipUnless(benchmarks, "runs with TEST_RUNNER_ANTENNA_BENCHMARKS=1")
        open("series")
        enterRows("series")
        expectBothSources("series")
        measureGaps("a series page and back") {
            remote.press(.select)
            Thread.sleep(forTimeInterval: 2)
            remote.press(.menu)
            Thread.sleep(forTimeInterval: 2)
        }
    }

    /// One walk through the section for Instruments to record: across
    /// posters, down and up the rows, a series page and back, and Series and
    /// back from the bar. It waits 10 seconds first for the recording to attach.
    func testWalkForInstruments() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["ANTENNA_TRACE"] == "1", "runs with TEST_RUNNER_ANTENNA_TRACE=1")
        launch()
        Thread.sleep(forTimeInterval: 10)
        press(.menu)
        moveAlongTheBar(.right, to: "shell.tab.movies")
        press(.select)
        expectFocus("movies.hero.play")
        Thread.sleep(forTimeInterval: 2)
        enterRows("movies")
        for _ in 0..<12 { remote.press(.right) }
        Thread.sleep(forTimeInterval: 1)
        for _ in 0..<12 { remote.press(.left) }
        Thread.sleep(forTimeInterval: 1)
        for _ in 0..<6 {
            remote.press(.down)
            Thread.sleep(forTimeInterval: 0.3)
            remote.press(.right)
            Thread.sleep(forTimeInterval: 0.3)
        }
        for _ in 0..<6 {
            remote.press(.up)
            Thread.sleep(forTimeInterval: 0.3)
        }
        Thread.sleep(forTimeInterval: 1)
        remote.press(.select)
        Thread.sleep(forTimeInterval: 2)
        remote.press(.menu)
        Thread.sleep(forTimeInterval: 2)
        remote.press(.menu)
        Thread.sleep(forTimeInterval: 1)
        remote.press(.right)
        Thread.sleep(forTimeInterval: 2)
        remote.press(.select)
        Thread.sleep(forTimeInterval: 1)
        enterRows("series")
        for _ in 0..<12 { remote.press(.right) }
        Thread.sleep(forTimeInterval: 1)
        remote.press(.select)
        Thread.sleep(forTimeInterval: 3)
        remote.press(.menu)
        Thread.sleep(forTimeInterval: 2)
    }
}

extension ShelfLargeTVUITests {
    /// Frames the main thread missed so far, as the section's probe counts
    /// them, and posters a card asked for before they were in memory.
    struct Gaps {
        var frames = 0
        var dropped = 0
        var hitchMs = 0
        var posterMisses = 0
        var posterAsks = 0

        static func - (lhs: Gaps, rhs: Gaps) -> Gaps {
            Gaps(
                frames: lhs.frames - rhs.frames, dropped: lhs.dropped - rhs.dropped, hitchMs: lhs.hitchMs - rhs.hitchMs,
                posterMisses: lhs.posterMisses - rhs.posterMisses, posterAsks: lhs.posterAsks - rhs.posterAsks)
        }
    }
}
