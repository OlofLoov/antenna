import AntennaCore
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

    /// `holding` keeps onboarding up after its own Connect saved a source,
    /// until the user starts watching.
    init(sourceCount: Int, holding: Bool = false) {
        self = sourceCount == 0 || holding ? .welcome : .app
    }
}

/// Shows onboarding while the store holds no source, and `content` once
/// one exists, here or through sync. Deleting the last source brings
/// onboarding back. Nothing in `content` is built while onboarding shows,
/// so no source loads and no server is contacted.
struct OnboardingGate<Content: View>: View {
    @Query private var records: [SourceRecord]
    @State private var onboarding = OnboardingModel(connector: .app, clipboard: .system)
    @State private var handoff = OnboardingHandoff()
    @ViewBuilder var content: Content
    #if !os(tvOS)
        /// The "Set up Apple TV" sheet keeps the welcome screen under it (iphone-as-setup-device capability).
        @Environment(\.setupInbox) private var setupInbox
    #endif

    var body: some View {
        let signIn = Self.needingSignIn(records)
        switch OnboardingRoute(sourceCount: records.count, holding: onboarding.holdsApp || !signIn.isEmpty || setupSheetOpen) {
        case .welcome:
            OnboardingScreen(model: onboarding, signIn: signIn) { request in
                if let request { handoff.hand(request) }
                onboarding.finish()
            }
            #if os(tvOS)
                .dropsShelfLinks()
            #endif
        case .app:
            content.environment(\.onboardingHandoff, handoff)
        }
    }
}

extension SourceConnector {
    /// The connector onboarding uses: the network and the Keychain, or the
    /// scripted ones in a Debug build launched for UI tests.
    static var app: SourceConnector {
        #if DEBUG
            if let scripted = UITestingOnboarding.connector() { return scripted }
        #endif
        return SourceConnector()
    }
}

extension OnboardingGate {
    /// On Apple TV, the sources to sign in when every source is an Xtream
    /// login, a Stalker portal or a Jellyfin server and none of their logins
    /// is on this device (first-run-onboarding/sign-in-again-on-an-apple-tv).
    /// Empty elsewhere.
    static func needingSignIn(_ records: [SourceRecord], loader: SourceLoader = .app) -> [SourceDescriptor] {
        #if os(tvOS)
            let sources = records.sorted { $0.sortOrder < $1.sortOrder }.compactMap(\.descriptor)
            guard !sources.isEmpty, sources.count == records.count, sources.allSatisfy(\.kind.signsInOnAppleTV),
                !sources.contains(where: loader.hasLogin)
            else { return [] }
            return sources
        #else
            return []
        #endif
    }
}

extension SourceKind {
    /// The kinds whose login the Apple TV sign-in asks for.
    var signsInOnAppleTV: Bool {
        self == .xtream || self == .stalker || self == .jellyfin
    }
}

extension SourceLoader {
    /// The loader the app's gates check logins with: the Keychain, or the
    /// scripted one in a Debug build launched for UI tests.
    static var app: SourceLoader {
        #if DEBUG
            if let scripted = UITestingOnboarding.loader() { return scripted }
        #endif
        return SourceLoader()
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

extension OnboardingGate {
    fileprivate var setupSheetOpen: Bool {
        #if os(tvOS)
            false
        #else
            setupInbox?.holdsApp == true
        #endif
    }
}
