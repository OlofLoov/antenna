import SwiftData
import SwiftUI

/// Onboarding for a user with no source: the welcome screen, "What is a
/// source?" and the add-source form. Menu on Apple TV is left to the
/// system, which sends the app to the background.
struct OnboardingScreen: View {
    @State private var signedInToICloud = false
    @State private var showingHelp = false
    @State private var showingAdd = false

    var body: some View {
        welcome
            .preferredColorScheme(.dark)
            .task { signedInToICloud = ICloudAccount.isSignedIn() }
            .sheet(isPresented: $showingAdd) {
                AddSourceView()
            }
            #if os(tvOS)
                .fullScreenCover(isPresented: $showingHelp) {
                    OnboardingHelp.Television { showingHelp = false }
                }
            #else
                .sheet(isPresented: $showingHelp) {
                    OnboardingHelp.Phone { showingHelp = false }
                }
            #endif
    }

    @ViewBuilder private var welcome: some View {
        let actions = OnboardingWelcome.Actions(addSource: { showingAdd = true }, help: { showingHelp = true })
        #if os(tvOS)
            OnboardingWelcome.Television(signedInToICloud: signedInToICloud, actions: actions)
        #else
            OnboardingWelcome.Phone(signedInToICloud: signedInToICloud, actions: actions)
        #endif
    }
}

#Preview("Onboarding, no sources") {
    OnboardingGate {
        Text("App")
    }
    .modelContainer(for: AntennaSchema.models, inMemory: true)
}
