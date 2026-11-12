import Foundation

/// What the device remembers about the unlock between launches: the verdict
/// with any lapse, and whether the App Store last answered with nothing.
/// It holds no transaction id, signed receipt or Apple Account.
public struct EntitlementRecord: Codable, Equatable, Sendable {
    /// Bumped when the stored shape changes; a record of another version
    /// reads as absent.
    public static let currentVersion = 1

    public var version: Int
    public var entitlement: Entitlement
    /// Set when the first App Store answer of a launch was empty while the
    /// record said unlocked.
    public var unconfirmed: Bool

    public init(entitlement: Entitlement, unconfirmed: Bool = false) {
        self.version = Self.currentVersion
        self.entitlement = entitlement
        self.unconfirmed = unconfirmed
    }

    /// Decodes a stored record; nil when it is missing, unreadable or of another version.
    public static func decode(_ data: Data?) -> EntitlementRecord? {
        guard let data, let record = try? JSONDecoder().decode(EntitlementRecord.self, from: data),
            record.version == currentVersion
        else { return nil }
        return record
    }

    public func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    /// The record after an App Store answer
    /// (paywall-and-entitlement/when-access-ends-the-app-locks-and-keeps-your-data).
    /// An answer with records decides afresh. An empty answer while the
    /// record says unlocked keeps the app open and marks it unconfirmed on
    /// the first answer of a launch; the first empty answer of the next
    /// launch locks it. An empty answer leaves a remembered lapse in place.
    public static func applying(
        _ answer: [PurchaseEvidence], to record: EntitlementRecord?, now: Date, firstOfLaunch: Bool
    ) -> EntitlementRecord {
        guard answer.isEmpty else {
            return EntitlementRecord(entitlement: EntitlementResolver.resolve(answer, now: now))
        }
        guard let record, record.entitlement != .unknown else {
            return EntitlementRecord(entitlement: .notEntitled(.neverPurchased))
        }
        guard record.entitlement.isUnlocked, firstOfLaunch else { return record }
        return record.unconfirmed
            ? EntitlementRecord(entitlement: .notEntitled(.revoked))
            : EntitlementRecord(entitlement: record.entitlement, unconfirmed: true)
    }
}
