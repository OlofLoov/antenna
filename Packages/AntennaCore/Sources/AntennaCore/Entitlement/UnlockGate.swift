import Foundation

/// What the window shows before onboarding and the app: a short splash,
/// the paywall, or the app (paywall-and-entitlement/nothing-works-before-the-app-is-unlocked).
public enum UnlockRoute: Equatable, Sendable {
    case splash
    case paywall
    case app
}

/// Decides the route from the verdicts it is told about. An unlock applies
/// at once. A lock found while the app is open waits for the next return to
/// the app, so a programme is never cut off
/// (paywall-and-entitlement/when-access-ends-the-app-locks-and-keeps-your-data).
public struct UnlockGate: Equatable, Sendable {
    /// The verdict the window follows.
    public private(set) var applied: Entitlement
    /// The latest verdict, applied at the next return.
    public private(set) var latest: Entitlement
    private var splashOver = false

    public init(_ entitlement: Entitlement) {
        applied = entitlement
        latest = entitlement
    }

    /// The app came back to the front, or launched: the latest verdict applies.
    public mutating func activate() {
        applied = latest
    }

    /// A new verdict. It applies now unless it would lock an open app.
    public mutating func changed(to entitlement: Entitlement) {
        latest = entitlement
        if entitlement.isUnlocked || !applied.isUnlocked { applied = entitlement }
    }

    /// The splash waited long enough for a first answer; an unknown verdict
    /// now shows the paywall.
    public mutating func endSplash() {
        splashOver = true
    }

    /// `holdsPaywall` keeps the paywall while a restore runs or "Welcome back" waits for Continue.
    public func route(holdsPaywall: Bool) -> UnlockRoute {
        if holdsPaywall { return .paywall }
        switch applied {
        case .entitled: return .app
        case .notEntitled: return .paywall
        case .unknown: return splashOver ? .paywall : .splash
        }
    }
}
