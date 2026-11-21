import XCTest

/// File > New Window on the Mac opens a window only while none is open
/// (live-tv-on-iphone-ipad-mac/one-window-on-the-mac).
@MainActor
final class OneWindowTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func windowCount(_ app: XCUIApplication, settlesAt expected: Int) -> Bool {
        let settled = expectation(for: NSPredicate { _, _ in app.windows.count == expected }, evaluatedWith: nil)
        return XCTWaiter.wait(for: [settled], timeout: 5) == .completed
    }

    // live-tv-on-iphone-ipad-mac/one-window-on-the-mac
    func testNewWindowOnlyWhenNoneIsOpen() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-screenshots", "empty", "-ApplePersistenceIgnoreState", "YES"]
        app.launchInEnglish()
        if !app.windows.firstMatch.waitForExistence(timeout: 5) {
            app.typeKey("n", modifierFlags: .command)
        }
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10), "no window")
        XCTAssertTrue(windowCount(app, settlesAt: 1))

        app.typeKey("n", modifierFlags: .command)
        sleep(1)
        XCTAssertEqual(app.windows.count, 1, "File > New Window opened a second window")
        XCTAssertFalse(app.menuBars.menuItems["New Window"].isEnabled, "New Window is offered with a window open")

        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(windowCount(app, settlesAt: 0), "the window did not close")
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(windowCount(app, settlesAt: 1), "File > New Window did not open a window with none open")
    }
}
