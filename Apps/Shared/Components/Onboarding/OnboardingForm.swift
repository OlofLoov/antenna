import AntennaCore
import SwiftUI

/// The add-source form (`iPhone-Onboard-2` and its `-M3U`, `-Connecting`,
/// `-NoLink`, `-XtreamLink` and `-Error` states, `iPad-Onboard-2`,
/// `TV-Onboard-3` and its `-M3U`, `-Connecting`, `-XtreamLink` and `-Error`
/// states). Both variants are system forms with the same rows, the way
/// source details shows them (design-system/forms-use-the-platform-form-style).
/// Takes the fields as a binding and reports Connect, Cancel, Fill in and
/// the type through closures.
enum OnboardingForm {
    /// What the form's buttons do.
    struct Actions {
        var choose: (SourceKind) -> Void
        var connect: () -> Void
        var fillIn: () -> Void
        /// "Import a file instead" under the playlist link; nil hides it.
        var importFile: (() -> Void)?
        /// Use Xtream on the offer under a panel link.
        var useXtream: () -> Void = {}
        /// Cancel, which closes the form; nil leaves it out.
        var cancel: (() -> Void)?
        /// The Type row on Apple TV, which goes back to the kinds; nil leaves the row out.
        var changeKind: (() -> Void)?
    }

    /// The values the form shows besides the fields.
    struct Status: Equatable {
        var error: String?
        var connecting = false
        var clipboard = ClipboardOffer.hidden
        /// The playlist link is an Xtream login, so the offer shows
        /// (source-management/the-add-form-offers-xtream-for-a-panel-link).
        var xtreamLink = false
    }

    /// What the clipboard row says.
    enum ClipboardOffer: Equatable {
        case hidden
        /// "Fill in from the copied link".
        case link
        /// "No link on the clipboard", after Fill in found none.
        case noLink
    }

    static let errorColor = Color(red: 0xFF / 255, green: 0x5F / 255, blue: 0x57 / 255)

    /// The kinds the Type picker offers, in the order of the Apple TV cards.
    static let kinds: [SourceKind] = [.m3u, .xtream, .stalker, .jellyfin, .channelsDVR]

    /// The kind's name, as the picker and the Apple TV title show it.
    static func title(_ kind: SourceKind) -> String {
        switch kind {
        case .m3u, .m3uFile: "M3U playlist"
        case .xtream: "Xtream login"
        case .stalker: "Stalker portal"
        case .jellyfin: "Jellyfin server"
        case .channelsDVR: "Channels DVR"
        }
    }

    /// Where a login is kept, under the login rows.
    static func keychainLine(_ kind: SourceKind) -> String? {
        guard [.xtream, .stalker, .jellyfin].contains(kind) else { return nil }
        #if os(tvOS)
            return "Saved in the Keychain on this Apple TV. Antenna has no servers."
        #else
            return "Saved in your iCloud Keychain only. Antenna has no servers and never sees your login."
        #endif
    }

    /// iPhone, and the sheet on iPad and Mac (`iPhone-Onboard-2`): a grouped
    /// form with Type as a menu, the field rows, the offers as button rows,
    /// and Cancel and Connect in the toolbar. It scrolls, so every row stays
    /// reachable at the largest text size.
    struct Phone<Header: View>: View {
        @Binding var fields: SourceFields
        @Binding var revealsPassword: Bool
        let status: Status
        let actions: Actions
        /// Above the type: the "Opened from your Apple TV" banner, or nothing.
        @ViewBuilder var header: Header

        var body: some View {
            Form {
                header
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                Section {
                    Picker("Type", selection: kind) {
                        ForEach(OnboardingForm.kinds, id: \.self) { kind in
                            Text(OnboardingForm.title(kind)).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("onboarding.kind")
                }
                Section {
                    Rows(fields: $fields, reveals: $revealsPassword)
                } header: {
                    Text(groupTitle)
                } footer: {
                    Footer(line: OnboardingForm.keychainLine(fields.kind), error: status.error)
                }
                .disabled(status.connecting)
                if status.xtreamLink {
                    XtreamLinkOffer.Phone(useXtream: actions.useXtream)
                }
                if fields.kind == .m3u, let importFile = actions.importFile {
                    Section {
                        Button("Import a file instead", action: importFile)
                            .accessibilityIdentifier("import.pickFile")
                    }
                }
                if status.clipboard != .hidden {
                    ClipboardRow(offer: status.clipboard, fillIn: actions.fillIn)
                }
            }
            .formStyle(.grouped)
            .toolbar {
                if let cancel = actions.cancel {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: cancel)
                            .accessibilityIdentifier("onboarding.back")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: actions.connect) {
                        if status.connecting {
                            ProgressView()
                                .accessibilityLabel("Connecting")
                        } else {
                            Text("Connect")
                        }
                    }
                    .primaryActionStyle()
                    .disabled(status.connecting)
                    .accessibilityIdentifier("onboarding.connect")
                }
            }
        }

