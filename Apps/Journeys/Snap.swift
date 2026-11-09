import XCTest

/// One screenshot walk-through: the app launched with `-ui-screenshots
/// <scenario>`, and a numbered screenshot per step. CI exports the
/// screenshots from the result bundle (add-app-screenshots-ci).
@MainActor
final class Journey {
    let app = XCUIApplication()
    private let test: XCTestCase
    private var steps = 0

    init(_ test: XCTestCase, scenario: String) {
        self.test = test
        app.launchArguments = ["-ui-screenshots", scenario]
        app.launch()
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Waits up to 10 seconds for the element with identifier `anchor`, then
    /// attaches a screenshot named `<nn>-<step>`. Fails the test when the
    /// anchor never appears.
    func snap(_ step: String, anchor: String, file: StaticString = #filePath, line: UInt = #line) {
        guard element(anchor).waitForExistence(timeout: 10) else {
            XCTFail("step \(step): \(anchor) never appeared", file: file, line: line)
            return
        }
        steps += 1
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = String(format: "%02d-%@", steps, step)
        attachment.lifetime = .keepAlways
        test.add(attachment)
    }
}
