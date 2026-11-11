import AntennaCore
import SwiftData
import SwiftUI

/// Onboarding for a user with no source: the welcome screen, "What is a
/// source?" and the add-source form. Menu on the Apple TV welcome screen is
/// left to the system, which sends the app to the background; on the later
/// steps it goes back one step.
struct OnboardingScreen: View {
    @Environment(\.modelContext) private var context
    @State private var model = OnboardingModel(connector: SourceConnector(), clipboard: .system)
    @State private var signedInToICloud = false
    @State private var showingHelp = false
    #if os(tvOS)
        @State private var path: [Step] = []
    #else
        @State private var showingAdd = false
    #endif

    /// The Apple TV steps after the welcome screen.
    enum Step: Hashable {
        case kinds, form
    }

    var body: some View {
        content
            .preferredColorScheme(.dark)
            .task { signedInToICloud = ICloudAccount.isSignedIn() }
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

    private var actions: OnboardingWelcome.Actions {
        #if os(tvOS)
            OnboardingWelcome.Actions(addSource: { path = [.kinds] }, help: { showingHelp = true })
        #else
            OnboardingWelcome.Actions(addSource: { showingAdd = true }, help: { showingHelp = true })
        #endif
    }

    #if os(tvOS)
        private var content: some View {
            NavigationStack(path: $path) {
                OnboardingWelcome.Television(signedInToICloud: signedInToICloud, actions: actions)
                    .navigationDestination(for: Step.self) { step in
                        switch step {
                        case .kinds:
                            OnboardingKinds.Television { kind in
                                model.choose(kind)
                                path.append(.form)
                            }
                        case .form:
                            OnboardingFormScreen(model: model)
                        }
                    }
            }
            .onChange(of: path) { _, steps in
                // Menu from the form while Connect runs stops the request.
                if !steps.contains(.form) { model.cancel() }
            }
        }
    #else
        private var content: some View {
            OnboardingWelcome.Phone(signedInToICloud: signedInToICloud, actions: actions)
                .sheet(isPresented: $showingAdd, onDismiss: model.cancel) {
                    NavigationStack {
                        OnboardingFormScreen(model: model)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Back") { showingAdd = false }
                                        .accessibilityIdentifier("onboarding.back")
                                }
                            }
                    }
                    .preferredColorScheme(.dark)
                }
        }
    #endif
}

/// The form with its model: the fields, Connect, and the clipboard check
/// when it appears.
struct OnboardingFormScreen: View {
    @Bindable var model: OnboardingModel
    @Environment(\.modelContext) private var context

    var body: some View {
        form
            .task { await model.lookForLink() }
    }

    private var status: OnboardingForm.Status {
        OnboardingForm.Status(error: model.error, connecting: model.connecting, clipboard: model.clipboardOffer)
    }

    private var actions: OnboardingForm.Actions {
        OnboardingForm.Actions(
            choose: { model.choose($0) },
            connect: { Task { await model.connect(into: context) } },
            fillIn: { model.fillIn() })
    }

    @ViewBuilder private var form: some View {
        #if os(tvOS)
            OnboardingForm.Television(fields: $model.fields, status: status, actions: actions)
        #else
            OnboardingForm.Phone(fields: $model.fields, revealsPassword: $model.revealsPassword, status: status, actions: actions)
                .navigationTitle("Add a source")
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
        #endif
    }
}

#Preview("Onboarding, no sources") {
    OnboardingGate {
        Text("App")
    }
    .modelContainer(for: AntennaSchema.models, inMemory: true)
}
