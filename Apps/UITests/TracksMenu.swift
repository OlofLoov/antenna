import XCTest

/// The audio-and-subtitles menu behind `player.tracks`. The system menu does
/// not carry SwiftUI identifiers to its rows, so rows are found by label in
/// the menu's own list.
extension XCUIApplication {
    /// The open menu: the list holding the "Subtitles" section title.
    var tracksMenu: XCUIElement {
        let title = NSPredicate(format: "elementType == %d AND label == 'Subtitles'", XCUIElement.ElementType.staticText.rawValue)
        return collectionViews.containing(title).firstMatch
    }

    /// The row named `label`, with or without the sound format the menu adds
    /// after a comma ("English, AAC 5.1"): a sound, "Off" or a subtitle, or
    /// the stream line. A subtitle named like a sound needs `in: .subtitles`.
    func tracksRow(_ label: String, in section: TracksSection = .any) -> XCUIElement {
        let named = tracksMenu.buttons.matching(NSPredicate(format: "label == %@ OR label BEGINSWITH %@", label, label + ", "))
        switch section {
        case .any: return named.firstMatch
        case .subtitles:
            // Subtitles come after the sounds, so the last row with the name is the subtitle.
            let exact = tracksMenu.buttons.matching(NSPredicate(format: "label == %@", label))
            return exact.element(boundBy: max(exact.count - 1, 0))
        }
    }

    enum TracksSection {
        case any, subtitles
    }

    /// Taps `player.tracks` and waits for the menu. When the controls have
    /// hidden, a tap on `picture` (the Live picture unless given) shows them.
    func openTracksMenu(picture: String = "browse.player.surface", file: StaticString = #filePath, line: UInt = #line) {
        let button = element("player.tracks")
        if !button.waitForExistence(timeout: 1) || !button.isHittable { element(picture).tap() }
        XCTAssertTrue(button.waitForExistence(timeout: 5), "no tracks button", file: file, line: line)
        button.tap()
        XCTAssertTrue(tracksMenu.waitForExistence(timeout: 5), "the menu did not open", file: file, line: line)
    }

    /// Picks the row labelled `label` and waits for the menu to close.
    func pickTrack(_ label: String, in section: TracksSection = .any, file: StaticString = #filePath, line: UInt = #line) {
        let row = tracksRow(label, in: section)
        XCTAssertTrue(row.waitForExistence(timeout: 3), "no row \(label)", file: file, line: line)
        row.tap()
        // A loaded simulator sometimes drops the tap on a row; the callers then check what the engine picked.
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: tracksMenu)
        if XCTWaiter().wait(for: [closed], timeout: 3) != .completed, row.exists { row.tap() }
        expectTracks(tracksMenu, "exists == false", "the menu stays open", file: file, line: line)
    }

    /// Waits for the row labelled `label` to be the checked one.
    func expectChecked(_ label: String, in section: TracksSection = .any, file: StaticString = #filePath, line: UInt = #line) {
        expectTracks(tracksRow(label, in: section), "isSelected == true", "\(label) is not checked", file: file, line: line)
    }

    func expectTracks(_ element: XCUIElement, _ predicate: String, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed, message, file: file, line: line)
    }
}
