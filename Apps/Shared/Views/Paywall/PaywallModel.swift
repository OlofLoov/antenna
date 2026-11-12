import AntennaCore
import Foundation
import Observation

/// The paywall's state and actions (paywall-and-entitlement capability).
/// One purchase or restore runs at a time, at most one status line shows,
/// and a new attempt clears it.
@MainActor
@Observable
final class PaywallModel {
    enum Busy: Equatable {
        case purchasing(ProductKind)
        case restoring
    }

    private(set) var phase: Paywall.Phase = .offer
    private(set) var prices: [ProductKind: Paywall.Price] = [:]
    private(set) var status: PaywallStatus?
    private(set) var busy: Busy?
    /// Why the app is locked; a lapse puts "Antenna is locked again" on top.
    private(set) var lapse: Lapse
    /// Yearly's offer once eligibility is known; nil before and when there is none.
    private(set) var offer: IntroOffer?
    private var restored: [PurchaseEvidence] = []
    private var released = false
    private var attempt = 0

    private let store: any PaywallStore
    private let unlock: ([PurchaseEvidence]) -> Void
    private let waitForAnswer: @Sendable () async -> Void
    private let now: () -> Date

    /// `unlock` hands confirmed purchase records to the entitlement
    /// provider. `waitForAnswer` returns when the App Store counts as
    /// unreachable, 10 seconds in the app.
    init(
        store: any PaywallStore, lapse: Lapse, links: PaywallLinks = .fixture, unlock: @escaping ([PurchaseEvidence]) -> Void,
        waitForAnswer: @escaping @Sendable () async -> Void = { try? await Task.sleep(for: .seconds(10)) },
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.lapse = lapse
        self.links = links
        self.unlock = unlock
        self.waitForAnswer = waitForAnswer
        self.now = now
    }

    /// The paywall stays on screen while a restore runs and while "Welcome
    /// back" waits for Continue, even once the app is unlocked.
    var holdsOpen: Bool {
        if busy == .restoring { return true }
        if case .restored = phase { return !released }
        return false
    }

    /// Updates the lapse when the provider reports a new one.
    func show(_ lapse: Lapse) {
        self.lapse = lapse
    }

    /// Loads the products. A panel replaces them when the App Store does
    /// not answer in time and nothing was ever bought here; a late answer
    /// puts the products back (paywall-and-entitlement/the-app-store-cannot-be-reached).
    func load() async {
        attempt += 1
        let current = attempt
        status = nil
        phase = .offer
        prices = Dictionary(uniqueKeysWithValues: ProductKind.allCases.map { ($0, .loading) })
        let wait = waitForAnswer
        let timer = Task { [weak self] in
            await wait()
            guard !Task.isCancelled else { return }
            self?.noAnswer(current)
        }
        let answer = await store.products()
        timer.cancel()
        guard current == attempt else { return }
        switch answer {
        case .products(let products):
            phase = .offer
            prices = Dictionary(uniqueKeysWithValues: products.map { ($0.kind, .shown($0.displayPrice)) })
            if !store.canMakePayments { status = .notAllowed }
            offer = await store.introOffer()
        case .notSold:
            phase = .unavailable(.notSold)
        case .unreachable:
            noAnswer(current)
        }
    }

    private func noAnswer(_ current: Int) {
        guard current == attempt, prices.values.contains(.loading) else { return }
        if lapse.isLapsed {
            phase = .offer
            prices = prices.mapValues { $0 == .loading ? .unavailable : $0 }
        } else {
            phase = .unavailable(.unreachable)
        }
    }

    /// Buys `kind` (paywall-and-entitlement/buy-once-and-you-re-in). A
    /// confirmed purchase unlocks at once; a cancel changes nothing.
    func buy(_ kind: ProductKind) async {
        guard busy == nil else { return }
        guard store.canMakePayments else {
            status = .notAllowed
            return
        }
        guard case .shown = prices[kind] else {
            status = .offline
            return
        }
        status = nil
        busy = .purchasing(kind)
        let outcome = await store.purchase(kind)
        busy = nil
        switch outcome {
        case .purchased(let evidence): unlock(evidence)
        case .cancelled: break
        case .pending: status = .pending
        case .failed: status = .failed
        case .offline: status = .offline
        case .notAllowed: status = .notAllowed
        }
    }

    /// Restores this Apple Account's purchase (paywall-and-entitlement/restore-your-purchase).
    func restore() async {
        guard busy == nil else { return }
        status = nil
        busy = .restoring
        let outcome = await store.restore()
        busy = nil
        switch outcome {
        case .found(let evidence):
            switch EntitlementResolver.resolve(evidence, now: now()) {
            case .entitled(let grant):
                restored = evidence
                released = false
                phase = .restored(grant)
            case .notEntitled(.neverPurchased), .unknown:
                status = .nothingFound
            case .notEntitled(let lapse):
                self.lapse = lapse
                if case .unavailable = phase { await load() }
            }
        case .cancelled: break
        case .failed: status = .restoreFailed
        case .offline: status = .offline
        }
    }

    /// Continue on "Welcome back": unlocks and lets the paywall go.
    func finish() {
        guard case .restored = phase, !released else { return }
        released = true
        unlock(restored)
    }

    /// The view's values.
    var state: Paywall.State {
        Paywall.State(
            phase: phase,
            title: PaywallCopy.Line(lapse.isLapsed ? .titleLapsed : .titleDefault),
            lapsedNote: PaywallCopy.lapsedNote(lapse),
            products: ProductKind.allCases.map(product),
            status: status,
            canRestore: busy == nil,
            links: links)
    }

    private let links: PaywallLinks

    private func product(_ kind: ProductKind) -> Paywall.Product {
        let price = prices[kind] ?? .loading
        let line: PaywallCopy.Line
        switch (kind, price) {
        case (.lifetime, _): line = PaywallCopy.Line(.lineLifetime)
        case (.yearly, .shown(let text)): line = PaywallCopy.yearlyLine(offer: offer, displayPrice: text)
        case (.yearly, _): line = PaywallCopy.Line(.lineRenews)
        }
        return Paywall.Product(
            kind: kind, price: price, line: line, purchasing: busy == .purchasing(kind),
            enabled: busy == nil && store.canMakePayments)
    }
}
