import XCTest

/// The New group in the Apple TV channel overlay (new-channels capability),
/// over the shell's `channels` scenario. `UITESTING_NEW_CHANNEL` names the
/// channel Home gained since a load the day before (`UITestingRecents`).
extension ShellUITests {
    // new-channels/a-new-group-lists-channels-added-lately, Apple TV overlay
    func testNewListsTheGainedChannelAndPlayingKeepsTheGroup() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels"]
        app.launchEnvironment["UITESTING_NEW_CHANNEL"] = "a3"
        app.launch()
        expectEngine("playing loads=1 file=a1.ts")
        expectFocus("shell.picture")
        expectGone("zapBar.bar", timeout: 10)
        openOverlay()
        expectFocusedRow("Channel a1")
        let new = element("overlay.group.new")
        XCTAssertTrue(new.waitForExistence(timeout: 5))
        XCTAssertTrue(new.label.contains("New, 1 channel"), "label is \(new.label)")
        XCTAssertTrue(element("overlay.group.0").label.contains("Favorites"))
        XCTAssertTrue(element("overlay.group.2").label.contains("All channels"))

        // Home's Ungrouped is the current group; New sits two above it.
        press(.left, toFocus: element("overlay.group.3"), from: overlayRows().element(boundBy: 0))
        press(.up, toFocus: element("overlay.group.2"), from: element("overlay.group.3"))
        press(.up, toFocus: new, from: element("overlay.group.2"))
        expect(overlayRows().element(boundBy: 0), "label CONTAINS 'Channel a3'")
        XCTAssertEqual(overlayRows().count, 1)
        press(.right, toFocus: overlayRows().element(boundBy: 0), from: new)
        press(.select)
        expectGone("overlay.root")
        expectEngine("playing loads=2 file=a3.ts")
        expectGone("zapBar.bar", timeout: 10)

        // Up steps through Home's Ungrouped, a3 wrapping round to a1.
        press(.up)
        expectEngine("playing loads=3 file=a1.ts")
    }

    // new-channels/a-new-source-starts-with-nothing-new, Apple TV overlay
    func testAFirstLoadHasNoNewGroupInTheOverlay() {
        launchPlaying()
        openOverlay()
        XCTAssertTrue(element("overlay.group.1").waitForExistence(timeout: 5))
        XCTAssertTrue(element("overlay.group.1").label.contains("All channels"))
        XCTAssertFalse(element("overlay.group.new").exists)
    }
}
