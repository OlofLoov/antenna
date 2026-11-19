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

        private func english(_ resource: LocalizedStringResource?) -> String? {
            resource.map { Words(Locale(identifier: "en_US"))($0) }
        }

        /// The banner over the channels, in English; nil without one.
        private func banner(_ status: LiveStatus) -> String? {
            guard case .channels(let banner, _) = status else { return nil }
            return english(banner)
        }

        /// The lines under a failed or empty message, in English.
        private func lines(_ status: LiveStatus) -> [String] {
            switch status {
            case .failed(let waiting), .empty(let waiting): waiting.compactMap { english($0) }
            default: []
            }
        }

        @Test("live-tv-on-iphone-ipad-mac/sources-that-fail-are-empty-or-wait-for-a-login each source shows while any loads")
        func loading() {
            #expect(status(.loaded(channels: 412), .loading) == .loading(sources(.loaded(channels: 412), .loading)))
            #expect(english(LiveStatus.detail(.loaded(channels: 412))) == "412 channels")
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
            let failed = status(.failed, .waitingForLogin)
            #expect({ if case .failed = failed { true } else { false } }())
            #expect(lines(failed) == waiting)
            let empty = status(.loaded(channels: 0), .waitingForLogin)
            #expect({ if case .empty = empty { true } else { false } }())
            #expect(lines(empty) == waiting)
            #expect(status(.loaded(channels: 0), .loaded(channels: 0)) == .empty(waiting: []))
        }

        @Test("live-tv-on-iphone-ipad-mac/sources-that-fail-are-empty-or-wait-for-a-login the channels that loaded show under a banner")
        func banner() {
            #expect(banner(status(.loaded(channels: 3), .failed)) == "Could not load Cabin")
            #expect(banner(status(.loaded(channels: 3), .loaded(channels: 0))) == "Cabin has no channels")
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
            #expect(banner(LiveStatus(sources: three, dismissed: [cabin])) == "Could not load Cabin and Office")
        }
    }
#endif
