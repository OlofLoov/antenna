import XCTest

extension XCTestCase {
    /// Moves the highlight along the system tab bar until `identifier` has
    /// it. A tab opens as the highlight lands on it, which can swallow a
    /// quick second press, so this presses once at a time.
    @MainActor
    func moveAlongTheBar(
        _ direction: XCUIRemote.Button, to identifier: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        let target = XCUIApplication().descendants(matching: .any)[identifier].firstMatch
        for _ in 0..<8 where !(target.exists && target.hasFocus) {
            XCUIRemote.shared.press(direction)
            _ = XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasFocus == true"), object: target)], timeout: 1)
        }
        XCTAssertTrue(target.exists && target.hasFocus, "\(identifier) never took focus", file: file, line: line)
    }
}
