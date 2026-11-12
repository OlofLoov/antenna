import XCTest

/// The tv-channel-overlay capability over the shell's scripted `channels`
/// scenario: Home playlist with a1, a2 and a3, Cabin with b1, none in a
/// named group.
extension ShellUITests {
    /// Opens the overlay over the playing picture.
    func openOverlay() {
        press(.select)
        XCTAssertTrue(element("overlay.root").waitForExistence(timeout: 10))
    }

    func expectFocusedRow(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let row = overlayRows().matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        expect(row, "hasFocus == true", file: file, line: line)
    }

    // tv-channel-overlay/the-picture-keeps-playing
    func testOverlayOpensOverThePlayingPicture() {
        launchPlaying()
        openOverlay()
        expectEngine("playing loads=1 file=a1.ts")
        expect(element("shell.player"), "value == 'full'")
        XCTAssertTrue(element("overlay.clock").exists)

        press(.playPause)
        expectEngine("paused loads=1 file=a1.ts")
        XCTAssertTrue(element("overlay.root").exists, "the overlay stays")
        press(.playPause)
        expectEngine("playing loads=1 file=a1.ts")
        XCTAssertTrue(element("overlay.root").exists)
    }

    // tv-channel-overlay/it-opens-where-the-user-left-off
    func testOverlayOpensWhereTheUserLeftOff() {
        launchPlaying()
        openOverlay()
        expectFocusedRow("Channel a1")
        let rows = overlayRows()
        press(.down, toFocus: rows.element(boundBy: 1), from: rows.element(boundBy: 0))
        press(.select)
        expectGone("overlay.root")
        expectEngine("playing loads=2 file=a2.ts")

        openOverlay()
        expectFocusedRow("Channel a2")
    }

    // tv-channel-overlay/every-group-with-its-size
    func testEveryGroupWithItsSize() {
        launchPlaying()
        openOverlay()
        let expected: [(label: String, count: String)] = [
            ("Favorites", "0"), ("All channels", "4"), ("Ungrouped", "3"), ("Ungrouped", "1"),
        ]
        for (index, group) in expected.enumerated() {
            let row = element("overlay.group.\(index)")
            XCTAssertTrue(row.waitForExistence(timeout: 5), "group \(index)")
            XCTAssertTrue(row.label.contains(group.label), "group \(index) is \(row.label)")
            XCTAssertEqual(row.value as? String, group.count, "group \(index) count")
        }
        XCTAssertFalse(element("overlay.group.\(expected.count)").exists)
        XCTAssertTrue(element("overlay.search").exists, "the column ends with Search")
    }

    // tv-channel-overlay/picking-a-group-shows-its-channels
    func testPickingAGroupShowsItsChannels() {
        launchPlaying()
        openOverlay()
        expect(element("overlay.channelsHeader"), "label CONTAINS 'UNGROUPED'")
        XCTAssertEqual(overlayRows().count, 3)

        press(.left, toFocus: element("overlay.group.2"), from: overlayRows().element(boundBy: 0))
        press(.down, toFocus: element("overlay.group.3"), from: element("overlay.group.2"))
        expect(overlayRows().element(boundBy: 0), "label CONTAINS 'Channel b1'")
        XCTAssertEqual(overlayRows().count, 1, "exactly the group's channels")

        press(.up, toFocus: element("overlay.group.2"), from: element("overlay.group.3"))
        press(.up, toFocus: element("overlay.group.1"), from: element("overlay.group.2"))
        expect(element("overlay.channelsHeader"), "label CONTAINS 'ALL CHANNELS'")
        expect(element("overlay.channelsHeader"), "label CONTAINS 'Sorted by number'")
        XCTAssertEqual(overlayRows().count, 4)

        press(.up, toFocus: element("overlay.group.0"), from: element("overlay.group.1"))
        expect(element("overlay.channelsHeader"), "label CONTAINS 'Your order'")
        XCTAssertEqual(overlayRows().count, 0)
        expectEngine("playing loads=1 file=a1.ts")
    }
}

extension ShellUITests {
    func row(named name: String) -> XCUIElement {
        overlayRows().matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    }

    func part(_ suffix: String, of row: XCUIElement) -> XCUIElement {
        element("\(row.identifier).\(suffix)")
    }

