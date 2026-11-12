#if os(tvOS)
    import AntennaCore
    import SwiftUI

    /// "Sign in on this Apple TV" for a login source sent from the iPhone
    /// (`TV-Onboard-3-QR-SignIn`): Name and the server or portal locked,
    /// the login fields kept as typed, and the QR card dimmed with the
    /// arrival. "Sign in on this Apple TV" on the card moves focus to the
    /// first login field and goes away.
    enum SetupSignIn {
        struct Television: View {
            @Binding var fields: SourceFields
            let link: URL
            let status: OnboardingForm.Status
            let connect: () -> Void
            @State private var chosen = false
            @FocusState private var focus: Focus?

            enum Focus: Hashable { case login, signInHere }

            var body: some View {
                HStack(alignment: .center, spacing: 80) {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Sign in on this Apple TV")
                                .font(.system(size: 52, weight: .heavy))
                                .accessibilityAddTraits(.isHeader)
                            Text("\(fields.kind == .stalker ? "Portal" : "Server") and name came from your iPhone.")
                                .font(.system(size: 24))
                                .foregroundStyle(Palette.textMuted)
                        }
                        VStack(alignment: .leading, spacing: 14) {
                            Locked(label: "Name", value: fields.name, identifier: "onboarding.field.name")
                            Locked(
                                label: fields.kind == .stalker ? "Portal" : "Server", value: fields.url,
                                identifier: fields.kind == .stalker ? "onboarding.field.portal" : "onboarding.field.server")
                            loginFields
                        }
                        if let error = status.error {
                            Text(error)
                                .font(.system(size: 22))
                                .foregroundStyle(OnboardingForm.errorColor)
                                .accessibilityIdentifier("onboarding.error")
                        }
                        HStack(spacing: 16) {
                            Button(status.connecting ? "Connecting…" : "Connect", action: connect)
                                .buttonStyle(OnboardingStyle.PrimaryTV())
                                .disabled(status.connecting)
                                .accessibilityIdentifier("onboarding.connect")
                            if status.connecting { ProgressView() }
                            Label("Saved in the Keychain on this Apple TV. Antenna has no servers.", systemImage: "lock")
                                .font(.system(size: 20))
                                .foregroundStyle(Palette.textMuted)
                        }
                        .padding(.top, 6)
                    }
                    .frame(width: 820)
                    SetupCard.Television(link: link, status: .arrived(name: fields.name, missing: SetupCard.missing(fields.kind))) {
                        if !chosen {
                            SetupCard.SignInHere(action: signInHere).focused($focus, equals: .signInHere)
                        }
                    }
                }
                .foregroundStyle(Palette.text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.ground)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("onboarding.signIn")
                .defaultFocus($focus, .signInHere)
            }

            private func signInHere() {
                chosen = true
                focus = .login
            }

            @ViewBuilder private var loginFields: some View {
                if fields.kind == .stalker {
                    OnboardingForm.Stacked(label: "MAC address") {
                        TextField("", text: $fields.mac)
                            .focused($focus, equals: .login)
                            .accessibilityIdentifier("onboarding.field.mac")
                    }
                    HStack(spacing: 14) {
                        OnboardingForm.Stacked(label: "Login", optional: true) {
                            TextField("", text: $fields.username).accessibilityIdentifier("onboarding.field.username")
                        }
                        OnboardingForm.Stacked(label: "Password", optional: true) {
                            SecureField("", text: $fields.password).accessibilityIdentifier("onboarding.field.password")
                        }
                    }
                } else {
                    HStack(spacing: 14) {
                        OnboardingForm.Stacked(label: "Username") {
                            TextField("", text: $fields.username)
                                .focused($focus, equals: .login)
                                .accessibilityIdentifier("onboarding.field.username")
                        }
                        OnboardingForm.Stacked(label: "Password") {
                            SecureField("", text: $fields.password).accessibilityIdentifier("onboarding.field.password")
                        }
                    }
                }
            }
        }

        /// A value that came from the iPhone: shown, not focusable.
        private struct Locked: View {
            let label: String
            let value: String
            let identifier: String

            var body: some View {
                OnboardingForm.Stacked(label: label) {
                    Text(value)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                        .background(Palette.surface(0.05), in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityValue(value)
                        .accessibilityIdentifier(identifier)
                }
            }
        }
    }

    private let previewLink = SetupLink(token: PairingToken("AAAAAAAAAAAAAAAAAAAAAA") ?? PairingToken()).url

    #Preview("Sign in after an Xtream source arrived", traits: .fixedLayout(width: 1920, height: 1080)) {
        @Previewable @State var fields = SourceFields(kind: .xtream, name: "Home provider", url: "http://tv.example-provider.net:8080")
        SetupSignIn.Television(fields: $fields, link: previewLink, status: .init(), connect: {})
    }

    #Preview("Sign in after a Stalker portal arrived", traits: .fixedLayout(width: 1920, height: 1080)) {
        @Previewable @State var fields = SourceFields(kind: .stalker, name: "Portal", url: "http://portal.example-provider.net/c/")
        SetupSignIn.Television(fields: $fields, link: previewLink, status: .init(), connect: {})
    }
#endif
