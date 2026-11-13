import XCTest

/// Screenshot walk-throughs on iPhone and iPad (add-app-screenshots-ci).
/// The change's design.md names the board each step compares with.
@MainActor
final class AppJourneys: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Opens a tab: its `browse.section.<id>` row in the iPad sidebar, or
    /// the tab bar button labelled `label` on iPhone. Tab bar buttons carry
    /// no identifier of their own, so there the label is the only handle, as
    /// in the other UI tests.
    private func open(_ id: String, label: String, in journey: Journey) {
        let button =
            UIDevice.current.userInterfaceIdiom == .pad ? journey.element("browse.section.\(id)") : journey.app.tabBars.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "no \(label) tab")
        button.tap()
    }

    /// What a new user sees before adding a source.
    func testFirstRun() {
        let journey = Journey(self, scenario: "empty")
        journey.snap("welcome", anchor: "onboarding.welcome")
        journey.element("onboarding.addSource").tap()
        journey.snap("add-source", anchor: "onboarding.connect")
    }

    /// The main tabs with two sources. The iPad's full-width window shows
    /// the regular guide, which has a toolbar in place of the compact root.
    func testBrowse() {
        let journey = Journey(self, scenario: "full")
        // The app reopens on the tab left last time, so the walk opens Live itself.
        open("live", label: "Live", in: journey)
        journey.snap("live", anchor: "browse.list")
        open("guide", label: "Guide", in: journey)
        journey.snap("guide", anchor: UIDevice.current.userInterfaceIdiom == .pad ? "guide.toolbar" : "guide.root")
        open("settings", label: "Settings", in: journey)
        journey.snap("settings", anchor: "settings.source.00000000-0000-0000-0000-0000000000C1")
        // Search last: its keyboard covers the iPhone tab bar.
        open("search", label: "Search", in: journey)
        journey.snap("search", anchor: "search.field")
    }

    /// Add a source from Settings, first as M3U and then as Xtream, and a
    /// source's details (refresh-visual-design, `iPhone-Refresh-AddSource`).
    func testSettingsAddSource() {
        let journey = Journey(self, scenario: "full")
        open("settings", label: "Settings", in: journey)
        let addSource = journey.element("settings.addSource")
        XCTAssertTrue(addSource.waitForExistence(timeout: 10), "no Add a source")
        addSource.tap()
        journey.snap("settings-add-source", anchor: "onboarding.connect")
        journey.element("onboarding.kind.xtream").tap()
        journey.snap("settings-add-source-xtream", anchor: "onboarding.field.password")
        journey.element("onboarding.back").tap()
        let home = journey.element("settings.source.00000000-0000-0000-0000-0000000000C1")
        XCTAssertTrue(home.waitForExistence(timeout: 10), "the sheet never closed")
        home.tap()
        journey.snap("source-details", anchor: "settings.details.status")
    }

    /// Live when every source loaded without channels (refresh-visual-design, `TV-Refresh-Shell-Empty`).
    func testLiveEmpty() {
        let journey = Journey(self, arguments: ["-ui-testing-live", "empty"])
        journey.snap("live-empty", anchor: "browse.empty")
    }

    /// Movies at the top, then scrolled to Recently watched and Recently
    /// added, with titles played on this profile (add-discover-rows,
    /// `iPhone-Movies`, `iPhone-Movies-Discover`, `iPad-Movies-Discover`).
    func testMoviesDiscover() {
        let journey = Journey(self, arguments: ["-ui-testing-shelf", "watching", "-ui-testing-reduce-motion"])
        open("movies", label: "Movies", in: journey)
        journey.snap("movies", anchor: "movies.hero.title")
        let row = journey.element("movies.row.recentlyWatched")
        for _ in 0..<4 where !(row.exists && row.isHittable) {
            journey.app.swipeUp()
        }
        journey.snap("movies-recently-watched", anchor: "movies.row.recentlyWatched")
    }

    /// Live with a channel the source gained since the day before, in the
    /// New group (add-discover-rows, `iPhone-Live-New`, `iPad-Live-New`).
    func testLiveNew() {
        let journey = Journey(
            self, arguments: ["-ui-testing-live", "channels"], environment: ["UITESTING_NEW_CHANNEL": "kids-one"])
        let new = journey.element("groups.new")
        if new.waitForExistence(timeout: 10) { new.tap() }
        journey.snap("live-new", anchor: "groups.new")
    }
}
