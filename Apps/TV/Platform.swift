// tvOS-specific code goes here (focus tweaks, Top Shelf extension hookup).

import SwiftUI

/// What shows on Apple TV once the app is unlocked (`AppRootView`): onboarding while there is no source
/// (first-run-onboarding capability), then "Who's watching?" when there are
/// two or more profiles (profiles capability), then the shell (tvos-shell capability).
struct PlatformRoot: View {
    var body: some View {
        OnboardingGate {
            ProfileGate {
                ShellView()
            }
        }
    }
}
