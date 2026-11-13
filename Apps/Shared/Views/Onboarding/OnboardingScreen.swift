import AntennaCore
import SwiftData
import SwiftUI

/// Onboarding for a user with no source: the welcome screen, "What is a
/// source?", the add-source form, the loading checklist and the summary.
/// Menu on the Apple TV welcome screen is left to the system, which sends
/// the app to the background; on the later steps it goes back one step.
struct OnboardingScreen: View {
    let model: OnboardingModel
    /// Apple TV sources that synced without their login, to sign in first.
    var signIn: [SourceDescriptor] = []
    /// Closes onboarding, asking the app to open on a channel or on Movies.
    let finish: (OnboardingHandoff.Request?) -> Void
    @Environment(\.guideStore) private var guideStore
    @State private var signedInToICloud = false
    @State private var showingHelp = false
    #if os(tvOS)
        @State private var path: [Step] = []
    #else
        @State private var showingAdd = false
        @Environment(\.importInbox) private var inbox
    #endif

    /// The Apple TV steps after the welcome screen.
    enum Step: Hashable {
        case kinds, form
    }

    var body: some View {
        content
            .preferredColorScheme(.dark)
            .task {
                signedInToICloud = ICloudAccount.isSignedIn()
                if model.setupDependencies == nil { model.setupDependencies = setupDependencies() }
                if !signIn.isEmpty { model.startSignIn(signIn) }
                #if DEBUG
                    if let fields = UITestingOnboarding.prefilledFields(), model.fields == SourceFields() { model.fields = fields }
                #endif
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

    private func setupDependencies() -> SourceSetup.Dependencies {
        #if DEBUG
            if let scripted = UITestingOnboarding.setupDependencies() { return scripted }
        #endif
        return .live(guide: guideStore)
    }

    private var actions: OnboardingWelcome.Actions {
        #if os(tvOS)
            OnboardingWelcome.Actions(addSource: { path = [.kinds] }, help: { showingHelp = true })
        #else
            OnboardingWelcome.Actions(addSource: { showingAdd = true }, help: { showingHelp = true })
        #endif
    }

    #if os(tvOS)
        @ViewBuilder private var content: some View {
            if !model.signIns.isEmpty, model.arrival == nil {
                OnboardingSignInScreen(model: model)
            } else if model.showsChecklist {
                OnboardingProgressScreen(model: model, signedInToICloud: signedInToICloud, finish: finish) {
                    path = [.kinds]
                }
            } else {
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
                                OnboardingFormScreen(model: model).modifier(SetupPairingRuntime(model: model))
                            }
                        }
                }
                .onChange(of: path) { _, steps in
                    // Menu from the form stops a running Connect; Menu all the
                    // way back from Add another source returns to the summary.
                    if !steps.contains(.form) { model.cancel() }
                    if steps.isEmpty { _ = model.leaveForm() }
                }
            }
        }
    #else
        private var content: some View {
            OnboardingWelcome.Phone(signedInToICloud: signedInToICloud, actions: actions)
                .playlistDropTarget { inbox?.receive($0) }
                .sheet(isPresented: $showingAdd, onDismiss: { _ = model.leaveForm() }) {
                    NavigationStack {
                        sheetContent
                    }
                    .interactiveDismissDisabled(model.holdsApp)
                }
                .onChange(of: model.holdsApp) { _, holds in
                    if holds { showingAdd = true }
                }
        }

        @ViewBuilder private var sheetContent: some View {
            if model.showsChecklist {
                OnboardingProgressScreen(model: model, signedInToICloud: signedInToICloud, finish: finish) {}
            } else {
                OnboardingFormScreen(model: model)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Back") {
                                // Back from Add another source returns to the summary.
                                if model.leaveForm() { showingAdd = false }
                            }
                            .accessibilityIdentifier("onboarding.back")
                        }
                    }
            }
        }
    #endif
}

/// The form with its model: the fields, Connect, and the clipboard check
/// when it appears.
struct OnboardingFormScreen: View {
    @Bindable var model: OnboardingModel
    @Environment(\.modelContext) private var context
    #if !os(tvOS)
        @State private var pickingFile = false
        @State private var importing: ImportRequest?
    #endif

    var body: some View {
        form
            .task { await model.lookForLink() }
            #if !os(tvOS)
                .playlistPicker(isPresented: $pickingFile) { importing = ImportRequest(url: $0) }
                .playlistDropTarget { importing = ImportRequest(url: $0) }
                .sheet(item: $importing) { request in
                    ImportSheet(
                        request,
                        actions: .init(
                            finish: imported,
                            addLink: { link in
                                importing = nil
                                model.fields = SourceFields(kind: .m3u, url: link.absoluteString)
                            }))
                }
            #endif
    }

    #if !os(tvOS)
        private func imported(_ saved: ImportModel.Saved?) {
            importing = nil
            if let saved { model.imported(saved.record, playlist: saved.playlist) }
        }
    #endif

    private var status: OnboardingForm.Status {
        OnboardingForm.Status(
            error: model.error, connecting: model.connecting, clipboard: model.clipboardOffer, xtreamLink: model.fields.xtreamPanel != nil)
    }

    private var actions: OnboardingForm.Actions {
        OnboardingForm.Actions(
            choose: { model.choose($0) },
            connect: { Task { await model.connect(into: context) } },
            fillIn: { model.fillIn() },
            importFile: importFile,
            useXtream: { model.useXtream() })
    }

    private var importFile: (() -> Void)? {
        #if os(tvOS)
            nil
        #else
            { pickingFile = true }
        #endif
    }

    #if os(tvOS)
        /// Where the login sent with an arrived source stands.
        private var arrivalLogin: SetupSignIn.Login {
            switch model.pairing?.login {
            case .waiting: .waiting
            case .checking: .checking
            case .missing, nil: .missing
            }
        }
    #endif

    @ViewBuilder private var form: some View {
        #if os(tvOS)
            if let arrival = model.arrival, case .code(let link) = model.pairing?.card {
                SetupSignIn.Television(fields: $model.fields, link: link.url, status: status, login: arrivalLogin) {
                    Task { await model.signIn(into: context) }
                }
                .id(arrival.id)
            } else {
                OnboardingForm.Television(fields: $model.fields, status: status, actions: actions) {
                    if let link = model.pairing?.link {
                        SetupCard.Television(link: link.url, status: .waiting(hint: model.pairing?.hint.map(SetupCard.text)))
                    } else {
                        OnboardingForm.TypeOnPhoneCard()
                    }
                }
            }
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

#if os(tvOS)
    /// The sign-in screen with its model, and the QR card that asks the
    /// iPhone for the logins (apple-tv-login-from-iphone/the-apple-tv-sign-in-offers-a-qr-code).
    private struct OnboardingSignInScreen: View {
        @Bindable var model: OnboardingModel
        @Environment(\.modelContext) private var context

        var body: some View {
            OnboardingSignIn.Television(
                fields: $model.fields,
                remaining: OnboardingSignIn.remaining(model.signInsAfterThis),
                status: .init(error: model.error, connecting: model.connecting)
            ) {
                Task { await model.signIn(into: context) }
            } card: {
                if let receiver = model.receiver, let link = receiver.link {
                    LoginQRCard.Television(link: link.url, status: LoginQRCard.status(of: receiver, names: model.signIns))
                } else {
                    OnboardingForm.TypeOnPhoneCard()
                }
            }
            .modifier(LoginReceiverRuntime(model: model))
        }
    }
#endif
