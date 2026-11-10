import Foundation
import Testing

@testable import Antenna

#if os(iOS) || os(macOS)
    /// What Live shows while sources load, fail, come back empty or wait for a login.
    @Suite struct LiveStatusTests {
        let home = UUID()
        let cabin = UUID()

        private func sources(_ homeState: LiveSource.State, _ cabinState: LiveSource.State) -> [LiveSource] {
            [LiveSource(id: home, name: "Home", state: homeState), LiveSource(id: cabin, name: "Cabin", state: cabinState)]
        }

        private func status(_ homeState: LiveSource.State, _ cabinState: LiveSource.State, dismissed: Set<UUID> = []) -> LiveStatus {
            LiveStatus(sources: sources(homeState, cabinState), dismissed: dismissed)
        }

        @Test("live-tv-on-iphone-ipad-mac/sources-that-fail-are-empty-or-wait-for-a-login each source shows while any loads")
        func loading() {
            #expect(status(.loaded(channels: 412), .loading) == .loading(sources(.loaded(channels: 412), .loading)))
            #expect(LiveStatus.detail(.loaded(channels: 412)) == "412 channels")
            #expect(LiveStatus.detail(.loading) == nil)
        }

        @Test("live-tv-on-iphone-ipad-mac/sources-that-fail-are-empty-or-wait-for-a-login offline when every failure is the connection")
        func offline() {
            #expect(status(.offline, .offline) == .offline)
            #expect(status(.offline, .loaded(channels: 0)) == .offline)
            #expect(status(.offline, .failed) == .failed(waiting: []))
        }

        @Test(
            "live-tv-on-iphone-ipad-mac/sources-that-fail-are-empty-or-wait-for-a-login nothing loaded names who waits"
        )
        func nothingLoaded() {
            let waiting = ["Cabin: waiting for its login to sync from iCloud"]
            #expect(status(.failed, .waitingForLogin) == .failed(waiting: waiting))
            #expect(status(.loaded(channels: 0), .waitingForLogin) == .empty(waiting: waiting))
            #expect(status(.loaded(channels: 0), .loaded(channels: 0)) == .empty(waiting: []))
        }

        @Test("live-tv-on-iphone-ipad-mac/sources-that-fail-are-empty-or-wait-for-a-login the channels that loaded show under a banner")
        func banner() {
            #expect(status(.loaded(channels: 3), .failed) == .channels(banner: "Could not load Cabin", waiting: []))
            #expect(status(.loaded(channels: 3), .loaded(channels: 0)) == .channels(banner: "Cabin has no channels", waiting: []))
            let waiting = LiveSource(id: cabin, name: "Cabin", state: .waitingForLogin)
            #expect(status(.loaded(channels: 3), .waitingForLogin) == .channels(banner: nil, waiting: [waiting]))
            #expect(status(.loaded(channels: 3), .loaded(channels: 1)) == .channels(banner: nil, waiting: []))
        }

        @Test(
            "live-tv-on-iphone-ipad-mac/sources-that-fail-are-empty-or-wait-for-a-login a dismissed banner stays away"
        )
        func dismissed() {
            #expect(status(.loaded(channels: 3), .failed, dismissed: [cabin]) == .channels(banner: nil, waiting: []))
            let three = sources(.loaded(channels: 3), .failed) + [LiveSource(id: UUID(), name: "Office", state: .offline)]
            #expect(LiveStatus(sources: three, dismissed: [cabin]) == .channels(banner: "Could not load Cabin and Office", waiting: []))
        }
    }
#endif