        private var kind: Binding<SourceKind> {
            Binding(get: { fields.kind == .m3uFile ? .m3u : fields.kind }, set: { actions.choose($0) })
        }

        private var groupTitle: String {
            switch fields.kind {
            case .m3u, .m3uFile: "Playlist"
            case .xtream: "Login"
            case .stalker: "Portal"
            case .jellyfin, .channelsDVR: "Server"
            }
        }
    }

    /// Apple TV (`TV-Onboard-3`): the title and line with `side` under them,
    /// the card about typing on iPhone or the QR card
    /// (iphone-as-setup-device capability), and the Type row, the field
    /// rows, the footer, Connect and Cancel beside them.
    struct Television<Side: View>: View {
        @Binding var fields: SourceFields
        let status: Status
        let actions: Actions
        @ViewBuilder var side: Side

        var body: some View {
            FormPage.Television(
                title: OnboardingForm.title(fields.kind), line: line, footer: OnboardingForm.keychainLine(fields.kind),
                error: status.error
            ) {
                side
            } rows: {
                if let changeKind = actions.changeKind {
                    Section {
                        FieldRow.Choice(
                            label: "Type", value: OnboardingForm.title(fields.kind), identifier: "onboarding.kind", action: changeKind)
                    }
                }
                Section {
                    Rows(fields: $fields, reveals: nil)
                }
                .disabled(status.connecting)
                if status.xtreamLink {
                    XtreamLinkOffer.Television(useXtream: actions.useXtream)
                }
            } buttons: {
                Buttons(connecting: status.connecting, connect: actions.connect, cancel: actions.cancel)
            }
        }

        private var line: String {
            switch fields.kind {
            case .m3u, .m3uFile: "Paste the link your provider gave you. The guide link is optional."
            case .xtream: "Copy these from the email or page your provider sent you."
            case .stalker:
                "Copy these from the email or page your provider sent you. Leave the login empty unless your provider gave you one."
            case .jellyfin: "The address you open Jellyfin at in a browser, with the username and password you sign in with."
            case .channelsDVR: "Type the address your Channels DVR server shows, such as 192.168.1.20 or nas.local."
            }
        }
    }

    /// Connect and Cancel on Apple TV, lined up under the fields with
    /// Connect filling the width the fields leave, so focus moving down
    /// from a field lands on Connect. While connecting, Connect shows a
    /// progress view and cannot be pressed.
    struct Buttons: View {
        let connecting: Bool
        let connect: () -> Void
        var cancel: (() -> Void)?

        var body: some View {
            HStack(spacing: Metrics.Spacing.large) {
                Button(action: connect) {
                    HStack(spacing: Metrics.Spacing.small) {
                        if connecting { ProgressView() }
                        Text(connecting ? "Connecting…" : "Connect")
                    }
                    .frame(maxWidth: .infinity)
                }
                .primaryActionStyle()
                .disabled(connecting)
                .accessibilityIdentifier("onboarding.connect")
                if let cancel {
                    Button("Cancel", action: cancel)
                        .buttonStyle(.glass)
                        .accessibilityIdentifier("onboarding.back")
                }
            }
        }
    }

    /// The field rows for the kind: name, then the link, server or portal,
    /// then the login. `reveals` adds the eye button to the password.
    struct Rows: View {
        @Binding var fields: SourceFields
        let reveals: Binding<Bool>?

        var body: some View {
            FieldRow.Text(label: "Name", text: $fields.name, prompt: "Optional", identifier: "onboarding.field.name")
            switch fields.kind {
            case .m3u, .m3uFile:
                FieldRow.Text(
                    label: "Playlist", text: $fields.url, prompt: "https://", entry: .link, identifier: "onboarding.field.playlist")
                FieldRow.Text(
                    label: "Guide", text: $fields.epgURL, prompt: "Optional XMLTV link", entry: .link,
                    identifier: "onboarding.field.guide")
            case .stalker:
                FieldRow.Text(label: "Portal", text: $fields.url, prompt: "http://", entry: .link, identifier: "onboarding.field.portal")
                PortalLogin(fields: $fields, reveals: reveals)
            case .channelsDVR:
                FieldRow.Text(
                    label: "Server", text: $fields.url, prompt: "192.168.1.20 or nas.local", entry: .link,
                    identifier: "onboarding.field.server")
            case .xtream, .jellyfin:
                FieldRow.Text(
                    label: "Server", text: $fields.url, prompt: fields.kind == .jellyfin ? "http://jellyfin.local:8096" : "http://",
                    entry: .link, identifier: "onboarding.field.server")
                Login(fields: $fields, reveals: reveals)
            }
        }
    }

