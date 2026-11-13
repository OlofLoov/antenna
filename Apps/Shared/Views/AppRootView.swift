import AntennaCore
import SwiftUI

/// The window root on every platform. It shows a short splash, the
/// paywall, or `content` (onboarding, "Who's watching?" and the app), in
/// that order (paywall-and-entitlement/nothing-works-before-the-app-is-unlocked,
/// design-system/nothing-shows-before-the-paywall). Nothing in `content` is
/// built while the paywall shows, so no source, playlist or guide is contacted.
struct AppRootView<Content: View>: View {
    let unlock: Unlock
    @ViewBuilder var content: Content
    @Environment(\.scenePhase) private var scenePhase
    @State private var paywall: PaywallModel?
    @State private var leftApp = false

    private var route: UnlockRoute {
        unlock.gate.route(holdsPaywall: paywall?.holdsOpen ?? false)
    }

    var body: some View {
        Group {
            switch route {
            case .splash:
                LaunchSplash()
            case .paywall:
                Group {
                    if let paywall {
                        PaywallScreen(model: paywall)
                    } else {
                        Palette.ground.ignoresSafeArea()
                    }
                }
                #if os(tvOS)
                    .dropsShelfLinks()
                #endif
            case .app:
                content
            }
        }
        // Dark on every platform, sheets and covers included, and the accent
        // as the tint system controls draw with (design-system/one-accent-color).
        .preferredColorScheme(.dark)
        .accentTint()
        .task { await unlock.run() }
        .task { await unlock.runSplash() }
        .onChange(of: route, initial: true) { _, route in
            switch route {
            case .paywall where paywall == nil: paywall = makePaywall()
            case .app: paywall = nil
            case .paywall, .splash: break
            }
        }
        .onChange(of: unlock.gate.applied) { _, applied in
            if let lapse = applied.lapse { paywall?.show(lapse) }
        }
        #if os(tvOS)
            .modifier(TopShelfLock(entitlement: unlock.gate.applied))
        #endif
        // A lock found while the app is open applies when the user comes
        // back to it, never mid-programme
        // (paywall-and-entitlement/when-access-ends-the-app-locks-and-keeps-your-data).
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: leftApp = true
            case .active where leftApp:
                leftApp = false
                unlock.activate()
            default: break
            }
        }
    }

    private func makePaywall() -> PaywallModel {
        let unlock = unlock
        return PaywallModel(
            store: unlock.makeStore(), lapse: unlock.gate.applied.lapse ?? .neverPurchased, links: .load(),
            unlock: { evidence in Task { await unlock.purchased(evidence) } })
    }
}

extension View {
    /// The accent as the tint on iPhone, iPad and Mac. Apple TV keeps the
    /// system tint: tinted, bordered buttons draw accent text on an accent
    /// fill and focused rows tint their titles, while the focused platter
    /// stays light either way (design-system/focus-is-the-lifted-white-card).
    @ViewBuilder fileprivate func accentTint() -> some View {
        #if os(tvOS)
            self
        #else
            tint(Palette.accent)
        #endif
    }
}
