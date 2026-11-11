import SwiftData
import SwiftUI

/// Where the app opens: onboarding for a user with no source, the app for
/// everyone else (first-run-onboarding/a-new-user-is-asked-for-a-provider,
/// first-run-onboarding/a-returning-user-goes-straight-to-their-channels).
/// A saved source opens the app whether or not its password is on this
/// device and whether or not it has channels.
enum OnboardingRoute: Equatable {
    case welcome
    case app

    init(sourceCount: Int) {
        self = sourceCount == 0 ? .welcome : .app
    }
}

/// Shows onboarding while the store holds no source, and `content` once
/// one exists, here or through sync. Deleting the last source brings
/// onboarding back. Nothing in `content` is built while onboarding shows,
/// so no source loads and no server is contacted.
struct OnboardingGate<Content: View>: View {
    @Query private var records: [SourceRecord]
    @ViewBuilder var content: Content

    var body: some View {
        switch OnboardingRoute(sourceCount: records.count) {
        case .welcome: OnboardingScreen()
        case .app: content
        }
    }
}

/// Whether this device is signed in to iCloud, which decides whether the
/// welcome screen mentions sync (first-run-onboarding/a-new-user-is-asked-for-a-provider).
enum ICloudAccount {
    @MainActor static func isSignedIn() -> Bool {
        #if DEBUG
            if let scripted = UITestingOnboarding.signedInToICloud() { return scripted }
        #endif
        return FileManager.default.ubiquityIdentityToken != nil
    }
}
