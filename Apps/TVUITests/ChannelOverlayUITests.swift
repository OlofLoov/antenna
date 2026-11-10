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
