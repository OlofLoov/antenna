import XCTest

/// The iPhone title page while its details load
/// (title-detail-and-episode-picker/the-page-shows-in-one-go).
extension TitleUITests {
    // title-detail-and-episode-picker/the-page-shows-in-one-go
    func testASeriesShowsTheMarkThenThePageInOneGo() throws {
        let app = try launch(extra: ["-ui-testing-slow-series"])
        openSection(app, "series")
        app.swipeUp()
        let poster = card(app, "series", in: "drama", "xtream#cabin#series#3")
        XCTAssertTrue(poster.waitForExistence(timeout: 5))
        poster.tap()

        // The scripted series answers after three seconds: the mark shows
        // past 0.3 s, and nothing of the page shows with it.
        let mark = app.element("title.loadingMark")
        XCTAssertTrue(mark.waitForExistence(timeout: 5))
        XCTAssertTrue(app.element("title.back").exists, "Back stays while the details load")
        for part in ["title.name", "title.eyebrow", "title.play", "title.meta", "episodes.loading"] {
            XCTAssertFalse(app.element(part).exists, "\(part) shows before the details are in")
        }

        XCTAssertTrue(app.element("title.name").waitForExistence(timeout: 10))
        XCTAssertFalse(mark.exists)
        XCTAssertTrue(app.element("title.play").exists)
        XCTAssertTrue(app.element("title.meta").exists)
        XCTAssertFalse(app.element("episodes.loading").exists, "the episodes come in with the rest")
    }
}
