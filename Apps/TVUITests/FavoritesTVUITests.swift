import XCTest

/// Favorites on Apple TV over the shell's scripted `channels` scenario:
/// Channel a1 plays at launch from the Home playlist, nothing is a favorite.
extension ShellUITests {
    /// Holds select long enough for tvOS to open the focused item's menu,
    /// and waits for the favorite item in it.
    func holdSelect(for item: String) -> XCUIElement {
        remote.press(.select, forDuration: 1.5)
        let entry = element(item)
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "\(item) never showed; focused: \(focusedElements())")
        return entry
    }

    // favorites/hold-select-to-favorite-on-apple-tv
    func testHoldSelectOnAnOverlayRow() {
        launchPlaying()
        openOverlay()
        expectFocusedRow("Channel a1")
        expect(element("overlay.group.0"), "value == '0'")

        let add = holdSelect(for: "overlay.menu.favorite")
        XCTAssertEqual(add.label, "Add to Favorites")
        press(.select)
        expectGone("overlay.menu.favorite")
        expect(element("overlay.group.0"), "value == '1'")
        expectEngine("playing loads=1 file=a1.ts")
        expectFocusedRow("Channel a1")

        // Menu closes the menu and changes nothing.
        let remove = holdSelect(for: "overlay.menu.favorite")
        XCTAssertEqual(remove.label, "Remove from Favorites")
        press(.menu)
        expectGone("overlay.menu.favorite")
        XCTAssertTrue(element("overlay.root").exists, "the overlay stays")
        expect(element("overlay.group.0"), "value == '1'")
        expectFocusedRow("Channel a1")
    }

    // favorites/hold-select-to-favorite-on-apple-tv
    // favorites/favorites-on-apple-tv
    func testHoldSelectInFavoritesAndTheGuide() {
        launchPlaying()
        openOverlay()
        _ = holdSelect(for: "overlay.menu.favorite")
        press(.select)
        expect(element("overlay.group.0"), "value == '1'")

        // Favorites lists the channel, and selecting it tunes from Favorites.
        press(.left, toFocus: element("overlay.group.2"), from: row(named: "Channel a1"))
        press(.up, toFocus: element("overlay.group.1"), from: element("overlay.group.2"))
        press(.up, toFocus: element("overlay.group.0"), from: element("overlay.group.1"))
        expect(element("overlay.channelsHeader"), "label CONTAINS 'FAVORITES'")
        XCTAssertEqual(overlayRows().count, 1)
        press(.right, toFocus: row(named: "Channel a1"), from: element("overlay.group.0"))
        press(.select)
        expectGone("overlay.root")
        expectEngine("playing loads=1 file=a1.ts")

        // The Guide shows Favorites; holding select there removes the one row.
        openGuide()
        expectHighlight("guide.block.\(homeKey(0)).")
        let remove = holdSelect(for: "guide.menu.favorite")
        XCTAssertEqual(remove.label, "Remove from Favorites")
        press(.select)
        expectGone("guide.grid")
        let day = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'guide.day.' AND hasFocus == true"))
        XCTAssertTrue(day.firstMatch.waitForExistence(timeout: 10), "focus moves to the day chips; focused: \(focusedElements())")
        expectEngine("playing loads=1 file=a1.ts")
    }

    // favorites/hold-select-to-favorite-on-apple-tv
    func testHoldSelectOnTheGuideGrid() {
        launchPlaying()
        openGuide()
        expectHighlight("guide.block.\(homeKey(0)).")
        let add = holdSelect(for: "guide.menu.favorite")
        XCTAssertEqual(add.label, "Add to Favorites")
        press(.select)
        expectGone("guide.menu.favorite")
        expectFocus("guide.grid")
        expectHighlight("guide.block.\(homeKey(0)).")
        expectEngine("playing loads=1 file=a1.ts")

        let remove = holdSelect(for: "guide.menu.favorite")
        XCTAssertEqual(remove.label, "Remove from Favorites")
        press(.menu)
        expectGone("guide.menu.favorite")
        expectFocus("guide.grid")
    }
}
