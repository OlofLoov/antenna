import Foundation

/// One verified purchase record from the App Store, reduced to what the
/// verdict needs. Unverified records never become evidence.
public struct PurchaseEvidence: Equatable, Sendable {
    public var kind: ProductKind
    /// The end of the paid period for Yearly; nil for Lifetime.
    public var expiresAt: Date?
    /// The end of the App Store's billing grace period while it retries a
    /// failed renewal; nil outside one.
    public var graceUntil: Date?
    /// Set when the purchase was refunded or Family Sharing stopped sharing it.
    public var revokedAt: Date?
    public var familyShared: Bool

    public init(kind: ProductKind, expiresAt: Date? = nil, graceUntil: Date? = nil, revokedAt: Date? = nil, familyShared: Bool = false) {
        self.kind = kind
        self.expiresAt = expiresAt
        self.graceUntil = graceUntil
        self.revokedAt = revokedAt
        self.familyShared = familyShared
    }

    /// When a Yearly record stops counting: its end date, or the end of a
    /// later billing grace period.
    var countsUntil: Date? {
        guard let expiresAt else { return nil }
        guard let graceUntil else { return expiresAt }
        return max(expiresAt, graceUntil)
    }
}

/// Decides the verdict from purchase records (paywall-and-entitlement/a-purchase-counts-while-it-is-paid-up).
public enum EntitlementResolver {
    /// How long a remembered Yearly purchase keeps the app open past its end
    /// date while the App Store cannot be asked.
    public static let offlineGrace: TimeInterval = 16 * 24 * 60 * 60

    /// Lifetime unlocks for good, Yearly until its end date or through
    /// billing grace, and a revoked record counts for nothing. Owning both
    /// reads as Lifetime. An own purchase wins over a shared one of the
    /// same kind.
    public static func resolve(_ evidence: [PurchaseEvidence], now: Date) -> Entitlement {
        let standing = evidence.filter { $0.revokedAt == nil }
        let lifetime = standing.filter { $0.kind == .lifetime }
        if !lifetime.isEmpty {
            let shared = lifetime.allSatisfy(\.familyShared)
            return .entitled(Grant(kind: .lifetime, familyShared: shared, verifiedAt: now))
        }
        let yearly = standing.filter { $0.kind == .yearly }
        let live = yearly.filter { ($0.countsUntil ?? .distantPast) > now }
        if let latest = live.max(by: { ($0.countsUntil ?? .distantPast) < ($1.countsUntil ?? .distantPast) }) {
            let shared = live.allSatisfy(\.familyShared)
            return .entitled(Grant(kind: .yearly, expiresAt: latest.countsUntil, familyShared: shared, verifiedAt: now))
        }
        if let ended = yearly.compactMap(\.countsUntil).max() {
            return .notEntitled(.expired(on: ended))
        }
        if evidence.contains(where: { $0.revokedAt != nil }) {
            return .notEntitled(.revoked)
        }
        return .notEntitled(.neverPurchased)
    }

    /// A remembered verdict seen at `now` without asking the App Store
    /// (paywall-and-entitlement/a-purchase-counts-while-it-is-paid-up). A
    /// Yearly grant stays unlocked up to `offlineGrace` past its end date,
    /// then reads as expired on that date. A clock set far ahead locks early
    /// until the App Store answers.
    public static func remembered(_ entitlement: Entitlement, now: Date) -> Entitlement {
        guard case .entitled(let grant) = entitlement, let end = grant.expiresAt else { return entitlement }
        return now > end.addingTimeInterval(offlineGrace) ? .notEntitled(.expired(on: end)) : entitlement
    }
}
