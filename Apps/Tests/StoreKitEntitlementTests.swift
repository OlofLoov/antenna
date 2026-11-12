import AntennaCore
import Foundation
import StoreKit
import StoreKitTest
import Testing

@testable import Antenna

/// The StoreKit provider against the local StoreKit configuration, `Config/Antenna.storekit`.
/// The iOS 26.5 simulator answers every `SKTestSession` purchase with
/// `notEntitled` and loads no products (Apple feedback FB23566876, fixed in
/// iOS 26.6), so the suite runs only with
/// `TEST_RUNNER_ANTENNA_STOREKIT_TESTS=1 xcodebuild test` on a runtime that works.
@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["ANTENNA_STOREKIT_TESTS"] == "1"))
struct StoreKitEntitlementTests {
    private final class Marker {}

    let session: SKTestSession
    let cache: EntitlementCache

    init() throws {
        let url = try #require(Bundle(for: Marker.self).url(forResource: "Antenna", withExtension: "storekit"))
        session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        cache = EntitlementCache(defaults: try #require(UserDefaults(suiteName: "storekit-tests-\(UUID().uuidString)")))
    }

    @Test("paywall-and-entitlement/a-purchase-counts-while-it-is-paid-up a Lifetime purchase unlocks and a refund locks")
    func lifetimeAndRefund() async throws {
        let provider = StoreKitEntitlementProvider(cache: cache)
        await provider.refresh()
        #expect(provider.current() == .notEntitled(.neverPurchased))

        let transaction = try await session.buyProduct(identifier: ProductKind.lifetime.productID)
        await provider.refresh()
        #expect(provider.current().grant?.kind == .lifetime)
        #expect(provider.current().grant?.familyShared == false)

        try session.refundTransaction(identifier: UInt(transaction.id))
        await provider.refresh()
        #expect(provider.current() == .notEntitled(.revoked))
    }

    @Test("paywall-and-entitlement/a-purchase-counts-while-it-is-paid-up a Yearly purchase unlocks until it expires")
    func yearlyThenExpired() async throws {
        let provider = StoreKitEntitlementProvider(cache: cache)
        _ = try await session.buyProduct(identifier: ProductKind.yearly.productID)
        await provider.refresh()
        let grant = try #require(provider.current().grant)
        #expect(grant.kind == .yearly)
        #expect(grant.expiresAt != nil)

        try session.expireSubscription(productIdentifier: ProductKind.yearly.productID)
        await provider.refresh()
        #expect(provider.current().lapse.map { if case .expired = $0 { true } else { false } } == true)
    }

    @Test("paywall-and-entitlement/a-buyer-goes-straight-in a purchase is remembered for the next launch")
    func remembered() async throws {
        _ = try await session.buyProduct(identifier: ProductKind.lifetime.productID)
        await StoreKitEntitlementProvider(cache: cache).refresh()
        #expect(StoreKitEntitlementProvider(cache: cache).current().isUnlocked, "before StoreKit answers")
    }
}
