import XCTest

/// Multi-view on Apple TV (multi-view capability) over the shell's
/// scripted `channels` scenario: a1, a2 and a3 on Home playlist, b1 on
/// Cabin, a1 playing at launch. Each tile's probe
/// `multiView.tile.<n>.debug` reads `"<state> loads=<n> file=<name>[ muted]"`.
@MainActor
final class MultiViewTVUITests: XCTestCase {
    let remote = XCUIRemote.shared
    var app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Helpers

    func launchPlaying(environment: [String: String] = [:]) {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels"]
        app.launchEnvironment = environment
        app.launch()
        expectEngine("playing loads=1 file=a1.ts")
        expectFocus("shell.picture")
        expectGone("zapBar.bar")
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    func expect(
        _ element: XCUIElement, _ predicate: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(element) never matched \(predicate)", file: file, line: line)
    }

    func expectEngine(_ summary: String, file: StaticString = #filePath, line: UInt = #line) {
        expect(element("shell.debug.engine"), "value == '\(summary)'", timeout: 15, file: file, line: line)
    }

    func expectTile(_ number: Int, _ summary: String, file: StaticString = #filePath, line: UInt = #line) {
        expect(element("multiView.tile.\(number).debug"), "value == '\(summary)'", file: file, line: line)
    }

    func expectFocus(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        expect(element(identifier), "hasFocus == true", file: file, line: line)
    }

    func expectGone(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        expect(element(identifier), "exists == false", file: file, line: line)
    }

    func overlayRow(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'overlay.channel.' AND label CONTAINS %@", name)).firstMatch
    }

    /// Moves focus with `button` until `target` has it, pressing at most `limit` times.
    func move(_ button: XCUIRemote.Button, to target: XCUIElement, limit: Int = 6, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<limit {
            if target.hasFocus { return }
            remote.press(button)
            let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasFocus == true"), object: target)
            _ = XCTWaiter().wait(for: [focused], timeout: 2)
        }
        XCTAssertTrue(target.hasFocus, "\(target) never took focus", file: file, line: line)
    }

    /// Opens the overlay over full-screen live, highlights `channel` and
    /// focuses the multi-view button.
    func focusMultiViewButton(on channel: String) {
        remote.press(.select)
        XCTAssertTrue(element("overlay.root").waitForExistence(timeout: 10))
        move(.down, to: overlayRow(channel))
        move(.right, to: element("overlay.multiView"))
    }

    /// Starts multi-view with a1 in tile 1 and a2 in tile 2.
    func startTwoTiles(environment: [String: String] = [:]) {
        launchPlaying(environment: environment)
        focusMultiViewButton(on: "Channel a2")
        remote.press(.select)
        XCTAssertTrue(element("multiView.root").waitForExistence(timeout: 10))
        expectFocus("multiView.tile.2")
    }

    // MARK: Start

    // multi-view/start-multi-view-on-apple-tv
    // tvos-shell/the-shell-hosts-multi-view
    func testAddToMultiViewSplitsIntoTwoTiles() {
        startTwoTiles()
        expectTile(1, "playing loads=1 file=a1.ts muted")
        expectTile(2, "playing loads=1 file=a2.ts")
        XCTAssertTrue(element("multiView.hint").exists, "the hint shows after entering")
        XCTAssertTrue(element("multiView.tile.2").label.hasSuffix("sound on"))
        XCTAssertTrue(element("multiView.tile.1").label.hasSuffix("muted"))
        XCTAssertFalse(element("zapBar.bar").exists, "entering is no channel change")
        XCTAssertFalse(element("shell.tab.live").isHittable, "the tab bar stays hidden")
        expectGone("multiView.hint")
    }

    // multi-view/start-multi-view-on-apple-tv
    func testOptionNotOfferedOnThePlayingChannelOrWhilePaused() {
        launchPlaying()
        remote.press(.select)
        XCTAssertTrue(element("overlay.root").waitForExistence(timeout: 10))
        move(.right, to: element("overlay.favorite"))
        XCTAssertFalse(element("overlay.multiView").exists, "not offered on the playing channel")

        move(.left, to: overlayRow("Channel a1"))
        move(.down, to: overlayRow("Channel a2"))
        move(.right, to: element("overlay.watch"))
        XCTAssertTrue(element("overlay.multiView").waitForExistence(timeout: 5))
        remote.press(.playPause)
        expectEngine("paused loads=1 file=a1.ts")
        expectGone("overlay.multiView")
    }

    // multi-view/start-multi-view-on-apple-tv
    func testOptionNotOfferedWhileThePlayingChannelLoads() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels"]
        app.launchEnvironment = ["UITESTING_PLAYBACK": "stall"]
        app.launch()
        expectEngine("loading loads=1 file=a1.ts")
        expectFocus("shell.picture")
        expectGone("zapBar.bar")
        remote.press(.select)
        XCTAssertTrue(element("overlay.root").waitForExistence(timeout: 10))
        move(.down, to: overlayRow("Channel a2"))
        move(.right, to: element("overlay.watch"))
        move(.right, to: element("overlay.favorite"))
        XCTAssertFalse(element("overlay.multiView").exists, "not offered while the playing channel loads")
    }

