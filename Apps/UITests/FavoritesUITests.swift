import XCTest

/// Spec 0005, the Favorites tab. Each test launches the app on an in-memory
/// store seeded through the `-ui-testing-favorites` launch argument
/// (`UITestingStore`), so nothing reaches iCloud.
@MainActor
final class FavoritesUITests: XCTestCase {
    // favorites/empty-state
    func testEmptyStateWhenThereAreNoFavorites() {
        let app = launch(favorites: [])

        let emptyState = app.descendants(matching: .any)["favorites.emptyState"].firstMatch
        XCTAssertTrue(emptyState.waitForExistence(timeout: 10))
        XCTAssertFalse(app.collectionViews["favorites.list"].exists)
    }

    // favorites/list-order
    func testRowsFollowSortOrder() {
        let app = launch(favorites: [2, 0, 1])

        let list = app.collectionViews["favorites.list"]
        XCTAssertTrue(list.waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["favorites.emptyState"].firstMatch.exists)

        let cells = list.cells
        XCTAssertEqual(cells.count, 3)
        let expected = ["channel-0", "channel-1", "channel-2"]
        var previousTop = -CGFloat.infinity
        for (index, channelID) in expected.enumerated() {
            let cell = cells.element(boundBy: index)
            XCTAssertTrue(cell.staticTexts[channelID].exists, "row \(index) should show \(channelID)")
            XCTAssertGreaterThan(cell.frame.minY, previousTop, "row \(index) should sit below row \(index - 1)")
            previousTop = cell.frame.minY
        }
    }

    private func launch(favorites sortOrders: [Int]) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-favorites", sortOrders.map(String.init).joined(separator: ",")]
        app.launch()

        // The tab bar belongs to the shell, which spec 0005 does not cover, so
        // its button has no identifier and is found by its label.
        let tab = app.tabBars.buttons["Favorites"]
        let button = tab.waitForExistence(timeout: 10) ? tab : app.buttons["Favorites"].firstMatch
        XCTAssertTrue(button.exists, "no Favorites tab button")
        button.tap()
        return app
    }
}
