import AntennaCore
import SwiftUI

/// "Sign in on this Apple TV" (`TV-Onboard-SignIn`): a source that synced
/// without its login, the server or portal filled in, empty login fields,
/// and the sources still to sign in after this one. A portal asks for its
/// MAC address, with the login and password optional. The card beside the
/// fields is the QR card (`TV-Onboard-SignIn-QR`) or the keyboard card.
enum OnboardingSignIn {
    /// The muted line naming the sources still to sign in, in order.
    static func remaining(_ names: [String]) -> String? {
        guard !names.isEmpty else { return nil }
        let count = names.count == 1 ? "1 more source" : "\(names.count) more sources"
        return "\(count) to sign in after this one: \(names.joined(separator: ", "))"
    }

    struct Television<Card: View>: View {
        /// The source's kind and address, and what the user types.
        @Binding var fields: SourceFields
        /// "1 more source to sign in after this one: Holiday flat"; nil for the last.
        let remaining: String?
        let status: OnboardingForm.Status
        let connect: () -> Void
        @ViewBuilder var card: Card

        var body: some View {
            HStack(alignment: .center, spacing: 80) {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sign in on this Apple TV")
                            .font(.system(size: 52, weight: .heavy))
                            .accessibilityAddTraits(.isHeader)
                        Text("This source arrived through iCloud without its login. Enter it once here.")
                            .font(.system(size: 24))
                            .foregroundStyle(Palette.textMuted)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        OnboardingForm.Stacked(label: fields.kind == .stalker ? "Portal" : "Server") {
                            Text(fields.url)
                                .padding(.horizontal, 24)
                                .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                                .background(Palette.surface(0.05), in: RoundedRectangle(cornerRadius: 14))
                                .accessibilityIdentifier("onboarding.signIn.server")
                        }
                        if fields.kind == .stalker {
                            OnboardingForm.PortalLoginFields(fields: $fields)
                        } else {
                            HStack(spacing: 14) {
                                OnboardingForm.Stacked(label: "Username") {
                                    TextField("", text: $fields.username).accessibilityIdentifier("onboarding.field.username")
                                }
                                OnboardingForm.Stacked(label: "Password") {
                                    SecureField("", text: $fields.password).accessibilityIdentifier("onboarding.field.password")
                                }
                            }
                        }
                        if let remaining {
                            Text(remaining)
                                .font(.system(size: 22))
                                .foregroundStyle(Palette.textMuted)
                                .accessibilityIdentifier("onboarding.signIn.remaining")
                        }
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
                        Label("Saved in the Keychain on this Apple TV. Antenna has no servers.", systemImage: "lock")
                            .font(.system(size: 20))
                            .foregroundStyle(Palette.textMuted)
                    }
                    .padding(.top, 6)
                }
                .frame(width: 820)
                card
            }
            .foregroundStyle(Palette.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.signIn")
        }
    }
}

extension OnboardingSignIn.Television where Card == OnboardingForm.TypeOnPhoneCard {
    init(fields: Binding<SourceFields>, remaining: String?, status: OnboardingForm.Status, connect: @escaping () -> Void) {
        self.init(fields: fields, remaining: remaining, status: status, connect: connect) { OnboardingForm.TypeOnPhoneCard() }
    }
}

#Preview("Sign in on this Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
    @Previewable @State var fields = SourceFields(kind: .xtream, url: "http://tv.example-provider.net:8080")
    OnboardingSignIn.Television(
        fields: $fields, remaining: OnboardingSignIn.remaining(["Holiday flat"]), status: .init(), connect: {})
}

#Preview("Sign in on this Apple TV, Stalker portal", traits: .fixedLayout(width: 1920, height: 1080)) {
    @Previewable @State var fields = SourceFields(kind: .stalker, url: "http://portal.example-provider.net")
    OnboardingSignIn.Television(fields: $fields, remaining: nil, status: .init(), connect: {})
}

#Preview("Sign in on this Apple TV, Jellyfin server", traits: .fixedLayout(width: 1920, height: 1080)) {
    @Previewable @State var fields = SourceFields(kind: .jellyfin, url: "http://jellyfin.local:8096")
    OnboardingSignIn.Television(fields: $fields, remaining: nil, status: .init(), connect: {})
}
