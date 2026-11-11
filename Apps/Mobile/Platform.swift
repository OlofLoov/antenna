// iPhone / iPad / Mac-specific code goes here (PiP, Handoff, Live Activities, Foundation Models cleanup).

import SwiftUI

/// The window root on iPhone, iPad and Mac: onboarding while there is no
/// source (first-run-onboarding capability), then `RootView`.
struct PlatformRoot: View {
    var body: some View {
        OnboardingGate {
            RootView()
        }
    }
}
