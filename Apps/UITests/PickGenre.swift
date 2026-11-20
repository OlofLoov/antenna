import XCTest

extension XCUIApplication {
    /// Picks the list `identifier` (`movies.genres.<slug>`, `series.genres.all`,
    /// `movies.genres.myList`) from the Genres sheet on iPhone: the genre
    /// button opens the sheet, the half-height sheet grows when the row is
    /// below its fold, and the pick closes it
    /// (movies-and-series-browsing/pick-a-genre-from-a-list-on-iphone).
    func pickGenre(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let prefix = identifier.components(separatedBy: ".").first ?? "movies"
        let button = descendants(matching: .any)["\(prefix).genres"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10), "no genre button", file: file, line: line)
        button.tap()
        let row = descendants(matching: .any)[identifier].firstMatch
        let grabber = buttons["Sheet Grabber"]
        if !row.waitForExistence(timeout: 3), grabber.exists { grabber.tap() }
        for _ in 0..<4 where !row.isHittable { descendants(matching: .any)["\(prefix).genres.sheet"].firstMatch.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 5), "no \(identifier) in the Genres sheet", file: file, line: line)
        row.tap()
    }

    /// The open list as the genre button reads it, such as "Drama, 4 titles".
    func genreButton(_ prefix: String) -> XCUIElement {
        descendants(matching: .any)["\(prefix).genres"].firstMatch
    }
}
