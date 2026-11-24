import AntennaCore
import Testing

/// Which moment each screen plays. The UI tests check the same moments on
/// screen through the mark's accessibility value.
@Suite struct MarkPlacementTests {
    @Test("first-run-onboarding/the-welcome-says-hello: the welcome screen plays Hello")
    func welcome() {
        #expect(MarkPlacement.welcome.moment == .hello)
    }

    @Test("paywall-and-entitlement/the-splash-tunes-in: the launch splash plays Tuning")
    func splash() {
        #expect(MarkPlacement.splash.moment == .tuning)
    }

    @Test("live-tv-on-iphone-ipad-mac/the-loading-list-tunes-in: the loading list plays Tuning")
    func loadingList() {
        #expect(MarkPlacement.loadingList.moment == .tuning)
    }

    @Test("tvos-shell/the-loading-screen-tunes-in: the Apple TV loading screen plays Tuning")
    func loadingScreen() {
        #expect(MarkPlacement.loadingScreen.moment == .tuning)
    }

    @Test("paywall-and-entitlement/a-restored-purchase-ends-with-got-it: Welcome back plays Got it, the offer stands still")
    func paywall() {
        #expect(MarkPlacement.paywallRestored.moment == .gotIt)
        #expect(MarkPlacement.paywall.moment == .still)
    }

    @Test("design-system/the-mark-moves-at-three-moments: only screens that open, load or confirm move the mark")
    func onlyThreeMoments() {
        let moving = MarkPlacement.allCases.filter { $0.moment != .still }
        #expect(Set(moving.map(\.moment)) == [.hello, .tuning, .gotIt])
        #expect(MarkPlacement.sidebar.moment == .still)
    }
}
