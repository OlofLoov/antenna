import AntennaCore
import Foundation
import Observation

/// The app's one answer to "is the app unlocked?", as the window root
/// follows it (paywall-and-entitlement capability). It wraps an
/// `EntitlementProvider`, the StoreKit one in the app and a stand-in in UI
/// tests, and feeds its verdicts through an `UnlockGate`.
@MainActor
@Observable
final class Unlock {
    private(set) var gate: UnlockGate
    @ObservationIgnored private let provider: any EntitlementProvider
    @ObservationIgnored private let begin: @MainActor () -> Void
    @ObservationIgnored private let record: @MainActor ([PurchaseEvidence]) async -> Void
    @ObservationIgnored let makeStore: @MainActor () -> any PaywallStore
    /// How long the splash waits for a first answer when nothing is remembered.
    @ObservationIgnored let splashWait: Duration

    /// `begin` starts the provider; `record` hands it confirmed purchase records.
    init(
        initial: Entitlement, provider: any EntitlementProvider, splashWait: Duration = .milliseconds(750),
        begin: @escaping @MainActor () -> Void = {}, record: @escaping @MainActor ([PurchaseEvidence]) async -> Void,
        makeStore: @escaping @MainActor () -> any PaywallStore
    ) {
        gate = UnlockGate(initial)
        self.provider = provider
        self.splashWait = splashWait
        self.begin = begin
        self.record = record
        self.makeStore = makeStore
    }

    /// The app over StoreKit, or the stand-in a UI test or the unit test host asks for.
    static func app() -> Unlock {
        #if DEBUG
            if let scripted = UITestingPaywall.unlock() { return scripted }
        #endif
        let provider = StoreKitEntitlementProvider()
        return Unlock(
            initial: provider.current(), provider: provider, begin: { provider.start() }, record: { provider.apply($0) },
            makeStore: { StoreKitPaywallStore() })
    }

    /// A stand-in with a set verdict. A purchase or restore sets it to what the records give.
    static func fixed(
        _ entitlement: Entitlement, store: @escaping @MainActor () -> any PaywallStore
    ) -> (Unlock, FixedEntitlementProvider) {
        let provider = FixedEntitlementProvider(entitlement)
        let unlock = Unlock(
            initial: entitlement, provider: provider, splashWait: .zero,
            record: { evidence in await provider.set(EntitlementResolver.resolve(evidence, now: Date())) }, makeStore: store)
        return (unlock, provider)
    }

    /// Follows the provider for the life of the window.
    func run() async {
        let updates = await provider.updates()
        begin()
        gate.changed(to: await provider.current())
        for await entitlement in updates { gate.changed(to: entitlement) }
    }

    /// Ends the splash after `splashWait`.
    func runSplash() async {
        try? await Task.sleep(for: splashWait)
        gate.endSplash()
    }

    /// The app came back to the front: a lock found meanwhile applies now.
    func activate() {
        gate.activate()
    }

    /// Hands confirmed purchase records to the provider.
    func purchased(_ evidence: [PurchaseEvidence]) async {
        await record(evidence)
    }
}