    /// The username and password rows, both required.
    struct Login: View {
        @Binding var fields: SourceFields
        let reveals: Binding<Bool>?

        var body: some View {
            FieldRow.Text(
                label: "Username", text: $fields.username, prompt: "Required", entry: .plain, identifier: "onboarding.field.username")
            FieldRow.Secret(label: "Password", text: $fields.password, prompt: "Required", reveals: reveals)
        }
    }

    /// A portal's MAC address with the optional login and password, shared
    /// by the form and the Apple TV sign-in.
    struct PortalLogin: View {
        @Binding var fields: SourceFields
        let reveals: Binding<Bool>?

        var body: some View {
            FieldRow.Text(
                label: "MAC address", text: $fields.mac, prompt: "00:1A:79:12:34:56", entry: .plain,
                identifier: "onboarding.field.mac")
            FieldRow.Text(
                label: "Login", text: $fields.username, prompt: "Optional", entry: .plain, identifier: "onboarding.field.username")
            FieldRow.Secret(label: "Password", text: $fields.password, prompt: "Optional", reveals: reveals)
        }
    }

    /// The section footer: where the login is kept, then the error in the live-dot red.
    struct Footer: View {
        let line: String?
        let error: String?

        var body: some View {
            if line != nil || error != nil {
                VStack(alignment: .leading, spacing: Metrics.Spacing.xSmall) {
                    if let line {
                        Text(line)
                    }
                    if let error {
                        Text(error)
                            .foregroundStyle(OnboardingForm.errorColor)
                            .accessibilityIdentifier("onboarding.error")
                    }
                }
            }
        }
    }
}

#Preview("Form, iPhone, Xtream with a link copied") {
    @Previewable @State var fields = SourceFields(
        kind: .xtream, name: "Home provider", url: "http://tv.example-provider.net:8080", username: "user4821", password: "pass1234")
    @Previewable @State var reveals = false
    NavigationStack {
        OnboardingForm.Phone(
            fields: $fields, revealsPassword: $reveals, status: .init(clipboard: .link),
            actions: .init(choose: { _ in }, connect: {}, fillIn: {}, cancel: {})
        )
        .navigationTitle("Add a source")
    }
}

#Preview("Form, iPhone, M3U with an Xtream link") {
    @Previewable @State var fields = SourceFields(
        kind: .m3u, name: "Home provider",
        url: "http://tv.example-provider.net:8080/get.php?username=user4821&password=pass1234&type=m3u_plus")
    @Previewable @State var reveals = false
    NavigationStack {
        OnboardingForm.Phone(
            fields: $fields, revealsPassword: $reveals, status: .init(xtreamLink: true),
            actions: .init(choose: { _ in }, connect: {}, fillIn: {}, importFile: {}, cancel: {})
        )
        .navigationTitle("Add a source")
    }
}

#Preview("Form, iPhone, Channels DVR with an error") {
    @Previewable @State var fields = SourceFields(kind: .channelsDVR, url: "192.168.1.20")
    @Previewable @State var reveals = false
    NavigationStack {
        OnboardingForm.Phone(
            fields: $fields, revealsPassword: $reveals,
            status: .init(
                error: "Could not reach 192.168.1.20. Check the address and try again. "
                    + "Allow local network access for Antenna in Settings."),
            actions: .init(choose: { _ in }, connect: {}, fillIn: {}, cancel: {})
        )
        .navigationTitle("Add a source")
    }
}

#Preview("Form, iPhone, connecting") {
    @Previewable @State var fields = SourceFields(kind: .xtream, url: "http://tv.example-provider.net:8080", username: "u", password: "p")
    @Previewable @State var reveals = false
    NavigationStack {
        OnboardingForm.Phone(
            fields: $fields, revealsPassword: $reveals, status: .init(connecting: true, clipboard: .noLink),
            actions: .init(choose: { _ in }, connect: {}, fillIn: {}, cancel: {})
        )
        .navigationTitle("Add a source")
    }
}

