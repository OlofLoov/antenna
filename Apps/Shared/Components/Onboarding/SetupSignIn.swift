#if os(tvOS)
    import AntennaCore
    import SwiftUI

    /// "Sign in on this Apple TV" for a login source sent from the iPhone
    /// (`TV-Onboard-3-QR-SignIn`): Name and the server or portal locked,
    /// the login fields kept as typed, and the QR card dimmed with the
    /// arrival. While the login is on its way from the iPhone the card says
    /// so (`TV-Onboard-3-QR-Received`); once it is missing, "Sign in on this
    /// Apple TV" on the card moves focus to the first login field and goes away.
    enum SetupSignIn {
        /// Where the login sent with the source stands.
        enum Login: Equatable {
            case waiting
            case checking
            case missing
        }

        struct Television: View {
            @Binding var fields: SourceFields
            let link: URL
            let status: OnboardingForm.Status
            var login = Login.missing
            let connect: () -> Void
            /// Cancel beside Connect; nil leaves it out.
            var cancel: (() -> Void)?
            @State private var chosen = false
            @FocusState private var focus: Focus?

            enum Focus: Hashable { case login, signInHere }

            var body: some View {
                FormPage.Television(
                    title: "Sign in on this Apple TV",
                    line: "\(fields.kind == .stalker ? "Portal" : "Server") and name came from your iPhone.",
                    footer: OnboardingForm.keychainLine(fields.kind), error: status.error
                ) {
                    SetupCard.Television(link: link, status: cardStatus) {
                        if !chosen, login == .missing {
                            SetupCard.SignInHere(action: signInHere).focused($focus, equals: .signInHere)
                        }
                    }
                } rows: {
                    Section {
                        FieldRow.Value(label: "Name", value: fields.name, identifier: "onboarding.field.name")
                        FieldRow.Value(
                            label: fields.kind == .stalker ? "Portal" : "Server", value: fields.url,
                            identifier: fields.kind == .stalker ? "onboarding.field.portal" : "onboarding.field.server")
                        loginFields
                    }
                    .disabled(status.connecting)
                } buttons: {
                    OnboardingForm.Buttons(connecting: status.connecting, connect: connect, cancel: cancel)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("onboarding.signIn")
                .defaultFocus($focus, .signInHere)
                .onChange(of: login) { _, login in
                    // The login did not come: the button appears and takes focus, as on arrival.
                    if login == .missing, !chosen { focus = .signInHere }
                }
            }

            private var cardStatus: SetupCard.Status {
                switch login {
                case .waiting: .awaitingLogin(name: fields.name, progress: SetupCard.waitingForLogin)
                case .checking: .awaitingLogin(name: fields.name, progress: SetupCard.checkingLogin)
                case .missing: .arrived(name: fields.name, missing: SetupCard.missing(fields.kind))
                }
            }

            private func signInHere() {
                chosen = true
                focus = .login
            }

            /// The login rows; the first takes focus after "Sign in on this Apple TV".
            @ViewBuilder private var loginFields: some View {
                if fields.kind == .stalker {
                    FieldRow.Text(
                        label: "MAC address", text: $fields.mac, prompt: "00:1A:79:12:34:56", entry: .plain,
                        identifier: "onboarding.field.mac"
                    )
                    .focused($focus, equals: .login)
                    FieldRow.Text(
                        label: "Login", text: $fields.username, prompt: "Optional", entry: .plain, identifier: "onboarding.field.username")
                    FieldRow.Secret(label: "Password", text: $fields.password, prompt: "Optional")
                } else {
                    FieldRow.Text(
                        label: "Username", text: $fields.username, prompt: "Required", entry: .plain,
                        identifier: "onboarding.field.username"
                    )
                    .focused($focus, equals: .login)
                    FieldRow.Secret(label: "Password", text: $fields.password, prompt: "Required")
                }
            }
        }
    }

    private let previewLink = SetupLink(token: PairingToken("AAAAAAAAAAAAAAAAAAAAAA") ?? PairingToken()).url

    #Preview("Sign in after an Xtream source arrived", traits: .fixedLayout(width: 1920, height: 1080)) {
        @Previewable @State var fields = SourceFields(kind: .xtream, name: "Home provider", url: "http://tv.example-provider.net:8080")
        SetupSignIn.Television(fields: $fields, link: previewLink, status: .init(), connect: {})
    }

    #Preview("Waiting for the login after an Xtream source arrived", traits: .fixedLayout(width: 1920, height: 1080)) {
        @Previewable @State var fields = SourceFields(kind: .xtream, name: "Home provider", url: "http://tv.example-provider.net:8080")
        SetupSignIn.Television(fields: $fields, link: previewLink, status: .init(), login: .waiting, connect: {})
    }

    #Preview("Sign in after a Stalker portal arrived", traits: .fixedLayout(width: 1920, height: 1080)) {
        @Previewable @State var fields = SourceFields(kind: .stalker, name: "Portal", url: "http://portal.example-provider.net/c/")
        SetupSignIn.Television(fields: $fields, link: previewLink, status: .init(), connect: {})
    }
#endif
