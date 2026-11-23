import XCTest

/// Moving up through the rows of Movies and Series on Apple TV with the
/// preview showing. Launches the shelf's `watching` script, whose Series
/// rows are Continue watching, Recently watched, Recently added and a row
/// per category, and whose Movies add My list.
@MainActor
final class ShelfRowsUpTVUITests: XCTestCase {
    let remote = XCUIRemote.shared
    var app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// The section's tab opened from the bar, with focus on the banner's Play button.
    func open(_ tab: String) {
        app.launchArguments = ["-ui-testing-shelf", "watching"]
        app.launchInEnglish()
        // The system bar takes Menu only once something on the page has focus.
        _ = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch.waitForExistence(timeout: 10)
        remote.press(.menu)
        XCTAssertTrue(element("shell.tab.\(tab)").waitForExistence(timeout: 10))
        moveAlongTheBar(.right, to: "shell.tab.\(tab)")
        remote.press(.select)
        XCTAssertTrue(element("\(tab).hero.play").waitForExistence(timeout: 10))
        // Play takes focus a second time once the titles have loaded.
        Thread.sleep(forTimeInterval: 1)
    }

    /// Waits for the row with `identifier` to hold the highlight and come to
    /// rest wholly between the preview's foot and the foot of the screen.
    func expectPlaced(_ tab: String, _ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let row = element("\(tab).row.\(identifier)")
        let preview = element("\(tab).preview")
        let focused = row.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
        var placed = false
        for _ in 0..<15 {
            if focused.exists, preview.exists, row.frame.minY >= preview.frame.maxY, row.frame.maxY <= app.frame.maxY {
                placed = true
                break
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertTrue(focused.exists, "\(identifier) does not hold the highlight", file: file, line: line)
        XCTAssertTrue(
            placed, "\(identifier) at \(row.frame) is not wholly below the preview at \(preview.frame)", file: file, line: line)
    }

    func walk(_ tab: String, rows: [String]) {
        open(tab)
        for row in rows {
            remote.press(.down)
            expectPlaced(tab, row)
        }
        for row in rows.reversed().dropFirst() {
            remote.press(.up)
            expectPlaced(tab, row)
        }
        // Two quick presses up, from the last row to two above it.
        for row in rows.dropFirst() {
            remote.press(.down)
            expectPlaced(tab, row)
        }
        remote.press(.up)
        remote.press(.up)
        expectPlaced(tab, rows[rows.count - 3])
    }

    // movies-and-series-browsing/preview-of-the-focused-title-on-apple-tv, moving up to the row above
    // Owner-found on 2026-11-23: moving up left the row under the preview, then slid it down late.
    func testMovingUpInSeriesPutsTheRowBelowThePreview() {
        walk("series", rows: ["continueWatching", "recentlyWatched", "recentlyAdded", "drama"])
    }

    // movies-and-series-browsing/preview-of-the-focused-title-on-apple-tv, moving up to the row above
    func testMovingUpInMoviesPutsTheRowBelowThePreview() {
        walk("movies", rows: ["continueWatching", "myList", "recentlyWatched", "recentlyAdded"])
    }
}
