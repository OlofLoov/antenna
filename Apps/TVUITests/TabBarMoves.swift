import XCTest

extension XCTestCase {
    /// Moves the highlight along the system tab bar until `identifier` has
    /// it. A tab opens as the highlight lands on it, which can swallow a
    /// quick second press, so this presses once at a time and waits for the
    /// highlight to leave the tab it was on before pressing again; a slow
    /// focus change then cannot carry it past `identifier`.
    @MainActor
    func moveAlongTheBar(
        _ direction: XCUIRemote.Button, to identifier: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        let app = XCUIApplication()
        let target = app.descendants(matching: .any)[identifier].firstMatch
        let focused = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
        for _ in 0..<8 where !(target.exists && target.hasFocus) {
            let origin = focused.exists ? focused.identifier : ""
            XCUIRemote.shared.press(direction)
            let deadline = Date.now.addingTimeInterval(3)
            while Date.now < deadline, !target.hasFocus, !focused.exists || focused.identifier == origin {
                Thread.sleep(forTimeInterval: 0.2)
            }
        }
        XCTAssertTrue(target.exists && target.hasFocus, "\(identifier) never took focus", file: file, line: line)
    }
}
