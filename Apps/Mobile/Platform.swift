// iPhone / iPad / Mac-specific code goes here (PiP, Handoff, Live Activities, Foundation Models cleanup).

import SwiftUI

/// What shows on iPhone, iPad and Mac once the app is unlocked (`AppRootView`): onboarding while there is no
/// source (first-run-onboarding capability), then "Who's watching?" when
/// there are two or more profiles (profiles capability), then the tabs.
struct PlatformRoot: View {
    var body: some View {
        OnboardingGate {
            ProfileGate {
                RootView()
            }
        }
    }
}
