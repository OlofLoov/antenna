import AntennaCore
import Foundation
import Testing

/// The remembered verdict and the two-launch rule for an empty App Store answer.
@Suite struct EntitlementRecordTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    var unlocked: EntitlementRecord { EntitlementRecord(entitlement: .entitled(Grant(kind: .lifetime, verifiedAt: now))) }

    @Test("paywall-and-entitlement/when-access-ends-the-app-locks-and-keeps-your-data an empty answer locks only on the second launch")
    func twoLaunches() {
        let first = EntitlementRecord.applying([], to: unlocked, now: now, firstOfLaunch: true)
        #expect(first.entitlement.isUnlocked, "the first empty answer keeps the app open")
        #expect(first.unconfirmed)
        let laterSameLaunch = EntitlementRecord.applying([], to: first, now: now, firstOfLaunch: false)
        #expect(laterSameLaunch == first, "later answers in the same launch do not count")
        let second = EntitlementRecord.applying([], to: first, now: now, firstOfLaunch: true)
        #expect(second.entitlement == .notEntitled(.revoked))
        #expect(!second.unconfirmed)
    }

    @Test("paywall-and-entitlement/when-access-ends-the-app-locks-and-keeps-your-data a purchase found clears the mark")
    func confirmed() {
        let marked = EntitlementRecord(entitlement: unlocked.entitlement, unconfirmed: true)
        let found = EntitlementRecord.applying([PurchaseEvidence(kind: .lifetime)], to: marked, now: now, firstOfLaunch: true)
        #expect(found.entitlement.isUnlocked)
        #expect(!found.unconfirmed)
    }

    @Test("paywall-and-entitlement/when-access-ends-the-app-locks-and-keeps-your-data a reported end locks at once and stays locked")
    func reportedEnd() {
        let refunded = EntitlementRecord.applying(
            [PurchaseEvidence(kind: .lifetime, revokedAt: now)], to: unlocked, now: now, firstOfLaunch: false)
        #expect(refunded.entitlement == .notEntitled(.revoked))
        let relaunch = EntitlementRecord.applying([], to: refunded, now: now, firstOfLaunch: true)
        #expect(relaunch.entitlement == .notEntitled(.revoked), "an empty answer keeps the remembered lapse")
        #expect(EntitlementRecord.applying([], to: nil, now: now, firstOfLaunch: true).entitlement == .notEntitled(.neverPurchased))
    }

    @Test("paywall-and-entitlement/a-buyer-goes-straight-in the record round trips and rejects other versions")
    func storage() throws {
        let data = try #require(unlocked.encoded())
        #expect(EntitlementRecord.decode(data) == unlocked)
        #expect(EntitlementRecord.decode(Data("{}".utf8)) == nil)
        var old = unlocked
        old.version = 0
        #expect(EntitlementRecord.decode(old.encoded()) == nil)
        #expect(EntitlementRecord.decode(nil) == nil)
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("transaction"), "no transaction id is kept")
    }
}
