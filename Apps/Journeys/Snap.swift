import XCTest

/// One screenshot walk-through: the app launched on seeded data, and a
/// numbered screenshot per step. CI exports the screenshots from the result
/// bundle as `<device>/<test>/<nn>-<step>.png` (add-app-screenshots-ci).
@MainActor
final class Journey {
    private(set) var app = XCUIApplication()
    private let test: XCTestCase
    private var steps = 0

    /// Launches the app with `-ui-screenshots <scenario>`.
    convenience init(_ test: XCTestCase, scenario: String) {
        self.init(test, arguments: ["-ui-screenshots", scenario])
    }

    /// Launches the app with `arguments`, for a scenario another UI test
    /// target already seeds, such as `-ui-testing-shell loading`.
    init(_ test: XCTestCase, arguments: [String]) {
        self.test = test
        launch(arguments)
    }

    /// Ends the running app and starts it again with `arguments`. Step
    /// numbers carry on.
    func launch(_ arguments: [String]) {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Waits up to 10 seconds for the element with identifier `anchor`, then
    /// attaches a screenshot named `<nn>-<step>`. Fails the test when the
    /// anchor never appears, with the accessibility tree attached.
    func snap(_ step: String, anchor: String, file: StaticString = #filePath, line: UInt = #line) {
        guard element(anchor).waitForExistence(timeout: 10) else {
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "tree-\(step)"
            tree.lifetime = .keepAlways
            test.add(tree)
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
