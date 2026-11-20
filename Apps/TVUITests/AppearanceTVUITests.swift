import XCTest

/// Settings, Appearance on Apple TV, over the scripted shell with Dad and
/// Kids. The Accent row's value is the accent the environment holds.
extension ShellUITests {
    // sources-and-settings/pick-the-accent-for-your-profile, Apple TV
    // design-system/one-accent-color-per-profile
    func testPickingAnAccentOnAppleTV() {
        launchAsDad()
        openSettingsOnProfiles()
        let row = element("settings.appearance.accent")
        let focusedRow = labelled("hasFocus == true AND label BEGINSWITH 'Accent'")
        for _ in 0..<24 where !focusedRow.exists { press(.down) }
        XCTAssertTrue(focusedRow.exists, "the Accent row never took focus: \(focusedElements())")
        expect(row, "value == 'Blue'")
        XCTAssertTrue(element("settings.appearance.footer").label.contains("this profile on every device"))

        press(.select)
        XCTAssertTrue(labelled("hasFocus == true AND label == 'Blue'").waitForExistence(timeout: 5), "no choices: \(focusedElements())")
        XCTAssertTrue(labelled("label == 'Blue' AND isSelected == true").exists, "Blue is not ticked")
        press(.down)
        XCTAssertTrue(labelled("hasFocus == true AND label == 'Teal'").waitForExistence(timeout: 5), "Teal never took focus")
        press(.select)

        if !row.waitForExistence(timeout: 3) { press(.menu) }
        expect(row, "value == 'Teal'")
    }

    // sources-and-settings/pick-the-app-icon-on-this-device, Apple TV
    func testTheAppIconChoicesOnAppleTV() {
        launchAsDad()
        openSettingsOnProfiles()
        let row = element("settings.appearance.icon")
        let focusedRow = labelled("hasFocus == true AND label BEGINSWITH 'App icon'")
        for _ in 0..<26 where !focusedRow.exists { press(.down) }
        XCTAssertTrue(focusedRow.exists, "the App icon row never took focus: \(focusedElements())")
        expect(row, "value == 'Antenna'")
        press(.select)
        XCTAssertTrue(labelled("hasFocus == true AND label == 'Antenna'").waitForExistence(timeout: 5), "no choices: \(focusedElements())")
        for id in ["standard", "mono", "light", "teal", "amber", "pink", "violet"] {
            XCTAssertTrue(element("settings.choice.\(id)").exists, "no \(id) icon")
        }
    }
}
