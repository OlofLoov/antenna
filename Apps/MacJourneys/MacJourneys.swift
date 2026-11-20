import XCTest

/// The App Store set on a Mac (polish-store-screenshots,
/// store-listing/store-screenshots-in-every-ready-language): the steps of
/// the iPhone and iPad walk in a 1440 by 900 point window, which the
/// store-shot launch sizes. Every step anchors on an identifier, never on a
/// translated label.
@MainActor
final class MacJourneys: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Opens a tab from its `browse.section.<id>` row in the sidebar.
    private func open(_ id: String, in journey: Journey) {
        let row = journey.element("browse.section.\(id)")
        XCTAssertTrue(row.waitForExistence(timeout: 10), "no \(id) in the sidebar")
        row.click()
    }

    /// Live with News One playing, the guide, Movies, a movie playing, and
    /// adding a source.
    func testStore() {
        let store = ["-ui-testing-store-shots", "-ApplePersistenceIgnoreState", "YES"]
        let journey = Journey(
            self, arguments: ["-ui-testing-live", "favorites"] + store, environment: ["UITESTING_CONTROLS_SECONDS": "1"])
        open("live", in: journey)
        let newsOne = journey.element("browse.row.00000000-0000-0000-0000-0000000000D1.0")
        XCTAssertTrue(newsOne.waitForExistence(timeout: 10), "no News One")
        newsOne.click()
        XCTAssertTrue(journey.element("browse.player.surface").waitForExistence(timeout: 10), "News One never played")
        journey.waitUntilGone("browse.player.controls")
        journey.snap("live", anchor: "browse.list")
        open("guide", in: journey)
        journey.snap("guide", anchor: "guide.toolbar")
        journey.launch(["-ui-testing-shelf", "watching", "-ui-testing-reduce-motion"] + store)
        open("movies", in: journey)
        journey.snap("movies", anchor: "movies.hero.title")
        let poster = journey.element("movies.card.xtream#cabin#vod#2")
        if poster.waitForExistence(timeout: 10) { poster.click() }
        journey.waitForPicture()
        journey.snap("player", anchor: "title.transport")
        journey.launch(["-ui-screenshots", "empty"] + store)
        let add = journey.element("onboarding.addSource")
        XCTAssertTrue(add.waitForExistence(timeout: 10), "no Add a source")
        add.click()
        journey.snap("add-source", anchor: "onboarding.connect")
    }
}