    // MARK: Sound and navigation

    // multi-view/sound-follows-the-highlighted-tile
    func testSoundFollowsTheHighlightAndNavigationChangesNothing() {
        startTwoTiles()
        move(.left, to: element("multiView.tile.1"))
        expectTile(1, "playing loads=1 file=a1.ts")
        expectTile(2, "playing loads=1 file=a2.ts muted")
        remote.press(.up)
        remote.press(.down)
        expectTile(1, "playing loads=1 file=a1.ts")
        expectTile(2, "playing loads=1 file=a2.ts muted")
        XCTAssertTrue(element("multiView.root").exists)
        XCTAssertFalse(element("zapBar.bar").exists)
    }

    // MARK: Change and add

    // multi-view/change-a-tile-s-channel
    func testPickerChangesOnlyTheHighlightedTile() {
        startTwoTiles()
        remote.press(.select)
        expect(element("overlay.pickTarget"), "label == 'CHANGING TILE 2 OF 2'")
        XCTAssertFalse(element("overlay.search").exists, "the picker has no Search")
        XCTAssertTrue(overlayRow("Channel a1").label.contains("Channel a1"))
        expect(app.descendants(matching: .any).matching(NSPredicate(format: "identifier ENDSWITH '.tile'")).firstMatch, "exists == true")
        expectFocus(overlayRow("Channel a2").identifier)

        remote.press(.menu)
        expectGone("overlay.root")
        expectTile(2, "playing loads=1 file=a2.ts")

        remote.press(.select)
        XCTAssertTrue(element("overlay.root").waitForExistence(timeout: 10))
        move(.down, to: overlayRow("Channel a3"))
        move(.right, to: element("overlay.watch"))
        XCTAssertEqual(element("overlay.watch").label, "Show in tile 2")
        remote.press(.select)
        expectGone("overlay.root")
        expectTile(2, "playing loads=2 file=a3.ts")
        expectTile(1, "playing loads=1 file=a1.ts muted")
        XCTAssertFalse(element("zapBar.bar").exists)
    }

    // multi-view/change-a-tile-s-channel
    func testPickingAChannelInAnotherTileMovesTheHighlight() {
        startTwoTiles()
        remote.press(.select)
        XCTAssertTrue(element("overlay.root").waitForExistence(timeout: 10))
        move(.up, to: overlayRow("Channel a1"))
        remote.press(.select)
        expectGone("overlay.root")
        expectFocus("multiView.tile.1")
        expectTile(1, "playing loads=1 file=a1.ts")
        expectTile(2, "playing loads=1 file=a2.ts muted")
    }

    // multi-view/add-more-tiles-up-to-the-limit
    func testAddAsNewTileUpToTheLimit() {
        startTwoTiles(environment: ["UITESTING_MULTIVIEW_CAP": "3"])
        remote.press(.select)
        XCTAssertTrue(element("overlay.root").waitForExistence(timeout: 10))
        move(.down, to: overlayRow("Channel a3"))
        move(.right, to: element("overlay.multiView"))
        XCTAssertEqual(element("overlay.multiView").label, "Add as new tile")
        remote.press(.select)
        expectGone("overlay.root")
        expectFocus("multiView.tile.3")
        expectTile(3, "playing loads=1 file=a3.ts")
        expectTile(2, "playing loads=1 file=a2.ts muted")

        remote.press(.select)
        XCTAssertTrue(element("overlay.root").waitForExistence(timeout: 10))
        move(.right, to: element("overlay.favorite"))
        XCTAssertFalse(element("overlay.multiView").exists, "no Add as new tile at the limit")
    }

