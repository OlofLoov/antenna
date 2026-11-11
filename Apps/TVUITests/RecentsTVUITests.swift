import XCTest

/// Recents in the Apple TV channel overlay (session-restore-and-recently-watched capability),
/// over the shell's `channels` scenario with recents seeded through
/// `UITESTING_RECENTS` (`UITestingRecents`).
extension ShellUITests {
    /// The `channels` scenario with `recents` seeded, a1 playing full screen.
    func launchPlaying(recents: String) {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels"]
        app.launchEnvironment["UITESTING_RECENTS"] = recents
        app.launch()
        expectEngine("playing loads=1 file=a1.ts")
        expectFocus("shell.picture")
        expectGone("zapBar.bar", timeout: 10)
    }

    // session-restore-and-recently-watched/recents-sits-between-favorites-and-all-channels
    func testRecentsSitsBetweenFavoritesAndAllChannelsInTheOverlay() {
        launchPlaying(recents: "b1,a2")
        openOverlay()
        let recents = element("overlay.group.1")
        XCTAssertTrue(recents.waitForExistence(timeout: 5))
        XCTAssertTrue(recents.label.contains("Recents, 2 channels"), "label is \(recents.label)")
        XCTAssertEqual(recents.value as? String, "2")
        XCTAssertTrue(element("overlay.group.0").label.contains("Favorites"))
        XCTAssertTrue(element("overlay.group.2").label.contains("All channels"))
    }

    // session-restore-and-recently-watched/recents-sits-between-favorites-and-all-channels, nothing to list
    func testRecentsIsHiddenInTheOverlayWithNothingToList() {
        launchPlaying(recents: "gone")
        openOverlay()
        XCTAssertTrue(element("overlay.group.1").waitForExistence(timeout: 5))
        XCTAssertTrue(element("overlay.group.1").label.contains("All channels"))
    }

    // session-restore-and-recently-watched/playing-from-recents-keeps-your-group-on-apple-tv
    func testPlayingFromRecentsKeepsTheCurrentGroup() {
        launchPlaying(recents: "a3,b1")
        openOverlay()
        expectFocusedRow("Channel a1")
        // Home's Ungrouped is the current group; Recents sits two above it.
        press(.left, toFocus: element("overlay.group.3"), from: overlayRows().element(boundBy: 0))
        press(.up, toFocus: element("overlay.group.2"), from: element("overlay.group.3"))
        press(.up, toFocus: element("overlay.group.1"), from: element("overlay.group.2"))
        expect(overlayRows().element(boundBy: 0), "label CONTAINS 'Channel a3'")
        press(.right, toFocus: overlayRows().element(boundBy: 0), from: element("overlay.group.1"))
        press(.select)
        expectGone("overlay.root")
        expectEngine("playing loads=2 file=a3.ts")
        expectGone("zapBar.bar", timeout: 10)

        // Up steps through Home's Ungrouped, a3 wrapping round to a1, not on to b1 in Recents.
        press(.up)
        expectEngine("playing loads=3 file=a1.ts")
    }
}
