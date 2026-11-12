import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// The StoreKit provider with a scripted App Store answer and a scratch cache.
@MainActor
@Suite struct EntitlementProviderTests {
    struct Offline: Error {}

    let cache: EntitlementCache
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        cache = EntitlementCache(defaults: try #require(UserDefaults(suiteName: "entitlement-tests-\(UUID().uuidString)")))
    }

    /// One launch: a new provider over the same cache.
    private func launch(answer: [PurchaseEvidence]?, at date: Date? = nil) -> StoreKitEntitlementProvider {
        let moment = date ?? now
        return StoreKitEntitlementProvider(
            cache: cache,
            ask: {
                guard let answer else { throw Offline() }
                return answer
            }, now: { moment })
    }

    @Test("paywall-and-entitlement/a-buyer-goes-straight-in an offline launch after a purchase opens the app")
    func offlineAfterPurchase() async {
        let first = launch(answer: [PurchaseEvidence(kind: .lifetime)])
        #expect(first.current() == .unknown, "nothing remembered before the first answer")
        await first.refresh()
        #expect(first.current().grant?.kind == .lifetime)

        let offline = launch(answer: nil)
        #expect(offline.current().isUnlocked, "unlocked before StoreKit is asked")
        await offline.refresh()
        #expect(offline.current().isUnlocked, "no answer keeps the remembered verdict")
    }

    @Test("paywall-and-entitlement/a-purchase-counts-while-it-is-paid-up a remembered Yearly purchase locks 16 days past its end offline")
    func offlineYearly() async {
        let end = now.addingTimeInterval(24 * 60 * 60)
        await launch(answer: [PurchaseEvidence(kind: .yearly, expiresAt: end)]).refresh()
        #expect(launch(answer: nil, at: end.addingTimeInterval(15 * 24 * 60 * 60)).current().isUnlocked)
        #expect(launch(answer: nil, at: end.addingTimeInterval(17 * 24 * 60 * 60)).current() == .notEntitled(.expired(on: end)))
    }

    @Test("paywall-and-entitlement/when-access-ends-the-app-locks-and-keeps-your-data an empty answer locks on the second launch")
    func twoLaunchRule() async {
        await launch(answer: [PurchaseEvidence(kind: .lifetime)]).refresh()

        let signedOut = launch(answer: [])
        await signedOut.refresh()
        #expect(signedOut.current().isUnlocked, "the first empty answer keeps the app open")
        #expect(cache.read()?.unconfirmed == true)
        await signedOut.refresh()
        #expect(signedOut.current().isUnlocked, "a second answer in the same launch does not count")

        let next = launch(answer: [])
        await next.refresh()
        #expect(next.current() == .notEntitled(.revoked))
        #expect(launch(answer: nil).current() == .notEntitled(.revoked), "stays locked across relaunches offline")
    }

    @Test("paywall-and-entitlement/when-access-ends-the-app-locks-and-keeps-your-data a reported end reaches every listener")
    func updates() async {
        let provider = launch(answer: [PurchaseEvidence(kind: .lifetime, revokedAt: now)])
        provider.apply([PurchaseEvidence(kind: .lifetime)])
        let stream = provider.updates()
        await provider.refresh()
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == .notEntitled(.revoked))
    }

    @Test("the cache ignores an unreadable value and keeps no transaction id")
    func cacheContents() throws {
        cache.defaults.set(Data("not json".utf8), forKey: EntitlementCache.key)
        #expect(cache.read() == nil)
        cache.write(EntitlementRecord(entitlement: .entitled(Grant(kind: .yearly, expiresAt: now, familyShared: true, verifiedAt: now))))
        let stored = try #require(cache.defaults.data(forKey: EntitlementCache.key))
        let text = String(decoding: stored, as: UTF8.self)
        #expect(!text.contains("transaction"))
        #expect(!text.contains("receipt"))
    }
}
