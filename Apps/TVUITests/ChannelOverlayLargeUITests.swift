import XCTest

/// Moving between the overlay's columns in a provider-sized catalogue: the
/// `channels` scenario with 20 000 more channels in "Group 001" to "Group 300"
/// on Home playlist, whose Ungrouped group, with a1 playing, sits at the
/// bottom of the group column.
extension ShellUITests {
    func launchPlayingLarge() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels", "-ui-testing-large-catalogue"]
        app.launch()
        expectEngine("playing loads=1 file=a1.ts")
        expectFocus("shell.picture")
        expectGone("zapBar.bar", timeout: 10)
    }

    /// The group row whose label holds `name`.
    func overlayGroup(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'overlay.group.' AND label CONTAINS %@", name)).firstMatch
    }

    // tv-channel-overlay/picking-a-group-shows-its-channels
    func testLeftLandsOnAGroupFarDownTheList() {
        launchPlayingLarge()
        openOverlay()
        expectFocusedRow("Channel a1")
        expect(element("overlay.channelsHeader"), "label CONTAINS 'UNGROUPED'")

        press(.left)
        expect(overlayGroup("Ungrouped"), "hasFocus == true")
        expect(element("overlay.channelsHeader"), "label CONTAINS 'UNGROUPED'")
        XCTAssertEqual(overlayRows().count, 3, "the list keeps the group's channels")
    }

    // tv-channel-overlay/picking-a-group-shows-its-channels
    func testMovingBetweenTheColumnsInALargeCatalogue() {
        launchPlayingLarge()
        openOverlay()
        press(.left)
        expect(overlayGroup("Ungrouped"), "hasFocus == true")

        // Up through the last groups, as fast as the remote sends them.
        press(.up, times: 4)
        expect(overlayGroup("Group 297"), "hasFocus == true")
        expect(element("overlay.channelsHeader"), "label CONTAINS 'GROUP 297'")

        // Right lands on the group's first channel, l296.
        press(.right)
        expectFocusedRow("Channel l296,")

        // Far down the list, then back: left lands on Group 297.
        press(.down, times: 30)
        expectFocusedRow("Channel l9296,")
        press(.left)
        expect(overlayGroup("Group 297"), "hasFocus == true")
        expect(element("overlay.channelsHeader"), "label CONTAINS 'GROUP 297'")

        // Right again comes back to the row left.
        press(.right)
        expectFocusedRow("Channel l9296,")

        // Another group's list opens at its first channel.
        press(.left)
        expect(overlayGroup("Group 297"), "hasFocus == true")
        press(.up)
        expect(overlayGroup("Group 296"), "hasFocus == true")
        press(.right)
        expectFocusedRow("Channel l295,")
        expectEngine("playing loads=1 file=a1.ts")
    }
}
