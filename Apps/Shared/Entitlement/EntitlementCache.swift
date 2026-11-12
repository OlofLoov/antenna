import AntennaCore
import Foundation

/// The remembered verdict on this device, so the app opens without the
/// network (paywall-and-entitlement/a-buyer-goes-straight-in). JSON under
/// `paywall.entitlement` in `UserDefaults`, never synced. It holds the
/// verdict and any lapse, never a transaction id, receipt or Apple Account.
struct EntitlementCache: Sendable {
    static let key = "paywall.entitlement"

    nonisolated(unsafe) let defaults: UserDefaults

    /// `defaults` is the suite to keep the record in, so an app group can take it over later.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Nil when nothing is stored, or the stored value is unreadable or of another version.
    func read() -> EntitlementRecord? {
        EntitlementRecord.decode(defaults.data(forKey: Self.key))
    }

    func write(_ record: EntitlementRecord) {
        guard let data = record.encoded() else { return }
        defaults.set(data, forKey: Self.key)
    }
}
