import XCTest

/// Proves the target, the seed data and `snap` work together on Apple TV.
/// The real walk-throughs replace it in the next pull request.
@MainActor
final class SmokeJourney: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testFirstScreen() {
        let journey = Journey(self, scenario: "full")
        journey.snap("live", anchor: "shell.picture")
    }
}
