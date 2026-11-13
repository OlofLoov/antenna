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
            FormPage.Television(
                title: "Sign in on this Apple TV", line: "This source arrived through iCloud without its login. Enter it once here.",
                footer: OnboardingForm.keychainLine(fields.kind), error: status.error
            ) {
                card
            } rows: {
                Section {
                    FieldRow.Value(
                        label: fields.kind == .stalker ? "Portal" : "Server", value: fields.url, identifier: "onboarding.signIn.server")
                    if fields.kind == .stalker {
                        OnboardingForm.PortalLogin(fields: $fields, reveals: nil)
                    } else {
                        OnboardingForm.Login(fields: $fields, reveals: nil)
                    }
                } footer: {
                    if let remaining {
                        Text(remaining)
                            .font(.caption)
                            .accessibilityIdentifier("onboarding.signIn.remaining")
                    }
                }
                .disabled(status.connecting)
            } buttons: {
                OnboardingForm.Buttons(connecting: status.connecting, connect: connect)
            }
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
