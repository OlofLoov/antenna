import XCTest

/// The tv-guide-grid capability on the shell's scripted `channels` scenario:
/// Channel a1 plays at launch from the Home playlist (a1 Morning News on
/// now, then four more; a2's guide loading; a3 with none), and Cabin has b1.
extension ShellUITests {
    static let homeRow = "00000000-0000-0000-0000-00000000000A"

    /// The row key part of a guide identifier for Home playlist channel `position`.
    func homeKey(_ position: Int) -> String { "\(Self.homeRow).\(position)" }

    /// Opens the Guide tab from full-screen Live.
    func openGuide() {
        press(.menu)
        expectFocus("shell.tab.live")
        press(.right, toFocus: element("shell.tab.guide"), from: element("shell.tab.live"))
        press(.select)
        expectFocus("guide.grid")
    }

    /// The block the guide highlights: the one the panel describes.
    func highlighted() -> XCUIElement {
        let kinds = ["guide.block.", "guide.gap.", "guide.loading.", "guide.noGuide.", "guide.failed."]
        let prefix = kinds.map { "identifier BEGINSWITH '\($0)'" }.joined(separator: " OR ")
        return app.descendants(matching: .any).matching(NSPredicate(format: "(\(prefix)) AND isSelected == true")).firstMatch
    }

    /// Waits for the highlight to sit on a block whose identifier starts with `prefix`.
    func expectHighlight(_ prefix: String, file: StaticString = #filePath, line: UInt = #line) {
        expect(highlighted(), "identifier BEGINSWITH '\(prefix)'", file: file, line: line)
    }
}

// MARK: Guide tab and small picture

extension ShellUITests {
    // tv-guide-grid/the-channel-keeps-playing-in-a-small-picture
    func testTheChannelKeepsPlayingInASmallPicture() {
        launchPlaying()
        openGuide()
        expectEngine("playing loads=1 file=a1.ts")
        expect(element("guide.pip"), "label CONTAINS 'Channel a1'")
        let picture = element("shell.player")
        XCTAssertEqual(picture.frame.width, 480, accuracy: 1)
        XCTAssertEqual(picture.frame.height, 270, accuracy: 1)
    }

    // tv-guide-grid/the-channel-keeps-playing-in-a-small-picture
    func testAFailedStreamTunesAgainFromTheGuide() {
        launch("failing")
        expectEngine("failed loads=1 file=a1.ts")
        expectGone("zapBar.bar", timeout: 10)
        openGuide()
        expect(element("guide.pip"), "label CONTAINS 'Channel a1'")
        press(.right)
        expectHighlight("guide.block.\(homeKey(0)).")
        press(.select)
        expectFocus("guide.watch")
        press(.select)
        expectEngine("failed loads=2 file=a1.ts")
    }

    // tv-guide-grid/one-row-per-channel-in-the-current-group
    func testOneRowPerChannelInTheCurrentGroup() {
        launchPlaying()
        openGuide()
        let cells = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'guide.channel.'"))
        expect(cells.firstMatch, "exists == true")
        let rows = cells.allElementsBoundByIndex.sorted { $0.frame.minY < $1.frame.minY }
        XCTAssertEqual(rows.map(\.identifier), (0..<3).map { "guide.channel.\(homeKey($0))" })
        for (index, row) in zip(rows.indices, rows) {
            XCTAssertTrue(row.label.contains("Channel a\(index + 1)"), row.label)
        }
        XCTAssertEqual(rows.map { ($0.value as? String) ?? "" }, ["playing", "", ""])
        XCTAssertFalse(element("guide.channel.00000000-0000-0000-0000-00000000000B.0").exists, "b1 is in another group")
    }

    // tv-guide-grid/channels-without-a-guide-say-so
    func testChannelsWithoutAGuideSaySo() {
        launchPlaying()
        openGuide()
        expect(element("guide.loading.\(homeKey(1))"), "label CONTAINS 'Loading guide…'")
        expect(element("guide.noGuide.\(homeKey(2))"), "label CONTAINS 'No programme information'")
        press(.down)
        expectHighlight("guide.loading.\(homeKey(1))")
        expect(element("guide.panel.title"), "label == 'Loading guide…'")
        press(.select)
        expectFocus("guide.watch")
        expectEngine("playing loads=1 file=a1.ts")
    }

