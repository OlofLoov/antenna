import XCTest

/// Reopening on the title watched last on Apple TV
/// (session-restore-and-recently-watched capability). The episode test runs
/// on the `watching` script of `UITestingShelf`, where Harbor Watch's first
/// episode is 30 % in at every launch; the others on the shell's `channels`
/// scenario. Each relaunch passes `-ui-testing-keep-session`.
extension ShellUITests {
    func relaunch(_ arguments: [String], environment: [String: String] = [:]) {
        app = XCUIApplication()
        app.launchArguments = arguments
        app.launchEnvironment.merge(environment) { $1 }
        app.launchInEnglish()
    }

    /// Presses Menu until `identifier` is gone, at most three times, so an
    /// extra press never leaves the app.
    func menu(until identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<3 where element(identifier).exists {
            press(.menu)
            _ = element(identifier).waitForNonExistence(timeout: 3)
        }
        XCTAssertFalse(element(identifier).exists, "\(identifier) stayed", file: file, line: line)
    }

    /// Opens `tab` from the bar over whatever has focus, moving `direction` along it.
    func openTab(_ tab: String, _ direction: XCUIRemote.Button = .right, file: StaticString = #filePath, line: UInt = #line) {
        _ = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch.waitForExistence(timeout: 10)
        press(.menu)
        XCTAssertTrue(element(tab).waitForExistence(timeout: 10), file: file, line: line)
        moveAlongTheBar(direction, to: tab, file: file, line: line)
        press(.select)
    }

    // session-restore-and-recently-watched/reopen-on-the-title-watched-last, on Apple TV
    // session-restore-and-recently-watched/what-was-watched-last, on Apple TV
    // tvos-shell/back-to-the-last-channel-on-launch, after an episode
    func testAnEpisodeReopensItsSeriesPageWithResumeFocused() {
        let shelf = ["-ui-testing-shelf", "watching", "-ui-testing-reduce-motion"]
        relaunch(shelf)
        openTab("shell.tab.series")
        expectFocus("series.hero.play")
        let card = element("series.row.continueWatching").descendants(matching: .any)["series.card.xtream#cabin#series#2"].firstMatch
        for _ in 0..<4 where !(card.exists && card.hasFocus) {
            press(.down)
            Thread.sleep(forTimeInterval: 1)
        }
        expect(card, "hasFocus == true")
        press(.select)
        expect(element("shelf.debug.engine"), "value == 'playing 21.mp4 from 810'")
        menu(until: "series.player")
        app.terminate()

        relaunch(shelf + ["-ui-testing-keep-session"])
        expect(element("title.name"), "label == 'Harbor Watch'", timeout: 15)
        expectFocus("title.play")
        expect(element("title.play"), "label BEGINSWITH 'Resume'")
        XCTAssertFalse(element("series.player").exists, "nothing plays")

        // Back goes to the section's rows.
        press(.menu)
        expectGone("title.root")
        XCTAssertTrue(element("series.hero").waitForExistence(timeout: 5))
    }

    // session-restore-and-recently-watched/what-was-watched-last, a channel after a movie, on Apple TV
    // tvos-shell/back-to-the-last-channel-on-launch
    func testAChannelWatchedAfterAMovieComesBackFullScreen() {
        relaunch(["-ui-testing-shell", "channels"], environment: ["UITESTING_WATCH_SECONDS": "1"])
        expectEngine("playing loads=1 file=a1.ts")
        expectFocus("shell.picture")
        // Menu closes the zap bar first, so the bar waits for it to go.
        expectGone("zapBar.bar", timeout: 10)
        openTab("shell.tab.movies")
        expectFocus("movies.hero.play")
        press(.select)
        expect(element("shelf.debug.engine"), "value BEGINSWITH 'playing 1.mp4'")
        menu(until: "movies.player")
        openTab("shell.tab.live", .left)
        expectEngine("playing loads=2 file=a1.ts")
        // The count is one second here; three leave room for a slow runner.
        sleep(3)
        app.terminate()

        relaunch(["-ui-testing-shell", "channels", "-ui-testing-keep-session"])
        expectEngine("playing loads=1 file=a1.ts")
        expectFocus("shell.picture")
        XCTAssertFalse(element("title.root").exists, "no title page")
    }

    // session-restore-and-recently-watched/a-title-that-cannot-open-gives-way, on Apple TV
    // tvos-shell/back-to-the-last-channel-on-launch, the title cannot open
    func testATitleThatIsGoneGivesWayToTheLastChannel() {
        relaunch(["-ui-testing-shell", "channels"])
        expectEngine("playing loads=1 file=a1.ts")
        expectFocus("shell.picture")
        // Menu closes the zap bar first, so the bar waits for it to go.
        expectGone("zapBar.bar", timeout: 10)
        openTab("shell.tab.movies")
        expectFocus("movies.hero.play")
        press(.select)
        expect(element("shelf.debug.engine"), "value BEGINSWITH 'playing 1.mp4'")
        menu(until: "movies.player")
        app.terminate()

        // The titles script answers with nothing, so Night Ferry is gone.
        relaunch(["-ui-testing-shell", "channels", "-ui-testing-shelf", "empty", "-ui-testing-keep-session"])
        expectEngine("playing loads=1 file=a1.ts")
        expectFocus("shell.picture")
        XCTAssertFalse(element("title.root").exists, "no title page")
    }
}
