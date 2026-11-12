import AntennaCore
import SwiftData
import SwiftUI

/// Add a source from Settings: onboarding's form and checklist in a sheet
/// (first-run-onboarding capability). Start watching closes the sheet and
/// hands the first channel to the app.
struct SettingsAddSource: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.guideStore) private var guideStore
    @Environment(\.onboardingHandoff) private var handoff
    @State private var model = OnboardingModel(connector: .app, clipboard: .system)

    var body: some View {
        NavigationStack {
            content
        }
        .preferredColorScheme(.dark)
        .task {
            if model.setupDependencies == nil { model.setupDependencies = .live(guide: guideStore) }
        }
    }

    @ViewBuilder private var content: some View {
        if model.showsChecklist {
            OnboardingProgressScreen(model: model, signedInToICloud: ICloudAccount.isSignedIn(), finish: finish) {}
        } else {
            OnboardingFormScreen(model: model)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back") {
                            if model.leaveForm() { dismiss() }
                        }
                        .accessibilityIdentifier("onboarding.back")
                    }
                }
        }
    }

    private func finish(_ request: OnboardingHandoff.Request?) {
        model.finish()
        if let request { handoff?.hand(request) }
        dismiss()
    }
}
