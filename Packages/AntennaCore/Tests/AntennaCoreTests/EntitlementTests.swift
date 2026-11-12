import AntennaCore
import Foundation
import Testing

/// The verdict from purchase records, the offline grace rule and the stand-in provider.
@Suite struct EntitlementTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let day: TimeInterval = 24 * 60 * 60

    @Test("paywall-and-entitlement/a-purchase-counts-while-it-is-paid-up Lifetime unlocks for good")
    func lifetime() {
        let verdict = EntitlementResolver.resolve([PurchaseEvidence(kind: .lifetime)], now: now)
        #expect(verdict == .entitled(Grant(kind: .lifetime, verifiedAt: now)))
        #expect(verdict.isUnlocked)
        let later = EntitlementResolver.remembered(verdict, now: now.addingTimeInterval(3650 * day))
        #expect(later.isUnlocked, "no offline limit on Lifetime")
    }

    @Test("paywall-and-entitlement/a-purchase-counts-while-it-is-paid-up Yearly unlocks until its end date")
    func yearly() {
        let end = now.addingTimeInterval(30 * day)
        let paid = EntitlementResolver.resolve([PurchaseEvidence(kind: .yearly, expiresAt: end)], now: now)
        #expect(paid == .entitled(Grant(kind: .yearly, expiresAt: end, verifiedAt: now)))
        let ended = EntitlementResolver.resolve([PurchaseEvidence(kind: .yearly, expiresAt: end)], now: end.addingTimeInterval(1))
        #expect(ended == .notEntitled(.expired(on: end)))
        #expect(ended.lapse?.isLapsed == true)
    }

    @Test("paywall-and-entitlement/a-purchase-counts-while-it-is-paid-up billing grace keeps Yearly open")
    func billingGrace() {
        let end = now.addingTimeInterval(-2 * day)
        let grace = now.addingTimeInterval(14 * day)
        let verdict = EntitlementResolver.resolve([PurchaseEvidence(kind: .yearly, expiresAt: end, graceUntil: grace)], now: now)
        #expect(verdict.grant?.expiresAt == grace, "counts through the grace period")
        let after = EntitlementResolver.resolve(
            [PurchaseEvidence(kind: .yearly, expiresAt: end, graceUntil: grace)], now: grace.addingTimeInterval(1))
        #expect(after == .notEntitled(.expired(on: grace)))
    }

    @Test("paywall-and-entitlement/a-purchase-counts-while-it-is-paid-up a refund counts for nothing")
    func refund() {
        let refunded = PurchaseEvidence(kind: .lifetime, revokedAt: now)
        #expect(EntitlementResolver.resolve([refunded], now: now) == .notEntitled(.revoked))
        let refundedYearly = PurchaseEvidence(kind: .yearly, expiresAt: now.addingTimeInterval(day), revokedAt: now)
        #expect(EntitlementResolver.resolve([refundedYearly], now: now) == .notEntitled(.revoked))
        #expect(EntitlementResolver.resolve([], now: now) == .notEntitled(.neverPurchased))
        #expect(EntitlementResolver.resolve([], now: now).lapse?.isLapsed == false)
    }

    @Test("paywall-and-entitlement/a-purchase-counts-while-it-is-paid-up owning both counts as Lifetime")
    func both() {
        let evidence = [
            PurchaseEvidence(kind: .yearly, expiresAt: now.addingTimeInterval(100 * day)),
            PurchaseEvidence(kind: .lifetime, familyShared: true),
        ]
        let verdict = EntitlementResolver.resolve(evidence, now: now)
        #expect(verdict == .entitled(Grant(kind: .lifetime, familyShared: true, verifiedAt: now)))
        let own = EntitlementResolver.resolve(
            [PurchaseEvidence(kind: .lifetime, familyShared: true), PurchaseEvidence(kind: .lifetime)], now: now)
        #expect(own.grant?.familyShared == false, "an own purchase wins over a shared one")
    }

    @Test("paywall-and-entitlement/a-purchase-counts-while-it-is-paid-up a remembered Yearly stays open 16 days offline")
    func offlineGrace() {
        let end = now
        let remembered = Entitlement.entitled(Grant(kind: .yearly, expiresAt: end, verifiedAt: now.addingTimeInterval(-300 * day)))
        #expect(EntitlementResolver.remembered(remembered, now: end.addingTimeInterval(16 * day)).isUnlocked)
        #expect(
            EntitlementResolver.remembered(remembered, now: end.addingTimeInterval(16 * day + 1)) == .notEntitled(.expired(on: end)))
    }

    @Test("paywall-and-entitlement/a-purchase-counts-while-it-is-paid-up a clock far ahead locks early")
    func clockAhead() {
        let remembered = Entitlement.entitled(Grant(kind: .yearly, expiresAt: now.addingTimeInterval(200 * day), verifiedAt: now))
        let ahead = now.addingTimeInterval(400 * day)
        #expect(!EntitlementResolver.remembered(remembered, now: ahead).isUnlocked)
        #expect(EntitlementResolver.remembered(.notEntitled(.revoked), now: ahead) == .notEntitled(.revoked))
    }

    @Test("the verdict survives a JSON round trip")
    func codable() throws {
        let values: [Entitlement] = [
            .unknown,
            .entitled(Grant(kind: .yearly, expiresAt: now, familyShared: true, verifiedAt: now)),
            .notEntitled(.expired(on: now)),
            .notEntitled(.revoked),
        ]
        let data = try JSONEncoder().encode(values)
        #expect(try JSONDecoder().decode([Entitlement].self, from: data) == values)
    }

    @Test("product ids map to their kinds")
    func productIDs() {
        #expect(ProductKind(productID: "se.codecrave.antenna.lifetime") == .lifetime)
        #expect(ProductKind(productID: "se.codecrave.antenna.yearly") == .yearly)
        #expect(ProductKind(productID: "se.codecrave.antenna.other") == nil)
    }

    @Test("paywall-and-entitlement/family-members-unlock-without-buying a shared purchase unlocks like an own one")
    func familyShared() {
        let lifetime = EntitlementResolver.resolve([PurchaseEvidence(kind: .lifetime, familyShared: true)], now: now)
        #expect(lifetime == .entitled(Grant(kind: .lifetime, familyShared: true, verifiedAt: now)))
        let end = now.addingTimeInterval(30 * day)
        let yearly = EntitlementResolver.resolve([PurchaseEvidence(kind: .yearly, expiresAt: end, familyShared: true)], now: now)
        #expect(yearly.grant?.familyShared == true)
        let unshared = EntitlementResolver.resolve([PurchaseEvidence(kind: .lifetime, revokedAt: now, familyShared: true)], now: now)
        #expect(unshared == .notEntitled(.revoked), "sharing stopped")
    }

    @Test("the stand-in provider answers its verdict and streams only later changes")
    func fixedProvider() async {
        let provider = FixedEntitlementProvider(.notEntitled(.neverPurchased))
        #expect(await provider.current() == .notEntitled(.neverPurchased))
        let stream = await provider.updates()
        let grant = Grant(kind: .lifetime, verifiedAt: now)
        await provider.set(.notEntitled(.neverPurchased))
        await provider.set(.entitled(grant))
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == .entitled(grant), "the same verdict is not repeated")
        #expect(await provider.current() == .entitled(grant))
    }
}
