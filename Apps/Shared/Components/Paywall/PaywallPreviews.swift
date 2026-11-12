import AntennaCore
import SwiftUI

/// Fixture states for the paywall previews, one per board.
extension Paywall.State {
    static let verified = Date(timeIntervalSince1970: 1_800_000_000)

    static func fixture(
        phase: Paywall.Phase = .offer, lapse: Lapse = .neverPurchased, prices: [Paywall.Price] = [.shown("$29.99"), .shown("$9.99")],
        purchasing: ProductKind? = nil, status: PaywallStatus? = nil, offer: IntroOffer? = nil
    ) -> Paywall.State {
        let products = zip(ProductKind.allCases, prices).map { kind, price in
            var line = PaywallCopy.Line(kind == .lifetime ? .lineLifetime : .lineRenews)
            if kind == .yearly, case .shown(let text) = price { line = PaywallCopy.yearlyLine(offer: offer, displayPrice: text) }
            return Paywall.Product(kind: kind, price: price, line: line, purchasing: purchasing == kind, enabled: purchasing == nil)
        }
        return Paywall.State(
            phase: phase, title: PaywallCopy.Line(lapse.isLapsed ? .titleLapsed : .titleDefault), lapsedNote: PaywallCopy.lapsedNote(lapse),
            products: products, status: status, canRestore: purchasing == nil, links: .fixture)
    }
}

extension Paywall.Actions {
    @MainActor static let none = Paywall.Actions(buy: { _ in }, restore: {}, retry: {}, finish: {}, redeem: {})
}

#Preview("Paywall, iPhone") {
    Paywall.Touch(state: .fixture(), actions: .none)
}

#Preview("Paywall, iPhone, free first week") {
    Paywall.Touch(state: .fixture(offer: IntroOffer(payment: .freeTrial, displayPrice: "$0.00", unit: .week)), actions: .none)
}

#Preview("Paywall, iPhone, prices loading") {
    Paywall.Touch(state: .fixture(prices: [.loading, .loading]), actions: .none)
}

#Preview("Paywall, iPhone, purchasing") {
    Paywall.Touch(state: .fixture(purchasing: .lifetime), actions: .none)
}

#Preview("Paywall, iPhone, waiting for approval") {
    Paywall.Touch(state: .fixture(status: .pending), actions: .none)
}

#Preview("Paywall, iPhone, purchase failed") {
    Paywall.Touch(state: .fixture(status: .failed), actions: .none)
}

#Preview("Paywall, iPhone, locked again") {
    Paywall.Touch(
        state: .fixture(lapse: .expired(on: Paywall.State.verified), prices: [.unavailable, .unavailable]), actions: .none)
}

#Preview("Paywall, iPhone, restored") {
    Paywall.Touch(
        state: .fixture(phase: .restored(Grant(kind: .lifetime, familyShared: true, verifiedAt: Paywall.State.verified))),
        actions: .none)
}

#Preview("Paywall, iPhone, unavailable") {
    Paywall.Touch(state: .fixture(phase: .unavailable(.unreachable)), actions: .none)
}

#Preview("Paywall, iPhone, not sold here") {
    Paywall.Touch(state: .fixture(phase: .unavailable(.notSold)), actions: .none)
}

#Preview("Paywall, iPad", traits: .fixedLayout(width: 1194, height: 834)) {
    Paywall.Touch(state: .fixture(), actions: .none)
}

#Preview("Paywall, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
    Paywall.Television(state: .fixture(), actions: .none)
}

#Preview("Paywall, Apple TV, purchasing", traits: .fixedLayout(width: 1920, height: 1080)) {
    Paywall.Television(state: .fixture(purchasing: .lifetime), actions: .none)
}

#Preview("Paywall, Apple TV, restored", traits: .fixedLayout(width: 1920, height: 1080)) {
    Paywall.Television(
        state: .fixture(phase: .restored(Grant(kind: .lifetime, familyShared: true, verifiedAt: Paywall.State.verified))),
        actions: .none)
}

#Preview("Paywall, Apple TV, unavailable", traits: .fixedLayout(width: 1920, height: 1080)) {
    Paywall.Television(state: .fixture(phase: .unavailable(.unreachable)), actions: .none)
}
