import XCTest

/// The label of a prominent button on the accent: dark, never white.
@MainActor
final class ProminentLabelUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    // design-system/text-on-the-accent-is-dark
    // Prominent buttons drew a white label on the accent, 2.15:1 on Blue.
    func testPrimaryActionsDrawADarkLabelOnTheAccent() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-onboarding", "signedIn"]
        app.launchInEnglish()
        let addSource = element(app, "onboarding.addSource")
        XCTAssertTrue(addSource.waitForExistence(timeout: 10))
        try expectDarkLabel(addSource, app)

        addSource.tap()
        let connect = app.navigationBars["Add a source"].buttons["onboarding.connect"]
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
        try expectDarkLabel(connect, app)
    }

    /// The middle of the button, clear of its rounded ends, holds dark label
    /// pixels and no white ones.
    private func expectDarkLabel(_ button: XCUIElement, _ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) throws {
        // Let the press and the sheet settle before the screenshot.
        _ = button.waitForExistence(timeout: 1)
        let frame = button.frame
        let middle = frame.insetBy(dx: min(frame.width / 2 - 1, frame.height / 2), dy: frame.height * 0.3)
        let pixels = try ScreenPixels(app, file: file, line: line)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = button.identifier
        shot.lifetime = .keepAlways
        add(shot)
        let white = ScreenPixels.Color(red: 255, green: 255, blue: 255)
        let name = button.identifier
        XCTAssertLessThan(pixels.share(of: white, in: middle, tolerance: 48), 0.005, "a white label on \(name)", file: file, line: line)
        XCTAssertGreaterThan(pixels.share(of: .ground, in: middle, tolerance: 48), 0.02, "no dark label on \(name)", file: file, line: line)
    }
}
