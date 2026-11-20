import XCTest

/// Screenshot walk-throughs on iPhone and iPad (add-app-screenshots-ci).
/// The change's design.md names the board each step compares with.
@MainActor
final class AppJourneys: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Opens a tab: its `browse.section.<id>` row in the iPad sidebar, or
    /// its place in the iPhone tab bar (Live, Guide, Movies when a source
    /// offers titles, Search, Settings). Tab bar buttons take no identifier
    /// from SwiftUI, and their labels are translated, so the place is the
    /// handle that works in every language.
    private func open(_ id: String, label: String, in journey: Journey) {
        let button: XCUIElement
        if UIDevice.current.userInterfaceIdiom == .pad {
            button = journey.element("browse.section.\(id)")
        } else {
            let buttons = journey.app.tabBars.firstMatch.buttons
            XCTAssertTrue(buttons.firstMatch.waitForExistence(timeout: 10), "no tab bar")
            let count = buttons.count
            let index = ["live": 0, "guide": 1, "movies": 2, "search": count - 2, "settings": count - 1][id] ?? 0
            button = buttons.element(boundBy: index)
        }
        XCTAssertTrue(button.waitForExistence(timeout: 10), "no \(label) tab")
        button.tap()
    }

    /// The App Store set, in the language the runner's `STORE_LANGUAGE`
    /// names: Live with News One playing, the guide, Movies, a movie playing,
    /// and adding a source (add-store-localization,
    /// store-listing/store-screenshots-in-every-ready-language). Every step
    /// anchors on an identifier, never on a translated label.
    /// `-ui-testing-store-shots` fills the guide, plays the store clip and
    /// hides the test probes.
    func testStore() {
        let store = "-ui-testing-store-shots"
        let journey = Journey(
            self, arguments: ["-ui-testing-live", "favorites", store], environment: ["UITESTING_CONTROLS_SECONDS": "1"])
        open("live", label: "Live", in: journey)
        let newsOne = journey.element("browse.row.00000000-0000-0000-0000-0000000000D1.0")
        XCTAssertTrue(newsOne.waitForExistence(timeout: 10), "no News One")
        newsOne.tap()
        XCTAssertTrue(journey.element("browse.player.surface").waitForExistence(timeout: 10), "News One never played")
        journey.waitUntilGone("browse.player.controls")
        journey.snap("live", anchor: "browse.list")
        open("guide", label: "Guide", in: journey)
        journey.snap("guide", anchor: UIDevice.current.userInterfaceIdiom == .pad ? "guide.toolbar" : "guide.root")
        journey.launch(["-ui-testing-shelf", "watching", "-ui-testing-reduce-motion", store])
        open("movies", label: "Movies", in: journey)
        journey.snap("movies", anchor: "movies.hero.title")
        let poster = journey.element("movies.card.xtream#cabin#vod#2")
        if poster.waitForExistence(timeout: 10) { poster.tap() }
        journey.waitForPicture()
        journey.snap("player", anchor: "title.transport")
        journey.launch(["-ui-screenshots", "empty", store])
        let add = journey.element("onboarding.addSource")
        XCTAssertTrue(add.waitForExistence(timeout: 10), "no Add a source")
        add.tap()
        journey.snap("add-source", anchor: "onboarding.connect")
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

    /// Add a source from Settings: the Xtream form, the Type menu, the M3U
    /// form, then a source's details (refresh-visual-design, `iPhone-Onboard-2`,
    /// `iPhone-Onboard-2-M3U`, `iPad-Onboard-2`).
    func testSettingsAddSource() {
        let journey = Journey(self, scenario: "full")
        open("settings", label: "Settings", in: journey)
        let addSource = journey.element("settings.addSource")
        XCTAssertTrue(addSource.waitForExistence(timeout: 10), "no Add a source")
        addSource.tap()
        journey.snap("settings-add-source", anchor: "onboarding.connect")
        journey.element("onboarding.kind").tap()
        let playlist = journey.app.buttons["M3U playlist"].firstMatch
        XCTAssertTrue(playlist.waitForExistence(timeout: 5), "the Type menu never opened")
        journey.snap("settings-add-source-kinds", anchor: "onboarding.connect")
        playlist.tap()
        journey.snap("settings-add-source-m3u", anchor: "onboarding.field.playlist")
        journey.element("onboarding.back").tap()
        let home = journey.element("settings.source.00000000-0000-0000-0000-0000000000C1")
        XCTAssertTrue(home.waitForExistence(timeout: 10), "the sheet never closed")
        home.tap()
        journey.snap("source-details", anchor: "settings.details.status")
    }

    /// Live when every source loaded without channels (`iPhone-Live-Empty`).
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

    /// A movie's cast and crew, then Mira Holt's page (add-browse-by-person,
    /// `iPhone-Title-Cast`, `iPhone-Person`, `iPad-Person`).
    func testPerson() {
        let journey = Journey(self, arguments: ["-ui-testing-shelf", "titles", "-ui-testing-reduce-motion"])
        open("movies", label: "Movies", in: journey)
        let info = journey.element("movies.hero.info")
        if info.waitForExistence(timeout: 10) { info.tap() }
        journey.snap("title-cast", anchor: "title.cast.0")
        journey.element("title.cast.0").tap()
        journey.snap("person", anchor: "person.header")
    }

    /// A movie playing with its controls up (add-title-transport-controls,
    /// `iPhone-Title-Player-Transport`, `iPad-Title-Player-Transport`).
    func testMoviePlayer() {
        let journey = Journey(self, arguments: ["-ui-testing-shelf", "watching", "-ui-testing-reduce-motion"])
        open("movies", label: "Movies", in: journey)
        let poster = journey.element("movies.card.xtream#cabin#vod#2")
        if poster.waitForExistence(timeout: 10) { poster.tap() }
        journey.snap("movie-player-transport", anchor: "title.transport")
    }

    /// Live with a channel the source gained since the day before, in the
    /// New group (add-discover-rows, `iPhone-Live-New`, `iPad-Live-New`).
    func testLiveNew() {
        let journey = Journey(
            self, arguments: ["-ui-testing-live", "channels"], environment: ["UITESTING_NEW_CHANNEL": "kids-one"])
        // On iPhone New is a row of the Groups sheet (`iPhone-Live-Groups`); iPad lists it in the sidebar.
        let new = journey.element("groups.new")
        if journey.element("browse.list").waitForExistence(timeout: 10), !new.exists { journey.element("browse.groups").tap() }
        if new.waitForExistence(timeout: 10) { new.tap() }
        journey.snap("live-new", anchor: "browse.list")
    }
}
