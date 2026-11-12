import AntennaCore
import Foundation
import Testing

/// The splash, paywall and app route at the window root.
@Suite struct UnlockGateTests {
    let grant = Grant(kind: .lifetime, verifiedAt: Date(timeIntervalSince1970: 1_800_000_000))

    @Test("paywall-and-entitlement/nothing-works-before-the-app-is-unlocked without a purchase only the paywall shows")
    func locked() {
        let gate = UnlockGate(.notEntitled(.neverPurchased))
        #expect(gate.route(holdsPaywall: false) == .paywall)
    }

    @Test("paywall-and-entitlement/a-buyer-goes-straight-in a remembered purchase opens the app with no splash")
    func remembered() {
        #expect(UnlockGate(.entitled(grant)).route(holdsPaywall: false) == .app)
    }

    @Test("paywall-and-entitlement/a-buyer-goes-straight-in a slow App Store answer shows the splash, not the paywall")
    func slowAnswer() {
        var gate = UnlockGate(.unknown)
        #expect(gate.route(holdsPaywall: false) == .splash)
        gate.changed(to: .entitled(grant))
        #expect(gate.route(holdsPaywall: false) == .app)

        var late = UnlockGate(.unknown)
        late.endSplash()
        #expect(late.route(holdsPaywall: false) == .paywall)
        late.changed(to: .entitled(grant))
        #expect(late.route(holdsPaywall: false) == .app, "an answer after the splash still opens the app")
    }

    @Test("paywall-and-entitlement/buy-once-and-you-re-in a purchase leaves the paywall at once")
    func purchase() {
        var gate = UnlockGate(.notEntitled(.neverPurchased))
        gate.changed(to: .entitled(grant))
        #expect(gate.route(holdsPaywall: false) == .app)
        #expect(gate.route(holdsPaywall: true) == .paywall, "Welcome back waits for Continue")
    }

    @Test("paywall-and-entitlement/when-access-ends-the-app-locks-and-keeps-your-data a lock waits for the next return")
    func lockAtNextReturn() {
        var gate = UnlockGate(.entitled(grant))
        gate.changed(to: .notEntitled(.revoked))
        #expect(gate.route(holdsPaywall: false) == .app, "never mid-programme")
        #expect(gate.latest == .notEntitled(.revoked))
        gate.activate()
        #expect(gate.route(holdsPaywall: false) == .paywall)
        #expect(gate.applied.lapse == .revoked)
    }
}
