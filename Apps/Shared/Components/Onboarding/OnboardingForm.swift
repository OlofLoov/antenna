import AntennaCore
import SwiftUI

/// The add-source form (`iPhone-Onboard-2`, `iPhone-Onboard-2-M3U`,
/// `iPhone-Onboard-2-Connecting`, `iPhone-Onboard-2-NoLink`, `TV-Onboard-3`,
/// `TV-Onboard-3-M3U`, `TV-Onboard-3-Connecting`). Takes the fields as a
/// binding and reports Connect, Fill in and the type through closures.
enum OnboardingForm {
    /// What the form's buttons do.
    struct Actions {
        var choose: (SourceKind) -> Void
        var connect: () -> Void
        var fillIn: () -> Void
    }

    /// The values the form shows besides the fields.
    struct Status: Equatable {
        var error: String?
        var connecting = false
        var clipboard = ClipboardOffer.hidden
    }

    /// What the clipboard banner says.
    enum ClipboardOffer: Equatable {
        case hidden
        /// "A link is on the clipboard" with Fill in.
        case link
        /// "No link on the clipboard", after Fill in found none.
        case noLink
    }

    static let errorColor = Color(red: 0xFF / 255, green: 0x5F / 255, blue: 0x57 / 255)

    /// iPhone, and the sheet on iPad and Mac: the type picker, the clipboard
    /// banner, the grouped fields and Connect pinned at the bottom, so it
    /// stays reachable at the largest text size.
    struct Phone: View {
        @Binding var fields: SourceFields
        @Binding var revealsPassword: Bool
        let status: Status
        let actions: Actions

        var body: some View {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        KindPicker(kind: fields.kind, choose: actions.choose)
                        Text("Stalker portals are coming later")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textMuted)
                            .padding(.horizontal, 4)
                            .padding(.top, -14)
                        if status.clipboard != .hidden {
                            ClipboardBanner(offer: status.clipboard, fillIn: actions.fillIn)
                        }
                        fieldGroup
                        if let error = status.error {
                            Text(error)
                                .font(.system(size: 15))
                                .foregroundStyle(OnboardingForm.errorColor)
                                .padding(.horizontal, 4)
                                .accessibilityIdentifier("onboarding.error")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .scrollBounceBehavior(.basedOnSize)
                Button(action: actions.connect) {
                    HStack(spacing: 10) {
                        if status.connecting { ProgressView().tint(Palette.ground) }
                        Text(status.connecting ? "Connecting…" : "Connect")
                    }
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(Palette.ground)
                    .background(Palette.text.opacity(status.connecting ? 0.6 : 1), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(status.connecting)
                .accessibilityIdentifier("onboarding.connect")
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .foregroundStyle(Palette.text)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
        }

        @ViewBuilder private var fieldGroup: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(fields.kind == .m3u ? "Playlist" : "Login")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.textMuted)
                    .padding(.horizontal, 4)
                VStack(spacing: 0) {
                    Row(label: "Name") {
                        TextField("Optional", text: $fields.name)
                            .accessibilityIdentifier("onboarding.field.name")
                    }
                    if fields.kind == .m3u {
                        Row(label: "Playlist") {
                            LinkField(placeholder: "https://", text: $fields.url, identifier: "onboarding.field.playlist")
                        }
                        Row(label: "Guide", last: true) {
                            LinkField(placeholder: "Optional XMLTV link", text: $fields.epgURL, identifier: "onboarding.field.guide")
                        }
                    } else {
                        Row(label: "Server") {
                            LinkField(placeholder: "http://", text: $fields.url, identifier: "onboarding.field.server")
                        }
                        Row(label: "Username") {
                            TextField("", text: $fields.username)
                                .plainEntry()
                                .accessibilityIdentifier("onboarding.field.username")
                        }
                        Row(label: "Password", last: true) {
                            PasswordField(text: $fields.password, reveals: $revealsPassword, revealSize: 44)
                        }
                    }
                }
                .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 12))
                if fields.kind != .m3u {
                    Label("Saved in your iCloud Keychain only. Antenna has no servers and never sees your login.", systemImage: "lock")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textMuted)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    /// Apple TV: the title, the stacked fields, Connect with the Keychain
    /// line, and the card about typing on iPhone beside them.
    struct Television: View {
        @Binding var fields: SourceFields
        let status: Status
        let actions: Actions

