import XCTest

/// Settings, About.
@MainActor
final class SettingsUITests: XCTestCase {
    // The FFmpeg notice that FFmpeg's LGPL license asks for (add-playback-engine task 6.2).
    func testAboutShowsTheFFmpegNotice() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-favorites", ""]
        app.launch()

        let tab = app.tabBars.buttons["Settings"]
        let button = tab.waitForExistence(timeout: 10) ? tab : app.buttons["Settings"].firstMatch
        XCTAssertTrue(button.exists, "no Settings tab button")
        button.tap()

        let notice = app.descendants(matching: .any)["settings.ffmpegNotice"].firstMatch
        if !notice.waitForExistence(timeout: 5) { app.swipeUp() }
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        notice.tap()

        let text = app.staticTexts["ffmpegNotice.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertTrue(text.label.contains("GNU Lesser General Public License, version 2.1"))
        XCTAssertTrue(app.descendants(matching: .any)["ffmpegNotice.source"].firstMatch.exists)
    }
}
