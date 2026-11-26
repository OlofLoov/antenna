import Foundation
import Testing

@testable import AntennaCore

@Suite struct TitleRevealTests {
    @Test("title-detail-and-episode-picker/the-page-shows-in-one-go nothing of the page shows while the details load")
    func hiddenWhileLoading() {
        let opening = TitleReveal.opening(loading: true)
        #expect(opening == .waiting)
        #expect(!opening.showsPage)
        #expect(opening.moment == nil)
        let tuning = opening.delayPassed()
        #expect(tuning == .tuning)
        #expect(!tuning.showsPage)
        #expect(tuning.moment == .tuning)
        #expect(tuning.delayPassed() == .tuning)
    }

    @Test("title-detail-and-episode-picker/the-page-shows-in-one-go a slow load ends with Got it, then the page")
    func slowLoad() {
        let gotIt = TitleReveal.opening(loading: true).delayPassed().loaded()
        #expect(gotIt == .gotIt)
        #expect(!gotIt.showsPage)
        #expect(gotIt.moment == .gotIt)
        #expect(gotIt.gotItPlayed().showsPage)
        #expect(TitleReveal.gotItHold(reduceMotion: false) == 0.6)
        #expect(TitleReveal.gotItHold(reduceMotion: true) == 0.2)
    }

    @Test("title-detail-and-episode-picker/the-page-shows-in-one-go a fast load goes straight to the page without the mark")
    func fastLoad() {
        #expect(TitleReveal.opening(loading: true).loaded() == .page)
        #expect(TitleReveal.delay == .milliseconds(300))
    }

    @Test("title-detail-and-episode-picker/the-page-shows-in-one-go details already known show the page at once")
    func known() {
        #expect(TitleReveal.opening(loading: false) == .page)
        #expect(TitleReveal.page.loaded() == .page)
    }

    @Test("title-detail-and-episode-picker/the-page-shows-in-one-go Retry keeps the shown page")
    func retry() {
        #expect(TitleReveal.page.loadingAgain() == .page)
        #expect(TitleReveal.gotIt.loadingAgain() == .page)
        #expect(TitleReveal.tuning.loadingAgain() == .tuning)
    }
}
