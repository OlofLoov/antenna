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
        let rows = overlayRows()
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

extension ShellUITests {
    /// Play/pause shows the bar for five fresh seconds, so checks after a
    /// slow launch do not race its hiding.
    func freshBar() {
        press(.playPause)
        XCTAssertTrue(element("zapBar.bar").waitForExistence(timeout: 5))
    }

    /// Tunes the row named `name` in the overlay, from group `group` when given.
    func tune(_ name: String, fromGroup group: Int? = nil) {
        expectGone("zapBar.bar", timeout: 10)
        openOverlay()
        if let group {
            press(.left)
            let start = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
            expect(start, "identifier BEGINSWITH 'overlay.group.'")
            var index = Int(start.identifier.split(separator: ".").last ?? "") ?? 0
            while index != group {
                let direction: XCUIRemote.Button = index < group ? .down : .up
                let next = index + (index < group ? 1 : -1)
                press(direction, toFocus: element("overlay.group.\(next)"), from: element("overlay.group.\(index)"))
                index = next
            }
            press(.right, toFocus: overlayRows().firstMatch, from: element("overlay.group.\(group)"))
        }
        let target = row(named: name)
        let focused = overlayRows().matching(NSPredicate(format: "hasFocus == true")).firstMatch
        for _ in 0..<overlayRows().count where !target.hasFocus {
            let before = focused.identifier
            press(.down)
            expect(focused, "identifier != '\(before)'")
        }
        XCTAssertTrue(target.hasFocus, "\(name) never took focus")
        press(.select)
        XCTAssertTrue(element("zapBar.bar").waitForExistence(timeout: 10))
        expect(element("zapBar.name"), "label == '\(name)'")
    }

    // tv-zap-bar-and-number-entry/which-channel-this-is
    func testWhichChannelThisIs() {
        launchWithBar()
        freshBar()
        expect(element("zapBar.name"), "label == 'Channel a1'")
        expect(element("zapBar.position"), "label == 'Ungrouped · 1 of 3'")
        XCTAssertTrue(element("zapBar.number").exists)

        tune("Channel b1", fromGroup: 1)
        expect(element("zapBar.position"), "label == 'All channels · 4 of 4'")
    }

    // tv-zap-bar-and-number-entry/what-is-on-and-what-is-next
    func testWhatIsOnAndWhatIsNext() {
        launchWithBar()
        freshBar()
        expect(element("zapBar.programme"), "label == 'Morning News'")
        XCTAssertTrue(element("zapBar.times").label.contains("–"))
        XCTAssertTrue(element("zapBar.progress").exists)
        XCTAssertTrue(element("zapBar.next").label.contains("Weather"), element("zapBar.next").label)
        XCTAssertTrue(element("zapBar.remaining").label.hasSuffix("min left"), element("zapBar.remaining").label)

        tune("Channel a2")
        expect(element("zapBar.programme"), "label == 'Loading guide…'")
        XCTAssertFalse(element("zapBar.progress").exists)
        XCTAssertFalse(element("zapBar.next").exists)
        tune("Channel a3")
        expect(element("zapBar.programme"), "label == 'No programme information'")
    }

    // tv-zap-bar-and-number-entry/picture-and-sound-quality
    func testPictureAndSoundQuality() {
        launchWithBar()
        freshBar()
        expect(element("zapBar.live"), "label == 'LIVE'")
        let quality = app.staticTexts.matching(identifier: "zapBar.quality")
        XCTAssertTrue(quality["1080p"].waitForExistence(timeout: 3))
        XCTAssertTrue(quality["AAC 5.1"].exists)
    }

    // tv-zap-bar-and-number-entry/picture-and-sound-quality
    func testNoBadgesAfterAFailure() {
        launch("failing")
        expectEngine("failed loads=1 file=a1.ts")
        XCTAssertTrue(element("zapBar.bar").waitForExistence(timeout: 10))
        freshBar()
        expect(element("zapBar.name"), "label == 'Channel a1'")
        XCTAssertFalse(element("zapBar.live").exists)
        XCTAssertFalse(element("zapBar.quality").exists)
        expect(element("zapBar.programme"), "label == 'Morning News'")
    }

    // tv-zap-bar-and-number-entry/catch-up-hint
    func testCatchUpHint() {
        launchWithBar()
        freshBar()
        expect(element("zapBar.hint"), "label == 'Press to browse channels'")
        XCTAssertFalse(element("zapBar.catchup").exists)
        tune("Channel b1", fromGroup: 3)
        expect(element("zapBar.catchup"), "label == 'Catch-up 7 days'")
        expect(element("zapBar.hint"), "label == 'Press to browse channels'")
    }
}