    // MARK: Actions, full screen, remove and leave

    // multi-view/each-tile-has-its-own-actions
    // multi-view/one-tile-full-screen-and-back
    func testActionsFullScreenAndBack() {
        startTwoTiles()
        remote.press(.select, forDuration: 1)
        XCTAssertTrue(element("multiView.actions").waitForExistence(timeout: 5))
        expectFocus("multiView.action.fullScreen")
        XCTAssertFalse(element("multiView.action.retry").exists)
        remote.press(.menu)
        expectGone("multiView.actions")
        XCTAssertTrue(element("multiView.root").exists, "Menu only closed the actions")

        remote.press(.playPause)
        XCTAssertTrue(element("multiView.swapBadge").waitForExistence(timeout: 5))
        expect(element("multiView.swapBadge"), "label CONTAINS 'tile 2 of 2'")
        expectTile(2, "playing loads=1 file=a2.ts")
        expectTile(1, "playing loads=1 file=a1.ts muted")
        remote.press(.playPause)
        expectGone("multiView.swapBadge")

        remote.press(.select, forDuration: 1)
        XCTAssertTrue(element("multiView.actions").waitForExistence(timeout: 5))
        remote.press(.select)
        XCTAssertTrue(element("multiView.swapBadge").waitForExistence(timeout: 5))
        remote.press(.menu)
        expectGone("multiView.swapBadge")
        XCTAssertTrue(element("multiView.root").exists)
    }

    // multi-view/remove-a-tile
    func testRemovingOneOfTwoEndsMultiViewKeepingTheOther() {
        startTwoTiles()
        remote.press(.select, forDuration: 1)
        XCTAssertTrue(element("multiView.actions").waitForExistence(timeout: 5))
        move(.down, to: element("multiView.action.remove"))
        remote.press(.select)
        expectGone("multiView.root")
        expectEngine("playing loads=1 file=a1.ts")
        XCTAssertTrue(element("zapBar.bar").waitForExistence(timeout: 5), "the kept channel counts as a channel change")
    }

    // multi-view/leave-multi-view
    // tvos-shell/the-shell-hosts-multi-view
    func testMenuLeavesKeepingTheHighlightedTile() {
        startTwoTiles()
        remote.press(.menu)
        expectGone("multiView.root")
        expectEngine("playing loads=1 file=a2.ts")
        XCTAssertTrue(element("zapBar.bar").waitForExistence(timeout: 5))
        XCTAssertFalse(element("shell.tab.live").isHittable, "that Menu press does not open the tab bar")
        expectFocus("shell.picture")
    }

    // MARK: Failures

    // multi-view/a-tile-that-fails-says-why
    // multi-view/add-more-tiles-up-to-the-limit
    func testDeviceOutOfDecodersSaysSoAndTryAgainReloadsOnce() {
        startTwoTiles(environment: ["UITESTING_TILE_FAIL": "a2.ts:noDecoderFree"])
        expect(element("multiView.tile.2"), "value BEGINSWITH \"This Apple TV can't play another stream\"")
        expectTile(1, "playing loads=1 file=a1.ts muted")
        XCTAssertTrue(element("multiView.tile.2").label.hasSuffix("muted"), "a failed tile is silent")

        remote.press(.select, forDuration: 1)
        XCTAssertTrue(element("multiView.actions").waitForExistence(timeout: 5))
        expectFocus("multiView.action.retry")
        remote.press(.select)
        expectGone("multiView.actions")
        expectTile(2, "playing loads=2 file=a2.ts")
        expect(element("multiView.tile.2"), "label ENDSWITH 'sound on'")
    }

    // multi-view/a-tile-that-fails-says-why
    func testProviderRefusingAnotherStreamSaysSo() {
        startTwoTiles(environment: ["UITESTING_TILE_FAIL": "a2.ts:serverError"])
        expect(element("multiView.tile.2"), "value BEGINSWITH 'Your provider refused another stream'")
    }
}
