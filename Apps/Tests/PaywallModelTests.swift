import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// The paywall model over a scripted App Store.
@MainActor
@Suite struct PaywallModelTests {
    let store = ScriptedPaywallStore()
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// Collects what the paywall hands to the entitlement provider.
    final class Unlocks {
        var evidence: [[PurchaseEvidence]] = []
    }

    let unlocks = Unlocks()

    private func model(lapse: Lapse = .neverPurchased, timesOut: Bool = false) -> PaywallModel {
        let unlocks = unlocks
        let soon: @Sendable () async -> Void = {}
        let never: @Sendable () async -> Void = { try? await Task.sleep(for: .seconds(3600)) }
        let wait = timesOut ? soon : never
        return PaywallModel(store: store, lapse: lapse, unlock: { unlocks.evidence.append($0) }, waitForAnswer: wait, now: { [now] in now })
    }

    /// Lets queued main-actor work run, a bounded number of times.
    private func settle(until done: () -> Bool) async {
        for _ in 0..<200 where !done() { await Task.yield() }
    }

    @Test("paywall-and-entitlement/prices-come-from-the-app-store prices show as given with the renewal line and any offer")
    func prices() async {
        store.offer = IntroOffer(payment: .freeTrial, displayPrice: "$0.00", unit: .month)
        let paywall = model()
        #expect(paywall.state.products.map(\.price) == [.loading, .loading])
        await paywall.load()
        let products = paywall.state.products
        #expect(products.map(\.price) == [.shown("$29.99"), .shown("$9.99")])
        #expect(products[0].line.key == .lineLifetime)
        #expect(products[1].line == PaywallCopy.Line(.lineFreeTrial, "First month free, then $9.99 per year"))
        #expect(products[1].unit == "per year")
        #expect(paywall.state.title.key == .titleDefault)
        #expect(paywall.state.lapsedNote == nil)
    }

    @Test("paywall-and-entitlement/prices-come-from-the-app-store without an offer Yearly says it renews")
    func noOffer() async {
        let paywall = model()
        await paywall.load()
        #expect(paywall.state.products[1].line.key == .lineRenews)
    }

    @Test("paywall-and-entitlement/buy-once-and-you-re-in a confirmed purchase unlocks")
    func purchase() async {
        let paywall = model()
        await paywall.load()
        await paywall.buy(.yearly)
        #expect(store.purchases == [.yearly])
        #expect(unlocks.evidence == [[PurchaseEvidence(kind: .lifetime)]])
        #expect(paywall.status == nil)
        #expect(!paywall.holdsOpen, "a purchase leaves without Continue")
    }

    @Test("paywall-and-entitlement/buy-once-and-you-re-in a cancel changes nothing and a failure asks to try again")
    func cancelAndFail() async {
        let paywall = model()
        await paywall.load()
        store.purchaseOutcome = .cancelled
        await paywall.buy(.lifetime)
        #expect(paywall.status == nil)
        #expect(unlocks.evidence.isEmpty)
        store.purchaseOutcome = .failed
        await paywall.buy(.lifetime)
        #expect(paywall.status == .failed)
        store.purchaseOutcome = .offline
        await paywall.buy(.lifetime)
        #expect(paywall.status == .offline, "a new status replaces the old one")
        store.purchaseOutcome = .cancelled
        await paywall.buy(.lifetime)
        #expect(paywall.status == nil, "a new attempt clears the line")
    }

    @Test("paywall-and-entitlement/buy-once-and-you-re-in one purchase or restore at a time")
    func oneAtATime() async {
        let hold = ScriptedPaywallStore.Hold()
        store.purchaseHold = hold
        let paywall = model()
        await paywall.load()
        let first = Task { await paywall.buy(.lifetime) }
        await settle { paywall.busy != nil }
        #expect(paywall.busy == .purchasing(.lifetime))
        #expect(paywall.state.products.map(\.enabled) == [false, false])
        #expect(paywall.state.products[0].purchasing)
        #expect(!paywall.state.canRestore)
        await paywall.buy(.yearly)
        await paywall.restore()
        #expect(store.purchases == [.lifetime])
        #expect(store.restores == 0)
        hold.open()
        await first.value
        #expect(paywall.busy == nil)
    }

