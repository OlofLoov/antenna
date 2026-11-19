import XCTest

/// The banner's rating and Trailer on Apple TV
/// (movies-and-series-browsing/rating-and-trailer-on-the-banner).
extension ShelfTVUITests {
    // movies-and-series-browsing/rating-and-trailer-on-the-banner, a playable trailer on Apple TV
    func testTrailerOnTheBannerPlaysAndMenuGoesBackToIt() {
        openMovies()
        expect(element("movies.hero.facts"), "label CONTAINS 'rated 6.8 out of 10'")
        press(.right, times: 2)
        expectFocus("movies.hero.trailer")
        XCTAssertEqual(element("movies.hero.trailer").label, "Trailer")
        press(.select)
        expect(element("shelf.debug.engine"), "value == 'playing night-ferry.m3u8 from 0'")
        press(.menu)
        expect(element("movies.player"), "exists == false")
        expectFocus("movies.hero.trailer")
        XCTAssertFalse(element("movies.row.continueWatching").exists, "a trailer saves no place")
    }

    // movies-and-series-browsing/rating-and-trailer-on-the-banner, a YouTube trailer on Apple TV
    func testATrailerPageLinkGetsNoButtonOnTheBanner() {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-shelf", "titles", "-ui-testing-reduce-motion"]
        app.launchInEnglish()
        pressMenuOnceFocused()
        let tab = element("shell.tab.movies")
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        for _ in 0..<4 where !tab.hasFocus {
            press(.right)
            Thread.sleep(forTimeInterval: 0.5)
        }
        expectFocus("shell.tab.movies")
        press(.select)
        expectFocus("movies.hero.play")
        expect(element("movies.hero.title"), "label == 'The Long Harbor'")
        expect(element("movies.hero.facts"), "label CONTAINS 'rated 7.4 out of 10'")
        XCTAssertFalse(element("movies.hero.trailer").exists)
        press(.right, times: 2)
        expectFocus("movies.hero.myList")
    }
}
