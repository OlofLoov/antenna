import AntennaCore
import Foundation
import StoreKit

/// The app's entitlement provider, reading StoreKit 2 on the device
/// (paywall-and-entitlement capability). `current()` answers from the
/// remembered record at once; `start()` listens to transaction updates for
/// the life of the app and asks StoreKit again in the background.
@MainActor
final class StoreKitEntitlementProvider: EntitlementProvider {
    /// The purchase records StoreKit holds now. Throws when there is no answer.
    typealias Ask = @MainActor () async throws -> [PurchaseEvidence]

    private let cache: EntitlementCache
    private let ask: Ask
    private let now: @MainActor () -> Date
    private var record: EntitlementRecord?
    private var answered = false
    private var listeners: [UUID: AsyncStream<Entitlement>.Continuation] = [:]
    private var listening: Task<Void, Never>?

    init(
        cache: EntitlementCache = EntitlementCache(), ask: @escaping Ask = StoreKitEvidence.current,
        now: @escaping @MainActor () -> Date = Date.init
    ) {
        self.cache = cache
        self.ask = ask
        self.now = now
        self.record = cache.read()
    }

    /// The remembered verdict, with the offline grace applied to a Yearly
    /// purchase. Unknown until StoreKit first answers on a device that
    /// remembers nothing.
    func current() -> Entitlement {
        EntitlementResolver.remembered(record?.entitlement ?? .unknown, now: now())
    }

    func updates() -> AsyncStream<Entitlement> {
        let (stream, continuation) = AsyncStream.makeStream(of: Entitlement.self)
        let id = UUID()
        listeners[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.listeners[id] = nil }
        }
        return stream
    }

    /// Listens to transaction updates, including an Ask to Buy approval that
    /// arrives after a relaunch, and asks StoreKit once. Calling it again does nothing.
    func start() {
        guard listening == nil else { return }
        listening = Task { [weak self] in
            for await result in Transaction.updates {
                // An unverified transaction is ignored and never finished.
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    /// Stops listening; for tests that start more than one provider.
    func stop() {
        listening?.cancel()
        listening = nil
    }

    /// Asks StoreKit and remembers the answer. The first answer of a launch
    /// counts toward the two-launch rule for an empty answer
    /// (paywall-and-entitlement/when-access-ends-the-app-locks-and-keeps-your-data).
    func refresh() async {
        guard let answer = try? await ask() else { return }
        apply(answer)
    }

    /// Applies an answer already in hand, such as the records a restore found.
    func apply(_ answer: [PurchaseEvidence]) {
        let before = current()
        let first = !answered
        answered = true
        let updated = EntitlementRecord.applying(answer, to: record, now: now(), firstOfLaunch: first)
        record = updated
        cache.write(updated)
        let after = current()
        guard after != before else { return }
        for listener in listeners.values { listener.yield(after) }
    }
}

/// Reads purchase records from StoreKit 2. Only verified transactions
/// become evidence.
enum StoreKitEvidence {
    @MainActor static func current() async -> [PurchaseEvidence] {
        var seen = Set<UInt64>()
        var evidence: [PurchaseEvidence] = []
        func add(_ result: VerificationResult<Transaction>?) async {
            guard case .verified(let transaction)? = result, ProductKind(productID: transaction.productID) != nil,
                seen.insert(transaction.id).inserted
            else { return }
            await evidence.append(PurchaseEvidence(transaction))
        }
        for await result in Transaction.currentEntitlements { await add(result) }
        // The latest record of each product names a lapse the current ones leave out.
        for kind in ProductKind.allCases { await add(await Transaction.latest(for: kind.productID)) }
        return evidence
    }
}

extension PurchaseEvidence {
    /// The evidence in a verified transaction, with the end of any billing grace period.
    init(_ transaction: Transaction) async {
        let status = await transaction.subscriptionStatus
        var graceUntil: Date?
        if status?.state == .inGracePeriod, case .verified(let renewal)? = status?.renewalInfo {
            graceUntil = renewal.gracePeriodExpirationDate
        }
        self.init(
            kind: ProductKind(productID: transaction.productID) ?? .lifetime,
            expiresAt: transaction.expirationDate,
            graceUntil: graceUntil,
            revokedAt: transaction.revocationDate,
            familyShared: transaction.ownershipType == .familyShared)
    }
}
