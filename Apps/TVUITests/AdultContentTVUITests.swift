import XCTest

/// Adult content on Apple TV over the scripted shell with `-ui-testing-adult`:
/// the first playlist adds "XXX Night" in the group "XXX", and the
/// passcode is 2580 (adult-content capability).
extension ShellUITests {
    private func launchWithAdultContent() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shell", "channels", "-ui-testing-adult"]
        app.launchInEnglish()
        expectEngine("playing loads=1 file=a1.ts")
        expectGone("zapBar.bar", timeout: 10)
    }

    /// True when the overlay lists the group "XXX" or the channel "XXX Night".
    private func overlayListsAdultChannel() -> Bool {
        openOverlay()
        let found = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'XXX'")).firstMatch.exists
        press(.menu)
        expectGone("overlay.root")
        return found
    }

    /// Moves focus onto the passcode key `digit` by pressing toward it.
    private func focusKey(_ digit: Character) {
        let key = element("groups.passcode.key.\(digit)")
        XCTAssertTrue(key.waitForExistence(timeout: 5))
        for _ in 0..<12 where !key.hasFocus {
            let focused = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
            guard focused.exists else {
                press(.down)
                continue
            }
            let from = focused.frame
            let to = key.frame
            if to.midY > from.maxY {
                press(.down)
            } else if to.midY < from.minY {
                press(.up)
            } else if to.midX > from.midX {
                press(.right)
            } else {
                press(.left)
            }
        }
        XCTAssertTrue(key.hasFocus, "the key \(digit) never took focus; focused: \(focusedElements())")
    }

    private func typeOnRemote(_ digits: String) {
        for digit in digits {
            focusKey(digit)
            press(.select)
        }
    }

    /// Leaves Settings for the tab bar, then the Live picture.
    private func backToLive() {
        let live = element("shell.tab.live")
        for _ in 0..<3 where !live.exists {
            press(.menu)
            _ = live.waitForExistence(timeout: 2)
        }
        for _ in 0..<8 where !live.hasFocus { press(.left) }
        expectFocus("shell.tab.live")
        press(.select)
        expectGone("shell.tab.live")
    }

    /// Opens Settings and moves focus to Show adult content.
    private func focusAdultSwitch() -> XCUIElement {
        openSettingsOnProfiles()
        let row = element("settings.adultContent")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let focused = app.descendants(matching: .any).matching(
            NSPredicate(format: "hasFocus == true AND label CONTAINS 'Show adult content'"))
        for _ in 0..<4 where !focused.firstMatch.exists { press(.down) }
        XCTAssertTrue(focused.firstMatch.waitForExistence(timeout: 5), "the switch never took focus; focused: \(focusedElements())")
        return row
    }

    // adult-content/hidden-everywhere-by-default
    // adult-content/show-adult-content-with-the-passcode
    func testAdultContentNeedsThePasscodeOnAppleTVAndHidesAgainWhenSwitchedOff() {
        launchWithAdultContent()
        XCTAssertFalse(overlayListsAdultChannel(), "the adult channel is listed by default")

        let row = focusAdultSwitch()
        press(.select)
        XCTAssertTrue(element("groups.passcode").waitForExistence(timeout: 10))
        XCTAssertTrue(element("groups.passcode.forgot").exists, "the prompt says where to reset it")
        typeOnRemote("2580")
        expectGone("groups.passcode")
        expect(row, "value == '1' OR value == 'On'")

        backToLive()
        XCTAssertTrue(overlayListsAdultChannel(), "the adult channel is not listed after the passcode")

        _ = focusAdultSwitch()
        press(.select)
        XCTAssertFalse(element("groups.passcode").waitForExistence(timeout: 2), "turning it off asked for the passcode")
        expect(row, "value == '0' OR value == 'Off'")
        backToLive()
        XCTAssertFalse(overlayListsAdultChannel(), "the adult channel is listed after switching off")
    }
}