    // tv-channel-overlay/each-channel-shows-what-is-on
    func testEachChannelShowsWhatIsOn() {
        launchPlaying()
        openOverlay()
        let news = row(named: "Channel a1")
        XCTAssertTrue(news.waitForExistence(timeout: 5))
        XCTAssertTrue(news.label.contains("Morning News"), news.label)
        XCTAssertTrue(news.label.contains("min left"), news.label)
        XCTAssertTrue(part("progress", of: news).exists, "a programme on now shows its progress")
        XCTAssertTrue(part("logo", of: news).exists)

        let loading = row(named: "Channel a2")
        XCTAssertTrue(loading.label.contains("Loading guide…"), loading.label)
        XCTAssertFalse(part("progress", of: loading).exists)
        let none = row(named: "Channel a3")
        XCTAssertTrue(none.label.contains("No programme information"), none.label)
        XCTAssertFalse(part("progress", of: none).exists)
        XCTAssertFalse(part("catchup", of: news).exists)

        press(.left, toFocus: element("overlay.group.2"), from: news)
        press(.down, toFocus: element("overlay.group.3"), from: element("overlay.group.2"))
        let film = row(named: "Channel b1")
        expect(film, "exists == true")
        XCTAssertTrue(film.label.contains("Evening Film"), film.label)
        XCTAssertTrue(part("catchup", of: film).exists, "a channel with catch-up carries the mark")
    }

    // tv-channel-overlay/empty-groups-tell-the-user-what-to-do
    func testEmptyFavoritesTellTheUserWhatToDo() {
        launchPlaying()
        openOverlay()
        press(.left, toFocus: element("overlay.group.2"), from: row(named: "Channel a1"))
        press(.up, toFocus: element("overlay.group.1"), from: element("overlay.group.2"))
        press(.up, toFocus: element("overlay.group.0"), from: element("overlay.group.1"))
        expect(element("overlay.emptyGroup"), "label == 'No favorites yet. Press the star on a channel to add it.'")
        XCTAssertEqual(overlayRows().count, 0)
        press(.right)
        expectFocus("overlay.group.0")
    }
}

extension ShellUITests {
    // tv-channel-overlay/now-and-next-for-the-highlighted-channel
    func testNowAndNextForTheHighlightedChannel() {
        launchPlaying()
        openOverlay()
        expect(element("overlay.panel.now"), "label == 'Morning News'")
        let times = element("overlay.panel.remaining")
        XCTAssertTrue(times.label.contains("–") && times.label.contains("min left"), times.label)
        XCTAssertTrue(element("overlay.panel.progress").exists)
        expect(element("overlay.panel.summary"), "label == 'Headlines and weather.'")
        let next = element("overlay.panel.next")
        // Each programme that follows is a row that sets a reminder (programme-reminders capability).
        let titled = { (title: String) in
            next.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        }
        XCTAssertTrue(titled("Weather").exists && titled("Business").exists && titled("Sport Tonight").exists)
        XCTAssertFalse(titled("Late Film").exists, "at most three follow")
        XCTAssertTrue(element("overlay.panel.logo").exists)

        let rows = overlayRows()
        press(.down, toFocus: rows.element(boundBy: 1), from: rows.element(boundBy: 0))
        expect(element("overlay.panel.now"), "label == 'Loading guide…'")
        XCTAssertFalse(element("overlay.panel.progress").exists)
        XCTAssertFalse(element("overlay.panel.next").exists)
        press(.down, toFocus: rows.element(boundBy: 2), from: rows.element(boundBy: 1))
        expect(element("overlay.panel.now"), "label == 'No programme information'")
    }

