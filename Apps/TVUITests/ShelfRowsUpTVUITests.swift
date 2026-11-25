import XCTest

/// Moving down and up through the rows of Movies and Series on Apple TV.
/// Launches the shelf's `watching` script, whose Series rows are Continue
/// watching, Recently watched, Recently added and a row per category, and
/// whose Movies add My list.
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
    func open(_ tab: String, arguments: [String]) {
        app.launchArguments = ["-ui-testing-shelf", "watching"] + arguments
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
    /// rest wholly on screen, its top just under the tab bar.
    func expectPlaced(_ tab: String, _ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let row = element("\(tab).row.\(identifier)")
        let focused = row.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
        var placed = false
        for _ in 0..<15 {
            if focused.exists, (120...200).contains(row.frame.minY), row.frame.maxY <= app.frame.maxY {
                placed = true
                break
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        let holder = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
        XCTAssertTrue(
            focused.exists, "\(identifier) does not hold the highlight; \(holder.exists ? holder.identifier : "nothing") does",
            file: file, line: line)
        XCTAssertTrue(
            placed, "\(identifier) at \(row.frame) does not rest just under the tab bar", file: file, line: line)
    }

    func walk(_ tab: String, rows: [String], arguments: [String] = []) {
        open(tab, arguments: arguments)
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

    // movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv, moving up to the row above
    // Owner-found on 2026-11-23: moving up left the row under the top of the screen, then slid it down late.
    func testMovingUpInSeriesPutsTheRowUnderTheTabBar() {
        walk("series", rows: ["continueWatching", "recentlyWatched", "recentlyAdded", "drama"])
    }

    // movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv, moving up to the row above
    // CI on 2026-11-24: the focus engine's own scroll landed after the screen's and left the row
    // at the tab bar's foot. The launch argument makes that happen on every move up.
    func testMovingUpPutsTheRowUnderTheTabBarWhenTheFocusEngineScrollsLast() {
        walk(
            "series", rows: ["continueWatching", "recentlyWatched", "recentlyAdded", "drama"],
            arguments: ["-ui-testing-focus-scroll-wins"])
    }

    // movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv, moving up to the row above
    func testMovingUpInMoviesPutsTheRowUnderTheTabBar() {
        walk("movies", rows: ["continueWatching", "myList", "recentlyWatched", "recentlyAdded"])
    }
}
