import AntennaCore
import SwiftUI

/// "Sign in on this Apple TV" (`TV-Onboard-SignIn`): a source that synced
/// without its login, the server filled in, empty username and password,
/// and the sources still to sign in after this one.
enum OnboardingSignIn {
    struct Television: View {
        let server: String
        @Binding var username: String
        @Binding var password: String
        /// "1 more source to sign in after this one: Holiday flat"; nil for the last.
        let remaining: String?
        let status: OnboardingForm.Status
        let connect: () -> Void

        /// The muted line naming the sources still to sign in, in order.
        static func remaining(_ names: [String]) -> String? {
            guard !names.isEmpty else { return nil }
            let count = names.count == 1 ? "1 more source" : "\(names.count) more sources"
            return "\(count) to sign in after this one: \(names.joined(separator: ", "))"
        }

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
                        OnboardingForm.Stacked(label: "Server") {
                            Text(server)
                                .padding(.horizontal, 24)
                                .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                                .background(Palette.surface(0.05), in: RoundedRectangle(cornerRadius: 14))
                                .accessibilityIdentifier("onboarding.signIn.server")
                        }
                        HStack(spacing: 14) {
                            OnboardingForm.Stacked(label: "Username") {
                                TextField("", text: $username).accessibilityIdentifier("onboarding.field.username")
                            }
                            OnboardingForm.Stacked(label: "Password") {
                                SecureField("", text: $password).accessibilityIdentifier("onboarding.field.password")
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
                OnboardingForm.TypeOnPhoneCard()
            }
            .foregroundStyle(Palette.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.signIn")
        }
    }
}

#Preview("Sign in on this Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
    @Previewable @State var username = ""
    @Previewable @State var password = ""
    OnboardingSignIn.Television(
        server: "http://tv.example-provider.net:8080", username: $username, password: $password,
        remaining: OnboardingSignIn.Television.remaining(["Holiday flat"]), status: .init(), connect: {})
}