    // tv-channel-overlay/add-or-remove-a-favorite
    func testAddOrRemoveAFavorite() {
        launchPlaying()
        openOverlay()
        press(.right, toFocus: element("overlay.watch"), from: row(named: "Channel a1"))
        press(.right, toFocus: element("overlay.favorite"), from: element("overlay.watch"))
        let favorite = element("overlay.favorite")
        expect(favorite, "label == 'Add to favorites'")
        press(.select)
        expect(favorite, "label == 'Remove from favorites'")
        expect(element("overlay.group.0"), "value == '1'")
        press(.select)
        expect(favorite, "label == 'Add to favorites'")
        expect(element("overlay.group.0"), "value == '0'")
        press(.select)
        expect(element("overlay.group.0"), "value == '1'")

        // Removing it while Favorites is shown leaves no row, so focus goes to the group.
        press(.left, toFocus: element("overlay.watch"), from: favorite)
        press(.left, toFocus: row(named: "Channel a1"), from: element("overlay.watch"))
        press(.left, toFocus: element("overlay.group.2"), from: row(named: "Channel a1"))
        press(.up, toFocus: element("overlay.group.1"), from: element("overlay.group.2"))
        press(.up, toFocus: element("overlay.group.0"), from: element("overlay.group.1"))
        press(.right, toFocus: row(named: "Channel a1"), from: element("overlay.group.0"))
        press(.right, toFocus: element("overlay.watch"), from: row(named: "Channel a1"))
        press(.right, toFocus: favorite, from: element("overlay.watch"))
        press(.select)
        expectFocus("overlay.group.0")
        expect(element("overlay.emptyGroup"), "exists == true")
        expectEngine("playing loads=1 file=a1.ts")
    }
}

extension ShellUITests {
    // tv-channel-overlay/select-changes-channel
    func testSelectChangesChannel() {
        launchPlaying()
        openOverlay()
        let rows = overlayRows()
        press(.down, toFocus: rows.element(boundBy: 1), from: rows.element(boundBy: 0))
        press(.right, toFocus: element("overlay.watch"), from: rows.element(boundBy: 1))
        press(.select)
        expectGone("overlay.root")
        expectEngine("playing loads=2 file=a2.ts")
        XCTAssertTrue(element("zapBar.bar").waitForExistence(timeout: 5), "the info bar appears")
        expect(element("zapBar.name"), "label == 'Channel a2'")
    }

    // tv-channel-overlay/select-on-the-playing-channel-does-not-restart-it
    func testSelectOnThePlayingChannelDoesNotRestartIt() {
        launchPlaying()
        openOverlay()
        press(.select)
        expectGone("overlay.root")
        expectEngine("playing loads=1 file=a1.ts")

        expectGone("zapBar.bar", timeout: 10)
        openOverlay()
        press(.playPause)
        expectEngine("paused loads=1 file=a1.ts")
        press(.select)
        expectGone("overlay.root")
        expectEngine("playing loads=1 file=a1.ts")
    }

    // tv-channel-overlay/select-on-the-playing-channel-does-not-restart-it
    // player-controls-and-playback-errors/try-again-or-recover-on-its-own:
    // the error replaces the picture, so select on a failed channel is Try
    // again and loads it once more without opening the overlay.
    func testSelectOnAFailedChannelLoadsItAgain() {
        launch("failing")
        expectEngine("failed loads=1 file=a1.ts")
        expect(element("player.retry"), "hasFocus == true")
        press(.select)
        expectEngine("failed loads=2 file=a1.ts")
        XCTAssertFalse(element("overlay.root").exists)
    }

    // tv-channel-overlay/menu-closes-without-changing-anything
    func testMenuClosesWithoutChangingAnything() {
        launchPlaying()
        openOverlay()
        let rows = overlayRows()
        press(.down, toFocus: rows.element(boundBy: 1), from: rows.element(boundBy: 0))
        press(.menu)
        expectGone("overlay.root")
        XCTAssertFalse(element("shell.tab.live").exists, "Menu does not also raise the tab bar")
        expect(element("shell.player"), "value == 'full'")
        expectEngine("playing loads=1 file=a1.ts")
        XCTAssertTrue(app.state == .runningForeground)

        openOverlay()
        expectFocusedRow("Channel a1")
    }

    // tv-channel-overlay/a-way-into-search
    func testAWayIntoSearch() {
        launchPlaying()
        openOverlay()
        press(.left, toFocus: element("overlay.group.2"), from: row(named: "Channel a1"))
        press(.down, toFocus: element("overlay.group.3"), from: element("overlay.group.2"))
        press(.down, toFocus: element("overlay.search"), from: element("overlay.group.3"))
        press(.select)
        expectGone("overlay.root")
        XCTAssertTrue(element("search.results").waitForExistence(timeout: 10))
        expectEngine("playing loads=1 file=a1.ts")
        press(.menu)
        expectFocus("shell.tab.search")
        XCTAssertFalse(element("overlay.root").exists, "Menu in Search does not reopen the overlay")
    }
}
