import AntennaCore
import StoreKit
import SwiftUI

/// The paywall screen. The app root owns the model, so the paywall can stay
/// up after the unlock while "Welcome back" waits for Continue.
struct PaywallScreen: View {
    let model: PaywallModel
    @State private var redeeming = false

    var body: some View {
        layout
            .preferredColorScheme(.dark)
            .task { await model.load() }
    }

    private var actions: Paywall.Actions {
        Paywall.Actions(
            buy: { kind in Task { await model.buy(kind) } },
            restore: { Task { await model.restore() } },
            retry: { Task { await model.load() } },
            finish: { model.finish() },
            redeem: { redeeming = true })
    }

    @ViewBuilder private var layout: some View {
        #if os(tvOS)
            // No offer codes on Apple TV (paywall-and-entitlement capability, out of scope).
            Paywall.Television(state: model.state, actions: actions)
        #else
            // A redeemed code arrives as a transaction update and unlocks through the provider.
            Paywall.Touch(state: model.state, actions: actions)
                .offerCodeRedemption(isPresented: $redeeming) { _ in }
        #endif
    }
}
