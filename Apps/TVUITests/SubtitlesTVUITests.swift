import XCTest

/// The Subtitles preference and the subtitles a channel starts with on
/// Apple TV, over the shell's scripted `channels` scenario. The device's
/// language is fixed to English with `-AppleLanguages`.
extension ShellUITests {
    func launchSubtitles(environment: [String: String]) {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment.merge(environment) { $1 }
        app.launch()
        expectEngine("playing loads=1 file=a1.ts")
        expectFocus("shell.picture")
        expectGone("zapBar.bar", timeout: 10)
    }

    /// The first element matching `predicate`, for rows known by their label.
    func labelled(_ predicate: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: predicate)).firstMatch
    }

    /// Opens the info panel on its Subtitles tab.
    func openSubtitlesTab() {
        remote.press(.select, forDuration: 1)
        XCTAssertTrue(element("player.panel").waitForExistence(timeout: 5), "holding select opened no panel")
        expectFocus("player.panel.segment.info")
        press(.right, times: 2)
        expectFocus("player.panel.segment.subtitles")
    }

    // playback-engine/subtitles-start-by-the-subtitle-setting, Always
    func testAlwaysStartsEnglishSubtitlesOnAppleTV() {
        launchSubtitles(environment: ["UITESTING_SUBTITLES": "always"])
        openSubtitlesTab()
        expect(element("player.panel.track.1"), "value == 'Selected'")
        XCTAssertEqual(element("player.panel.track.1").label, "English")
    }

    // playback-engine/subtitles-start-by-the-subtitle-setting, Auto with sound in another language
    // playback-engine/forced-subtitles-in-your-language-show, forced subtitles in the list
    func testAutoWithGermanSoundStartsEnglishSubtitlesOnAppleTV() {
        launchSubtitles(environment: ["UITESTING_TRACKS": "foreign"])
        openSubtitlesTab()
        expect(element("player.panel.track.2"), "value == 'Selected'")
        XCTAssertEqual(element("player.panel.track.3").label, "English (Forced)")
    }

    // sources-and-settings/choose-when-subtitles-show, Apple TV
    func testSubtitlesPreferenceOpensAListOnAppleTV() {
        launchSubtitles(environment: [:])
        press(.menu)
        let settings = element("shell.settings")
        for _ in 0..<8 where !settings.hasFocus { press(.right) }
        expectFocus("shell.settings")
        press(.select)
        let row = element("settings.subtitles")
        XCTAssertTrue(row.waitForExistence(timeout: 10), "no Subtitles row")
        // The pushed-list picker takes focus as a cell labelled with its title.
        let focusedRow = labelled("hasFocus == true AND label BEGINSWITH 'Subtitles'")
        for _ in 0..<20 where !focusedRow.exists { press(.down) }
        XCTAssertTrue(focusedRow.exists, "the Subtitles row never took focus: \(focusedElements())")
        XCTAssertTrue(element("settings.subtitles.footer").label.contains("not in one of your languages"))

        press(.select)
        let always = labelled("hasFocus == true AND label == 'Always'")
        let off = labelled("hasFocus == true AND label == 'Off'")
        XCTAssertTrue(off.waitForExistence(timeout: 5), "the list of choices never opened: \(focusedElements())")
        XCTAssertTrue(labelled("label == 'Auto' AND isSelected == true").exists, "Auto is not ticked")
        press(.down, times: 2)
        XCTAssertTrue(always.waitForExistence(timeout: 5), "Always never took focus: \(focusedElements())")
        press(.select)

        if !row.waitForExistence(timeout: 3) { press(.menu) }
        expect(element("settings.subtitles.footer"), "label CONTAINS 'whenever the stream has them'")
    }
}
