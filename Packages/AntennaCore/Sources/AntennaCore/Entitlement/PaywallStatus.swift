import Foundation

/// The one status line the paywall shows under the products. A new attempt
/// clears it and a new status replaces it.
public enum PaywallStatus: Equatable, Sendable, CaseIterable {
    case pending
    case failed
    case restoreFailed
    case nothingFound
    case offline
    case notAllowed
    case notInStorefront

    public var key: PaywallCopy.Key {
        switch self {
        case .pending: .statusPending
        case .failed: .statusFailed
        case .restoreFailed: .statusRestoreFailed
        case .nothingFound: .statusNothingFound
        case .offline: .statusOffline
        case .notAllowed: .statusNotAllowed
        case .notInStorefront: .statusNotInStorefront
        }
    }

    public var text: String { PaywallCopy.text(key) }

    /// Shown in the error style; the rest are muted.
    public var isError: Bool {
        switch self {
        case .failed, .restoreFailed, .offline: true
        case .pending, .nothingFound, .notAllowed, .notInStorefront: false
        }
    }
}
