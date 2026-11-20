import XCTest

extension XCUIApplication {
    /// Opens Sources & Settings: on iPhone through the profile button,
    /// and its menu with two or more profiles; on iPad and Mac through the
    /// sidebar. Waits up to `timeout` for the button
    /// (live-tv-on-iphone-ipad-mac/settings-from-the-profile-button).
    func openSettings(timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        // Already open, as when a test opens Settings and then one of its pages.
        if descendants(matching: .any)["settings.close"].firstMatch.exists { return }
        let section = descendants(matching: .any)["browse.section.settings"].firstMatch
        let deadline = Date().addingTimeInterval(timeout)
        let toggle = descendants(matching: .any)["browse.toggleSidebar"].firstMatch
        while profileButton == nil, !section.exists, Date() < deadline {
            // A narrow iPad window folds the sidebar away until its button shows it.
            if toggle.exists, toggle.isHittable { toggle.tap() }
            _ = section.waitForExistence(timeout: 0.5)
        }
        if let profile = profileButton {
            profile.tap()
            let item = descendants(matching: .any)["profile.settings"].firstMatch
            if item.waitForExistence(timeout: 2) { item.tap() }
            // A tap while the sheet still slides up can be lost, so wait for it to come to rest.
            let close = descendants(matching: .any)["settings.close"].firstMatch
            if close.waitForExistence(timeout: 5) {
                var last = close.frame
                for _ in 0..<20 {
                    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
                    if close.frame == last { break }
                    last = close.frame
                }
            }
        } else {
            XCTAssertTrue(section.exists, "no profile button and no Settings in the sidebar", file: file, line: line)
            section.tap()
        }
    }

    /// Closes the Settings sheet on iPhone. Nothing on iPad and Mac, where
    /// Settings is a sidebar section.
    func closeSettings() {
        let close = descendants(matching: .any)["settings.close"].firstMatch
        if close.exists { close.tap() }
    }

    /// The open tab's profile button. Tabs left open keep theirs in the
    /// hierarchy off screen, so this is the one a tap can reach; nil when none can.
    var profileButton: XCUIElement? {
        descendants(matching: .any).matching(identifier: "profile.button").allElementsBoundByIndex.first { $0.isHittable }
    }

    /// The search button at the trailing end of the iPhone tab bar.
    var searchTab: XCUIElement { tabBars.buttons["Search"] }
}