    @Test("paywall-and-entitlement/buy-once-and-you-re-in purchases turned off leave only Restore")
    func notAllowed() async {
        store.canMakePayments = false
        let paywall = model()
        await paywall.load()
        #expect(paywall.status == .notAllowed)
        #expect(paywall.state.products.allSatisfy { !$0.enabled })
        #expect(paywall.state.canRestore)
        await paywall.buy(.lifetime)
        #expect(store.purchases.isEmpty)
    }

    @Test("paywall-and-entitlement/waiting-for-a-parent-s-approval Ask to Buy says it is waiting")
    func askToBuy() async {
        store.purchaseOutcome = .pending
        let paywall = model()
        await paywall.load()
        await paywall.buy(.lifetime)
        #expect(paywall.status == .pending)
        #expect(paywall.status?.isError == false, "muted, not an error")
        #expect(unlocks.evidence.isEmpty, "the approval arrives through the provider")
    }

    @Test("paywall-and-entitlement/restore-your-purchase restore finds a shared purchase and waits for Continue")
    func restoreFound() async {
        store.restoreOutcome = .found([PurchaseEvidence(kind: .lifetime, familyShared: true)])
        let paywall = model()
        await paywall.load()
        await paywall.restore()
        #expect(paywall.phase == .restored(Grant(kind: .lifetime, familyShared: true, verifiedAt: now)))
        #expect(paywall.holdsOpen)
        #expect(unlocks.evidence.isEmpty, "nothing unlocks before Continue")
        paywall.finish()
        #expect(unlocks.evidence.count == 1)
        #expect(!paywall.holdsOpen)
    }

    @Test("paywall-and-entitlement/restore-your-purchase restore finds nothing and suggests purchase sharing")
    func restoreNothing() async {
        let paywall = model()
        await paywall.load()
        await paywall.restore()
        #expect(paywall.status == .nothingFound)
        store.restoreOutcome = .failed
        await paywall.restore()
        #expect(paywall.status == .restoreFailed)
    }

    @Test("paywall-and-entitlement/restore-your-purchase restore finds an ended subscription and shows the products")
    func restoreExpired() async {
        let end = now.addingTimeInterval(-86_400)
        store.restoreOutcome = .found([PurchaseEvidence(kind: .yearly, expiresAt: end)])
        let paywall = model()
        await paywall.load()
        await paywall.restore()
        #expect(paywall.phase == .offer)
        #expect(paywall.state.title.key == .titleLapsed)
        #expect(paywall.state.lapsedNote?.key == .lapsedExpired)
        #expect(unlocks.evidence.isEmpty)
    }

    @Test("paywall-and-entitlement/the-app-store-cannot-be-reached a late answer replaces the panel")
    func lateAnswer() async {
        let hold = ScriptedPaywallStore.Hold()
        store.productsHold = hold
        let paywall = model(timesOut: true)
        let loading = Task { await paywall.load() }
        await settle { paywall.phase != .offer }
        #expect(paywall.phase == .unavailable(.unreachable))
        #expect(paywall.state.canRestore, "Restore works from the panel")
        hold.open()
        await loading.value
        #expect(paywall.phase == .offer)
        #expect(paywall.state.products.map(\.price) == [.shown("$29.99"), .shown("$9.99")])
    }

    @Test("paywall-and-entitlement/the-app-store-cannot-be-reached Try again after no answer loads the products")
    func retry() async {
        store.answers = [.unreachable, .products(ScriptedPaywallStore.prices)]
        let paywall = model()
        await paywall.load()
        #expect(paywall.phase == .unavailable(.unreachable))
        await paywall.load()
        #expect(paywall.phase == .offer)
    }

    @Test("paywall-and-entitlement/the-app-store-cannot-be-reached not sold here offers no Try again")
    func notSold() async {
        store.answers = [.notSold]
        let paywall = model()
        await paywall.load()
        #expect(paywall.phase == .unavailable(.notSold))
    }

    @Test(
        "paywall-and-entitlement/when-access-ends-the-app-locks-and-keeps-your-data a lapsed paywall without an answer shows the products")
    func lapsedOffline() async {
        store.answers = [.unreachable]
        let paywall = model(lapse: .revoked)
        await paywall.load()
        #expect(paywall.phase == .offer, "a lapse keeps the products instead of the panel")
        #expect(paywall.state.products.map(\.price) == [.unavailable, .unavailable])
        #expect(paywall.state.title.key == .titleLapsed)
        #expect(paywall.state.lapsedNote?.key == .lapsedRevoked)
        await paywall.buy(.lifetime)
        #expect(paywall.status == .offline)
        #expect(store.purchases.isEmpty)
    }
}
