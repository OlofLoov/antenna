import XCTest

/// The live-tv-on-iphone-ipad-mac capability in the iPad window. Runs on an
/// iPad simulator; on an iPhone every test skips. Uses the same scripted
/// launch as `LiveUITests`.
@MainActor
final class LiveRegularUITests: XCTestCase {
    nonisolated let log = FileManager.default.temporaryDirectory.appending(path: "live-engine-\(UUID().uuidString).log")

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: log)
    }

    private func launch() throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "the wide layout needs an iPad")
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"]
        app.launchEnvironment["UITESTING_ENGINE_LOG"] = log.path
        app.launch()
        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 10), "the channel list never appeared")
        return app
    }

    // live-tv-on-iphone-ipad-mac/sidebar-list-and-picture-side-by-side
    func testSidebarListAndPictureSitSideBySide() throws {
        let app = try launch()
        let sidebar = app.element("browse.sidebar").frame
        let list = app.element("browse.list").frame
        let player = app.element("browse.player").frame

        XCTAssertEqual(sidebar.width, 232, accuracy: 1)
        XCTAssertLessThanOrEqual(sidebar.maxX, list.minX + 1)
        XCTAssertLessThanOrEqual(list.maxX, player.minX + 1)
        XCTAssertLessThan(player.minY, list.maxY, "the picture sits beside the list, not under it")
        XCTAssertTrue(app.element("browse.section.live").isSelected)
        XCTAssertTrue(app.element("browse.nothingSelected").exists)
        XCTAssertFalse(app.element("browse.panel").exists)
        XCTAssertFalse(app.element("browse.toggleSidebar").exists)
    }

    // live-tv-on-iphone-ipad-mac/pick-a-group, the list's header on iPad and Mac
    func testPickingAGroupInTheSidebarHeadsTheListWithItsNameAndCount() throws {
        let app = try launch()
        XCTAssertEqual(app.element("browse.header.title").label, "All channels")
        XCTAssertEqual(app.element("browse.header.count").label, "5 channels")

        app.element("browse.group.2").tap()

        XCTAssertEqual(app.element("browse.header.title").label, "News")
        XCTAssertEqual(app.element("browse.header.count").label, "2 channels")
        XCTAssertTrue(app.row(1).exists)
        XCTAssertFalse(app.row(2).exists)
        XCTAssertTrue(app.element("browse.group.2").isSelected)
    }

    // live-tv-on-iphone-ipad-mac/watch-without-leaving-the-list, the details show the channel
    func testPickingAChannelShowsItsDetailsBesideTheList() throws {
        let app = try launch()
        app.row(0).tap()

        app.waitForEngine("playing loads=1")
        XCTAssertTrue(app.element("browse.panel").waitForExistence(timeout: 5))
        XCTAssertTrue(app.element("browse.panel.now").label.contains("Morning News"))
        XCTAssertTrue(app.element("browse.panel.now").label.contains("News One · 1"))
        XCTAssertTrue(app.row(0).isSelected)
        XCTAssertTrue(app.element("browse.list").exists)
    }

    // live-tv-on-iphone-ipad-mac/picture-pinned-at-the-top-on-iphone, switching between narrow and wide
    func testSwitchingBetweenNarrowAndWideKeepsTheChannelPlaying() throws {
        let app = try launch()
        app.row(0).tap()
        app.waitForEngine("playing loads=1")

        app.element("browse.debug.switchLayout").tap()
        XCTAssertTrue(app.element("browse.nowPlaying").waitForExistence(timeout: 5), "the narrow layout never showed")
        XCTAssertFalse(app.element("browse.sidebar").exists)
        app.waitForEngine("playing loads=1")

        app.element("browse.debug.switchLayout").tap()
        XCTAssertTrue(app.element("browse.sidebar").waitForExistence(timeout: 5), "the wide layout never came back")
        app.waitForEngine("playing loads=1")
        let loaded = ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n")
        XCTAssertEqual(loaded, ["news-one.ts"])
    }

    // live-tv-on-iphone-ipad-mac/see-what-is-on-now-and-next, up to three programmes next on iPad and Mac
    func testTheDetailsListUpToThreeProgrammesNext() throws {
        let app = try launch()
        app.row(0).tap()

        let next = app.element("browse.panel.next")
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        for title in ["Weather", "Business", "Sport Tonight"] {
            XCTAssertTrue(next.staticTexts[title].exists, "\(title) is missing")
        }
        XCTAssertFalse(next.staticTexts["Late Film"].exists, "three at most")
    }

    // live-tv-on-iphone-ipad-mac/see-what-is-on-now-and-next, nothing in the guide
    func testTheDetailsSayWhenTheGuideHasNothing() throws {
        let app = try launch()
        app.row(3).tap()

        let now = app.element("browse.panel.now")
        XCTAssertTrue(now.waitForExistence(timeout: 5))
        XCTAssertTrue(now.label.hasPrefix("No programme information"), now.label)
        XCTAssertFalse(app.element("browse.panel.next").exists)
    }

    // live-tv-on-iphone-ipad-mac/full-screen, the picture fills the window on iPad
    func testFullScreenFillsTheWindowWithThePictureAndItsControls() throws {
        let app = try launch()
        app.row(0).tap()
        app.waitForEngine("playing loads=1")
        app.element("browse.player.surface").tap()
        XCTAssertTrue(app.element("browse.player.pip").waitForExistence(timeout: 2), "iPad shows Picture in Picture")
        if !app.element("browse.player.controls").exists { app.element("browse.player.surface").tap() }
        app.element("browse.player.fullscreen").tap()

        let window = app.windows.firstMatch.frame
        let sidebarGone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: app.element("browse.sidebar"))
        XCTAssertEqual(XCTWaiter().wait(for: [sidebarGone], timeout: 3), .completed, "the columns stayed on screen")
        XCTAssertEqual(app.element("browse.player").frame.width, window.width, accuracy: 1)
        if !app.element("browse.player.controls").exists { app.element("browse.player.surface").tap() }
        app.element("browse.player.fullscreen").tap()

        XCTAssertTrue(app.element("browse.sidebar").waitForExistence(timeout: 3))
        XCTAssertLessThan(app.element("browse.player").frame.width, window.width - 500)
        app.waitForEngine("playing loads=1")
    }

    // live-tv-on-iphone-ipad-mac/star-a-channel, the sidebar count
    func testTheStarRaisesAndLowersTheFavoritesCount() throws {
        let app = try launch()
        let favorites = app.element("browse.group.0")
        XCTAssertTrue(favorites.label.hasSuffix("0"), favorites.label)
        app.row(0).tap()
        let star = app.element("browse.favorite")
        XCTAssertTrue(star.waitForExistence(timeout: 5))

        star.tap()
        XCTAssertTrue(favorites.label.hasSuffix("1"), favorites.label)
        star.tap()
        XCTAssertTrue(favorites.label.hasSuffix("0"), favorites.label)
    }
}
