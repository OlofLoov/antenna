import AntennaCore
import SwiftData
import SwiftUI

/// Add a source from Settings: onboarding's form and checklist
/// (first-run-onboarding capability). On Apple TV it is a full-screen
/// cover that opens on the kinds and pushes the form in one
/// `NavigationStack`, so Menu goes back a page before it closes; elsewhere
/// it is a sheet that opens on the form
/// (design-system/modals-are-system-presentations). Start watching closes
/// it and hands the first channel to the app.
struct SettingsAddSource: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.guideStore) private var guideStore
    @Environment(\.onboardingHandoff) private var handoff
    @State private var model: OnboardingModel
    #if os(tvOS)
        @State private var path: [OnboardingScreen.Step] = []
    #endif

    /// `fields` opens the form filled in, as from a one-link file's
    /// "Add the link as a source".
    init(fields: SourceFields? = nil) {
        let model = OnboardingModel(connector: .app, clipboard: .system)
        if let fields { model.fields = fields }
        _model = State(initialValue: model)
    }

    var body: some View {
        content
            .task {
                if model.setupDependencies == nil { model.setupDependencies = .live(guide: guideStore) }
            }
    }

    #if os(tvOS)
        @ViewBuilder private var content: some View {
            if model.showsChecklist {
                OnboardingProgressScreen(model: model, signedInToICloud: ICloudAccount.isSignedIn(), finish: finish) {}
            } else {
                NavigationStack(path: $path) {
                    OnboardingKinds.Television(
                        choose: { kind in
                            model.choose(kind)
                            path.append(.form)
                        },
                        cancel: cancel
                    )
                    .navigationDestination(for: OnboardingScreen.Step.self) { _ in
                        OnboardingFormScreen(model: model, cancel: cancel, changeKind: { path.removeLast() })
                    }
                }
                .onChange(of: path) { _, steps in
                    // Menu from the form stops a running Connect.
                    if steps.isEmpty { model.cancel() }
                }
            }
        }
    #else
        private var content: some View {
            NavigationStack {
                if model.showsChecklist {
                    OnboardingProgressScreen(model: model, signedInToICloud: ICloudAccount.isSignedIn(), finish: finish) {}
                } else {
                    OnboardingFormScreen(model: model, cancel: cancel)
                }
            }
        }
    #endif

    /// Cancel closes the presentation, or from Add another source goes back to the summary.
    private func cancel() {
        if model.leaveForm() { dismiss() }
    }

    private func finish(_ request: OnboardingHandoff.Request?) {
        model.finish()
        if let request { handoff?.hand(request) }
        dismiss()
    }
}

extension View {
    /// Presents Add a source over Settings: a full-screen cover on Apple
    /// TV, where the form's two columns do not fit a sheet, with the
    /// backdrop that blurs and dims Settings behind it, and a sheet on
    /// iPhone, iPad and Mac (design-system/modals-are-system-presentations,
    /// design-system/pages-cover-what-is-behind-them).
    func addSourcePresentation(isPresented: Binding<Bool>) -> some View {
        #if os(tvOS)
            fullScreenCover(isPresented: isPresented) {
                SettingsAddSource().presentationBackground { CoverBackdrop() }
            }
        #else
            sheet(isPresented: isPresented) { SettingsAddSource() }
        #endif
    }
}
