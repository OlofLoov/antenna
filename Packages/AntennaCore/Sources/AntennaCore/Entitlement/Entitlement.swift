import Foundation

/// Whether the app is unlocked, the one answer every screen reads
/// (paywall-and-entitlement capability). There is no other gate.
public enum Entitlement: Equatable, Sendable, Codable {
    /// Nothing is remembered and the App Store has not answered yet.
    case unknown
    case entitled(Grant)
    case notEntitled(Lapse)

    public var isUnlocked: Bool {
        if case .entitled = self { return true }
        return false
    }

    /// The grant behind an unlocked app, nil otherwise.
    public var grant: Grant? {
        if case .entitled(let grant) = self { return grant }
        return nil
    }

    /// Why the app is locked, nil while it is unlocked or unknown.
    public var lapse: Lapse? {
        if case .notEntitled(let lapse) = self { return lapse }
        return nil
    }
}

/// One of the two products. Its raw value is never shown.
public enum ProductKind: String, Sendable, Codable, CaseIterable {
    case lifetime
    case yearly

    /// The App Store product ids. No other id is hard-coded.
    public var productID: String {
        switch self {
        case .lifetime: "se.codecrave.antenna.lifetime"
        case .yearly: "se.codecrave.antenna.yearly"
        }
    }

    public init?(productID: String) {
        guard let kind = Self.allCases.first(where: { $0.productID == productID }) else { return nil }
        self = kind
    }
}

/// What unlocks the app. Holds no transaction id, receipt or account.
public struct Grant: Equatable, Sendable, Codable {
    public var kind: ProductKind
    /// When a Yearly purchase stops counting, its end date or the end of
    /// the App Store's billing grace period. Nil for Lifetime.
    public var expiresAt: Date?
    /// The purchase came through Family Sharing.
    public var familyShared: Bool
    /// When the App Store last confirmed it.
    public var verifiedAt: Date

    public init(kind: ProductKind, expiresAt: Date? = nil, familyShared: Bool = false, verifiedAt: Date) {
        self.kind = kind
        self.expiresAt = expiresAt
        self.familyShared = familyShared
        self.verifiedAt = verifiedAt
    }
}

/// Why the app is locked.
public enum Lapse: Equatable, Sendable, Codable {
    case neverPurchased
    /// A Yearly subscription ended on this date.
    case expired(on: Date)
    /// Refunded, or Family Sharing stopped sharing it.
    case revoked

    /// The app was unlocked once on this Apple Account, so the paywall
    /// says it is locked again.
    public var isLapsed: Bool { self != .neverPurchased }
}
