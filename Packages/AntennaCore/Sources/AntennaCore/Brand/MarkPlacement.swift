import Foundation

/// Every place the app shows the Antuna mark, and what it does there
/// (design.md decision 4 of add-tuna-wordmark). Views read `moment` from
/// here, so this table is where a placement changes.
public enum MarkPlacement: CaseIterable, Sendable {
    /// The welcome screen on every platform (first-run-onboarding/the-welcome-says-hello).
    case welcome
    /// The launch splash while the App Store answers (paywall-and-entitlement/the-splash-tunes-in).
    case splash
    /// The list on iPhone, iPad and Mac while sources load (live-tv-on-iphone-ipad-mac/the-loading-list-tunes-in).
    case loadingList
    /// The Apple TV loading screen at launch (tvos-shell/the-loading-screen-tunes-in).
    case loadingScreen
    /// The paywall showing the products, or saying the App Store is unavailable.
    case paywall
    /// The paywall after Restore found a purchase (paywall-and-entitlement/a-restored-purchase-ends-with-got-it).
    case paywallRestored
    /// The head of the iPad and Mac sidebar.
    case sidebar

    public var moment: MarkMoment {
        switch self {
        case .welcome: .hello
        case .splash, .loadingList, .loadingScreen: .tuning
        case .paywallRestored: .gotIt
        case .paywall, .sidebar: .still
        }
    }
}
