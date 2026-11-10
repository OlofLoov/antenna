import XCTest

/// The tv-zap-bar-and-number-entry capability: the info bar over the
/// full-screen picture, on the shell's scripted `channels` scenario.
extension ShellUITests {
    /// Launches `channels` and waits for the launch tune's bar.
    func launchWithBar() {
        launch("channels")
        expectEngine("playing loads=1 file=a1.ts")
        XCTAssertTrue(element("zapBar.bar").waitForExistence(timeout: 10))
    }

    // tv-zap-bar-and-number-entry/the-bar-appears-on-every-channel-change
    func testBarAppearsOnEveryChannelChange() {
        launchWithBar()
        expect(element("zapBar.name"), "label == 'Channel a1'")
        expectGone("zapBar.bar", timeout: 9)
        expectEngine("playing loads=1 file=a1.ts")

        press(.select)
        XCTAssertTrue(element("overlay.channels").waitForExistence(timeout: 10))
        let rows = app.cells
        expect(rows.element(boundBy: 0), "hasFocus == true")
        press(.down, toFocus: rows.element(boundBy: 1), from: rows.element(boundBy: 0))
        press(.select)
        XCTAssertTrue(element("zapBar.bar").waitForExistence(timeout: 10), "the new channel shows the bar")
        expect(element("zapBar.name"), "label == 'Channel a2'")
        expectGone("zapBar.bar", timeout: 9)
    }

    // tv-zap-bar-and-number-entry/play-pause-shows-the-bar
    func testPlayPauseShowsTheBar() {
        launchPlaying()
        press(.playPause)
        XCTAssertTrue(element("zapBar.bar").waitForExistence(timeout: 5))
        expectEngine("playing loads=1 file=a1.ts")
        expectGone("zapBar.bar", timeout: 9)
        expectEngine("playing loads=1 file=a1.ts")
    }

    // tv-zap-bar-and-number-entry/menu-hides-the-bar
    func testMenuHidesTheBar() {
        launchWithBar()
        press(.menu)
        expectGone("zapBar.bar", timeout: 3)
        XCTAssertFalse(element("shell.tab.live").exists, "Menu does not also raise the tab bar")
        expect(element("shell.player"), "value == 'full'")
        expectEngine("playing loads=1 file=a1.ts")
        XCTAssertTrue(app.state == .runningForeground, "Menu does not take the user out of the player")
    }

    // tv-zap-bar-and-number-entry/menu-hides-the-bar
    func testSelectWithTheBarOpensTheChannelList() {
        launchWithBar()
        press(.select)
        XCTAssertTrue(element("overlay.channels").waitForExistence(timeout: 10))
        XCTAssertFalse(element("zapBar.bar").exists)
        expectEngine("playing loads=1 file=a1.ts")
    }
}