    // tv-guide-grid/channels-without-a-guide-say-so
    func testAFailedGuideSaysUnavailable() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels", "-ui-testing-guide-failed"]
        app.launch()
        expectEngine("playing loads=1 file=a1.ts")
        expectGone("zapBar.bar", timeout: 10)
        openGuide()
        expect(element("guide.failed.\(homeKey(2))"), "label CONTAINS 'Guide unavailable'")
    }

    // tv-guide-grid/an-empty-group
    func testAnEmptyGroup() {
        launch("empty")
        expectFocus("shell.retry")
        press(.menu)
        expectFocus("shell.tab.live")
        press(.right, toFocus: element("shell.tab.guide"), from: element("shell.tab.live"))
        press(.select)
        expectFocus("guide.day.0")
        expect(element("guide.empty"), "label == 'No channels in All channels'")
        XCTAssertTrue(element("guide.column").exists, "the time header stays")
        XCTAssertTrue(element("guide.clock").exists)
        XCTAssertFalse(element("guide.watch").exists)
        press(.menu)
        expectFocus("shell.tab.guide")
    }
}

// MARK: Focus, panel and tuning

extension ShellUITests {
    // tv-guide-grid/it-opens-on-what-is-on-now
    // tvos-shell/menu-from-the-top-of-a-tab-reaches-the-tab-bar
    func testItOpensOnWhatIsOnNow() {
        launchPlaying()
        openGuide()
        expectHighlight("guide.block.\(homeKey(0)).")
        XCTAssertTrue(highlighted().label.contains("Morning News"), highlighted().label)
        XCTAssertTrue(element("guide.nowLine").exists)
        press(.up)
        expectFocus("guide.day.0")
        press(.down)
        expectFocus("guide.grid")
        expectHighlight("guide.block.\(homeKey(0)).")
        XCTAssertTrue(highlighted().label.contains("Morning News"), highlighted().label)
        press(.menu)
        expectFocus("shell.tab.guide")
    }

    // tv-guide-grid/the-panel-describes-the-highlighted-programme
    func testThePanelDescribesTheHighlightedProgramme() {
        launchPlaying()
        openGuide()
        expect(element("guide.panel.title"), "label == 'Morning News'")
        expect(element("guide.panel.eyebrow"), "label == 'Now · Channel a1'")
        let meta = element("guide.panel.meta")
        XCTAssertTrue(meta.label.contains("1 h") && meta.label.contains("News") && meta.label.hasSuffix("1080p"), meta.label)
        XCTAssertTrue(element("guide.panel.progress").exists)
        expect(element("guide.panel.summary"), "label == 'Headlines and weather.'")
        XCTAssertTrue(element("guide.watch").exists)
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'guide.' AND identifier != 'guide.grid'")).count
                - app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'guide.day.'")).count, 1, "Watch and nothing else")

        press(.right)
        expect(element("guide.panel.title"), "label == 'Weather'")
        expect(element("guide.panel.eyebrow"), "label BEGINSWITH 'Today '")
        XCTAssertFalse(element("guide.panel.progress").exists)
        XCTAssertFalse(element("guide.panel.summary").exists)
        XCTAssertTrue(element("guide.panel.meta").label.contains("30 min"), element("guide.panel.meta").label)
    }

    // tv-guide-grid/select-on-a-programme-that-is-on-now
    func testSelectOnAProgrammeThatIsOnNow() {
        launchPlaying()
        openGuide()
        expectHighlight("guide.block.\(homeKey(0)).")
        press(.select)
        expectGone("guide.grid")
        expect(element("shell.player"), "value == 'full'")
        expectEngine("playing loads=1 file=a1.ts")

        // Another channel: from a2 back up to a1's programme on now.
        tune("Channel a2")
        expectGone("zapBar.bar", timeout: 10)
        openGuide()
        expectHighlight("guide.loading.\(homeKey(1))")
        // Up lands at the window's start, in the gap before Morning News.
        press(.up)
        expectHighlight("guide.gap.\(homeKey(0)).")
        press(.right)
        expectHighlight("guide.block.\(homeKey(0)).")
        press(.select)
        expectEngine("playing loads=3 file=a1.ts")
        XCTAssertTrue(element("zapBar.bar").waitForExistence(timeout: 10), "the info bar shows")
        expect(element("zapBar.name"), "label == 'Channel a1'")
    }

    // tv-guide-grid/select-on-anything-else-goes-to-watch
    func testSelectOnAnythingElseGoesToWatch() {
        launchPlaying()
        openGuide()
        press(.right)
        expectHighlight("guide.block.\(homeKey(0)).")
        expect(element("guide.panel.title"), "label == 'Weather'")
        press(.select)
        expectFocus("guide.watch")
        expectEngine("playing loads=1 file=a1.ts")
        press(.menu)
        expectFocus("guide.grid")
        expect(element("guide.panel.title"), "label == 'Weather'")
        XCTAssertFalse(element("shell.tab.guide").exists, "the guide stays open")

        press(.select)
        expectFocus("guide.watch")
        press(.down)
        expectFocus("guide.grid")
        press(.select)
        expectFocus("guide.watch")
        press(.select)
        expectGone("guide.grid")
        expect(element("shell.player"), "value == 'full'")
        expectEngine("playing loads=1 file=a1.ts")
    }
}