#Preview("Form, iPhone, Stalker portal") {
    @Previewable @State var fields = SourceFields(kind: .stalker, url: "http://portal.example-provider.net/c/", mac: "00:1A:79:12:34:56")
    @Previewable @State var reveals = false
    NavigationStack {
        OnboardingForm.Phone(
            fields: $fields, revealsPassword: $reveals, status: .init(),
            actions: .init(choose: { _ in }, connect: {}, fillIn: {}, cancel: {})
        )
        .navigationTitle("Add a source")
    }
}

#Preview("Form, Apple TV, Stalker portal", traits: .fixedLayout(width: 1920, height: 1080)) {
    @Previewable @State var fields = SourceFields(kind: .stalker, url: "http://portal.example-provider.net/c/", mac: "00:1A:79:12:34:56")
    OnboardingForm.Television(
        fields: $fields, status: .init(error: "Could not sign in. Check the MAC address, and the login if you have one."),
        actions: .init(choose: { _ in }, connect: {}, fillIn: {}, cancel: {}, changeKind: {}))
}

#Preview("Form, Apple TV, Xtream", traits: .fixedLayout(width: 1920, height: 1080)) {
    @Previewable @State var fields = SourceFields(kind: .xtream, name: "Home provider", url: "http://tv.example-provider.net:8080")
    OnboardingForm.Television(
        fields: $fields, status: .init(), actions: .init(choose: { _ in }, connect: {}, fillIn: {}, cancel: {}, changeKind: {}))
}

#Preview("Form, Apple TV, connecting", traits: .fixedLayout(width: 1920, height: 1080)) {
    @Previewable @State var fields = SourceFields(
        kind: .xtream, name: "Home provider", url: "http://tv.example-provider.net:8080", username: "user4821", password: "pass1234")
    OnboardingForm.Television(
        fields: $fields, status: .init(connecting: true),
        actions: .init(choose: { _ in }, connect: {}, fillIn: {}, cancel: {}, changeKind: {}))
}

#Preview("Form, Apple TV, M3U with an error", traits: .fixedLayout(width: 1920, height: 1080)) {
    @Previewable @State var fields = SourceFields(kind: .m3u, url: "http://tv.example-provider.net/get.m3u")
    OnboardingForm.Television(
        fields: $fields, status: .init(error: "Could not reach tv.example-provider.net. Check the address and try again."),
        actions: .init(choose: { _ in }, connect: {}, fillIn: {}, cancel: {}, changeKind: {}))
}

#Preview("Form, Apple TV, M3U with an Xtream link", traits: .fixedLayout(width: 1920, height: 1080)) {
    @Previewable @State var fields = SourceFields(
        kind: .m3u, url: "http://tv.example-provider.net:8080/get.php?username=user4821&password=pass1234&type=m3u_plus")
    OnboardingForm.Television(
        fields: $fields, status: .init(xtreamLink: true),
        actions: .init(choose: { _ in }, connect: {}, fillIn: {}, cancel: {}, changeKind: {}))
}

#Preview("Form, iPhone, Jellyfin server") {
    @Previewable @State var fields = SourceFields(kind: .jellyfin, url: "http://jellyfin.local:8096", username: "anna")
    @Previewable @State var reveals = false
    NavigationStack {
        OnboardingForm.Phone(
            fields: $fields, revealsPassword: $reveals, status: .init(),
            actions: .init(choose: { _ in }, connect: {}, fillIn: {}, cancel: {})
        )
        .navigationTitle("Add a source")
    }
}

#Preview("Form, Apple TV, Jellyfin server", traits: .fixedLayout(width: 1920, height: 1080)) {
    @Previewable @State var fields = SourceFields(kind: .jellyfin, url: "https://jellyfin.example.net", username: "anna")
    OnboardingForm.Television(
        fields: $fields,
        status: .init(error: "Antenna can't verify this server's certificate. Use http on your network or a trusted certificate."),
        actions: .init(choose: { _ in }, connect: {}, fillIn: {}, cancel: {}, changeKind: {}))
}

extension OnboardingForm.Television where Side == OnboardingForm.TypeOnPhoneCard {
    init(fields: Binding<SourceFields>, status: OnboardingForm.Status, actions: OnboardingForm.Actions) {
        self.init(fields: fields, status: status, actions: actions) { OnboardingForm.TypeOnPhoneCard() }
    }
}

extension OnboardingForm.Phone where Header == EmptyView {
    init(fields: Binding<SourceFields>, revealsPassword: Binding<Bool>, status: OnboardingForm.Status, actions: OnboardingForm.Actions) {
        self.init(fields: fields, revealsPassword: revealsPassword, status: status, actions: actions) { EmptyView() }
    }
}