        var body: some View {
            HStack(alignment: .center, spacing: 80) {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(fields.kind == .m3u ? "M3U playlist" : "Xtream login")
                            .font(.system(size: 52, weight: .heavy))
                            .accessibilityAddTraits(.isHeader)
                        Text(
                            fields.kind == .m3u
                                ? "Paste the link your provider gave you. The guide link is optional."
                                : "Copy these from the email or page your provider sent you."
                        )
                        .font(.system(size: 24))
                        .foregroundStyle(Palette.textMuted)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        Stacked(label: "Name", optional: true) {
                            TextField("", text: $fields.name).accessibilityIdentifier("onboarding.field.name")
                        }
                        if fields.kind == .m3u {
                            Stacked(label: "Playlist URL") {
                                TextField("", text: $fields.url).accessibilityIdentifier("onboarding.field.playlist")
                            }
                            Stacked(label: "Guide URL", optional: true) {
                                TextField("", text: $fields.epgURL).accessibilityIdentifier("onboarding.field.guide")
                            }
                        } else {
                            Stacked(label: "Server") {
                                TextField("", text: $fields.url).accessibilityIdentifier("onboarding.field.server")
                            }
                            HStack(spacing: 14) {
                                Stacked(label: "Username") {
                                    TextField("", text: $fields.username).accessibilityIdentifier("onboarding.field.username")
                                }
                                Stacked(label: "Password") {
                                    SecureField("", text: $fields.password).accessibilityIdentifier("onboarding.field.password")
                                }
                            }
                        }
                    }
                    if let error = status.error {
                        Text(error)
                            .font(.system(size: 22))
                            .foregroundStyle(OnboardingForm.errorColor)
                            .accessibilityIdentifier("onboarding.error")
                    }
                    HStack(spacing: 16) {
                        Button(status.connecting ? "Connecting…" : "Connect", action: actions.connect)
                            .buttonStyle(OnboardingStyle.PrimaryTV())
                            .disabled(status.connecting)
                            .accessibilityIdentifier("onboarding.connect")
                        if status.connecting { ProgressView() }
                        if fields.kind != .m3u {
                            Label("Saved in the Keychain on this Apple TV. Antenna has no servers.", systemImage: "lock")
                                .font(.system(size: 20))
                                .foregroundStyle(Palette.textMuted)
                        }
                    }
                    .padding(.top, 6)
                }
                .frame(width: 820)
                TypeOnPhoneCard()
            }
            .foregroundStyle(Palette.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
        }
    }
}

#Preview("Form, iPhone, Xtream with a link copied") {
    @Previewable @State var fields = SourceFields(
        kind: .xtream, name: "Home provider", url: "http://tv.example-provider.net:8080", username: "user4821", password: "pass1234")
    @Previewable @State var reveals = false
    OnboardingForm.Phone(
        fields: $fields, revealsPassword: $reveals, status: .init(clipboard: .link),
        actions: .init(choose: { _ in }, connect: {}, fillIn: {}))
}

#Preview("Form, iPhone, M3U with an error") {
    @Previewable @State var fields = SourceFields(kind: .m3u, url: "http://tv.example-provider.net/get.m3u")
    @Previewable @State var reveals = false
    OnboardingForm.Phone(
        fields: $fields, revealsPassword: $reveals,
        status: .init(error: "Could not reach tv.example-provider.net. Check the address and try again."),
        actions: .init(choose: { _ in }, connect: {}, fillIn: {}))
}

#Preview("Form, iPhone, connecting") {
    @Previewable @State var fields = SourceFields(kind: .xtream, url: "http://tv.example-provider.net:8080", username: "u", password: "p")
    @Previewable @State var reveals = false
    OnboardingForm.Phone(
        fields: $fields, revealsPassword: $reveals, status: .init(connecting: true, clipboard: .noLink),
        actions: .init(choose: { _ in }, connect: {}, fillIn: {}))
}

#Preview("Form, Apple TV, Xtream", traits: .fixedLayout(width: 1920, height: 1080)) {
    @Previewable @State var fields = SourceFields(kind: .xtream, name: "Home provider", url: "http://tv.example-provider.net:8080")
    OnboardingForm.Television(fields: $fields, status: .init(), actions: .init(choose: { _ in }, connect: {}, fillIn: {}))
}

#Preview("Form, Apple TV, M3U with an error", traits: .fixedLayout(width: 1920, height: 1080)) {
    @Previewable @State var fields = SourceFields(kind: .m3u, url: "http://tv.example-provider.net/get.m3u")
    OnboardingForm.Television(
        fields: $fields, status: .init(error: "Could not reach tv.example-provider.net. Check the address and try again."),
        actions: .init(choose: { _ in }, connect: {}, fillIn: {}))
}
