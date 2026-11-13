import XCTest

/// Adding and removing favorites from a channel's menu, a swipe and the
/// full-screen controls on iPhone (favorites capability), on the scripted
/// launch of `LiveUITests`. Row 1 is Home's News Two.
@MainActor
final class FavoriteActionsUITests: XCTestCase {
    nonisolated let log = FileManager.default.temporaryDirectory.appending(path: "favorite-engine-\(UUID().uuidString).log")

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: log)
    }

    private func launch() throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "the narrow layout tests run on an iPhone")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-live", "channels"]
        app.launchEnvironment["UITESTING_ENGINE_LOG"] = log.path
        app.launch()
        XCTAssertTrue(app.row(1).waitForExistence(timeout: 10), "the channel list never appeared")
        return app
    }

    private func menuItem(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let item = app.buttons[identifier].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "no \(identifier) in the menu")
        return item
    }

    /// Opens Favorites and checks whether News Two is listed in it.
    private func expectNewsTwoInFavorites(_ app: XCUIApplication, _ listed: Bool, file: StaticString = #filePath, line: UInt = #line) {
        app.element("browse.group.0").tap()
        if listed {
            XCTAssertTrue(app.row(1).waitForExistence(timeout: 5), "News Two is not in Favorites", file: file, line: line)
            XCTAssertFalse(app.row(0).exists, file: file, line: line)
        } else {
            XCTAssertTrue(app.element("browse.emptyGroup").waitForExistence(timeout: 5), "Favorites is not empty", file: file, line: line)
        }
    }

    // favorites/favorite-from-a-channel-s-menu
    func testTheRowMenuAddsAndRemovesAFavoriteWithoutPlaying() throws {
        let app = try launch()
        app.row(1).press(forDuration: 1.2)
        let add = menuItem(app, "browse.menu.favorite")
        XCTAssertEqual(add.label, "Add to Favorites")
        add.tap()

        expectNewsTwoInFavorites(app, true)
        XCTAssertTrue(app.element("browse.nothingSelected").exists, "adding a favorite does not play the channel")

        app.row(1).press(forDuration: 1.2)
        let remove = menuItem(app, "browse.menu.favorite")
        XCTAssertEqual(remove.label, "Remove from Favorites")
        remove.tap()
        XCTAssertTrue(app.element("browse.emptyGroup").waitForExistence(timeout: 5), "Favorites is empty again")
    }

    // favorites/swipe-a-channel-into-favorites
    func testAFullSwipeAddsAndASwipeInFavoritesRemoves() throws {
        let app = try launch()
        let row = app.row(1)
        // A drag across the whole row; swipeRight starts at the center and stops short of a full swipe.
        let end = row.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5))
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0)

        expectNewsTwoInFavorites(app, true)

        app.row(1).swipeRight(velocity: .slow)
        let remove = menuItem(app, "browse.swipe.favorite")
        XCTAssertEqual(remove.label, "Remove from Favorites")
        remove.tap()
        XCTAssertTrue(app.element("browse.emptyGroup").waitForExistence(timeout: 5), "Favorites is empty again")
    }

    // favorites/favorite-from-a-channel-s-menu, the Guide's channel column
    func testTheGuideChannelMenuAddsAFavorite() throws {
        let app = try launch()
        app.tabBars.buttons["Guide"].tap()
        let channel = app.element("guide.channel.\(LiveUITests.home).1")
        XCTAssertTrue(channel.waitForExistence(timeout: 10), "the guide never listed News Two")
        channel.press(forDuration: 1.2)
        menuItem(app, "guide.menu.favorite").tap()
        XCTAssertTrue(app.element("guide.root").exists, "the Guide stays open")

        app.tabBars.buttons["Live"].tap()
        expectNewsTwoInFavorites(app, true)
    }

    // favorites/favorite-from-full-screen
    func testTheFullScreenStarAddsThePlayingChannel() throws {
        let app = try launch()
        app.row(1).tap()
        app.waitForEngine("playing loads=1")
        app.element("browse.player.surface").tap()
        XCTAssertTrue(app.element("browse.player.controls").waitForExistence(timeout: 3))
        XCTAssertFalse(app.element("browse.player.favorite").exists, "no star in the controls outside full screen")
        app.element("browse.player.fullscreen").tap()

        let star = app.element("browse.player.favorite")
        if !star.waitForExistence(timeout: 2) { app.element("browse.player.surface").tap() }
        XCTAssertTrue(star.waitForExistence(timeout: 3), "no star in the full-screen controls")
        XCTAssertEqual(star.label, "Add to favorites")
        star.tap()
        XCTAssertEqual(star.label, "Remove from favorites")

        if !app.element("browse.player.fullscreen").exists { app.element("browse.player.surface").tap() }
        app.element("browse.player.fullscreen").tap()
        XCTAssertTrue(app.element("browse.list").waitForExistence(timeout: 3))
        expectNewsTwoInFavorites(app, true)
    }
}
