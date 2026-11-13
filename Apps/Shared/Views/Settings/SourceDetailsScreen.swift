import AntennaCore
import SwiftData
import SwiftUI

/// A source's details (`iPhone-Settings-Detail`, `iPhone-Settings-Detail-XtreamLink`, `iPad-Settings`,
/// `TV-Settings-Details`): what it holds, its editable name, link, guide link and
/// login, Refresh now, Move up and Move down on Apple TV, and Delete source.
/// On Apple TV the settings split page: the name, type, status and QR card
/// on the left, the field rows and Save on the right.
/// Closes when another device deletes the source
/// (sources-and-settings/fix-a-source-s-link-or-login).
struct SourceDetailsScreen: View {
    let id: UUID
    let signedInToICloud: Bool
    /// Deletes the source once the user confirms.
    let delete: (SourceRecord) -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sourceRefresher) private var refresher
    @Query(sort: SourceRecord.displayOrder) private var sources: [SourceRecord]
    @State private var editor: SourceEditor?
    @State private var deleting: SourceRecord?
    #if !os(tvOS)
        @State private var reimport: FileImportAsk?
    #endif

    private var record: SourceRecord? { sources.first { $0.id == id } }

    var body: some View {
        Group {
            if let record {
                #if os(tvOS)
                    SettingsPage.Split {
                        TimelineView(.periodic(from: .now, by: 60)) { timeline in
                            SettingsPage.SourceLead(name: record.name, kind: record.kind, lines: statusLines(record, now: timeline.date)) {
                                loginCard(record)
                            }
                        }
                    } content: {
                        form(record)
                    }
                #else
                    form(record)
                #endif
            } else {
                Color.clear
            }
        }
        #if !os(tvOS)
            .navigationTitle(record?.name ?? "")
        #endif
        .deleteSourceConfirmation($deleting, signedInToICloud: signedInToICloud, delete: delete)
        #if !os(tvOS)
            .modifier(SettingsFileImport(ask: $reimport))
        #endif
        .onChange(of: record == nil) { _, gone in
            if gone { dismiss() }
        }
        .task(id: record?.descriptor) {
            guard editor == nil || editor?.id != id, let descriptor = record?.descriptor else { return }
            editor = SourceEditor(descriptor, connector: .app)
        }
    }

    @ViewBuilder private func form(_ record: SourceRecord) -> some View {
        Form {
            #if !os(tvOS)
                statusSection(record)
            #endif
            if let editor, record.url != nil {
                SourceFieldsSection(editor: editor, switched: switched)
                #if os(tvOS)
                    // The primary action under the fields, as Connect is on the add-source page.
                    Section {
                        Button("Save") { save(editor) }
                            .buttonStyle(.glassProminent)
                            .disabled(editor.saving)
                            .accessibilityIdentifier("settings.details.save")
                    }
                    .listRowBackground(Color.clear)
                #endif
            }
            GuideRowSection(id: record.id)
            Section {
                if record.url != nil {
                    Button("Refresh now") { refresher?.refresh([record.id]) }
                        .accessibilityIdentifier("settings.details.refresh")
                }
                #if !os(tvOS)
                    if record.kind == .m3uFile {
                        // local-m3u-file-import/re-import-onto-the-same-source
                        Button("Re-import…") { reimport = FileImportAsk(replacing: .init(id: record.id, name: record.name)) }
                            .accessibilityIdentifier("import.reimport")
                    }
                #endif
                #if os(tvOS)
                    Button("Move up") { SourceOrder.move(record, by: -1, among: sources, in: context) }
                        .disabled(sources.first?.id == record.id)
                        .accessibilityIdentifier("settings.details.moveUp")
                    Button("Move down") { SourceOrder.move(record, by: 1, among: sources, in: context) }
                        .disabled(sources.last?.id == record.id)
                        .accessibilityIdentifier("settings.details.moveDown")
                #endif
                Button("Delete source", role: .destructive) { deleting = record }
                    .accessibilityIdentifier("settings.details.delete")
            }
        }
        #if !os(tvOS)
            .toolbar {
                if let editor, record.url != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save(editor) }
                        .disabled(editor.saving)
                        .accessibilityIdentifier("settings.details.save")
                    }
                }
            }
        #endif
    }

    /// What the source holds and when it last loaded, under its type.
    private func statusSection(_ record: SourceRecord) -> some View {
        Section {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                VStack(alignment: .leading, spacing: Metrics.Spacing.xxSmall) {
                    ForEach(Array(statusLines(record, now: timeline.date).enumerated()), id: \.offset) { _, line in
                        Text(line.text)
                            .foregroundStyle(line.style == .error ? AnyShapeStyle(OnboardingForm.errorColor) : AnyShapeStyle(.secondary))
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("settings.details.status")
            }
        } header: {
            Text(SourceRowLabel.badge(record.kind))
        }
    }

    #if os(tvOS)
        /// The QR card for a source whose login has not reached this Apple TV
        /// (apple-tv-login-from-iphone/the-apple-tv-sign-in-offers-a-qr-code).
        @ViewBuilder private func loginCard(_ record: SourceRecord) -> some View {
            if let editor, let source = record.descriptor, source.signsInOnAppleTV, source.kind != .channelsDVR, !editor.hasLogin {
                SourceLoginCard(source: source) {
                    self.editor = SourceEditor(source, connector: .app)
                }
                .id(source.id)
            }
        }
    #endif

    private func statusLines(_ record: SourceRecord, now: Date) -> [SourceStatusText.Line] {
        #if os(tvOS)
            let text = SourceStatusText(television: true)
        #else
            let text = SourceStatusText()
        #endif
        return SettingsView.fileLines(record)
            + text.detailLines(SettingsView.status(of: record, refresher: refresher), account: nil, now: now)
    }

    /// A playlist became an Xtream login: the form follows the new type and the source loads again.
    private func switched(_ descriptor: SourceDescriptor) {
        editor = SourceEditor(descriptor, connector: .app)
        refresher?.refresh([descriptor.id])
    }

    private func save(_ editor: SourceEditor) {
        Task {
            let checked = editor.needsCheck
            if await editor.save(in: context), checked { refresher?.refresh([editor.id]) }
        }
    }
}

/// One editable field: a field row on Apple TV that opens the system
/// keyboard, a text field elsewhere (design-system/forms-use-the-platform-form-style).
private struct SourceField: View {
    let label: String
    @Binding var text: String
    var prompt: String?
    var entry = FieldEntry.text

    var body: some View {
        #if os(tvOS)
            FieldRow(label: label, text: $text, prompt: prompt ?? "", entry: entry)
        #else
            switch entry {
            case .secure:
                SecureField(label, text: $text, prompt: prompt.map { Text($0) })
            case .text:
                TextField(label, text: $text, prompt: prompt.map { Text($0) })
            case .link, .login:
                TextField(label, text: $text, prompt: prompt.map { Text($0) })
                    .autocorrectionDisabled()
            }
        #endif
    }
}

/// The editable fields: Name, the link, the guide link for a playlist, the
/// login for Xtream, and the MAC address and optional login for a portal,
/// with the password field empty.
private struct SourceFieldsSection: View {
    @Bindable var editor: SourceEditor
    /// After Use Xtream worked, with the source as it is now.
    let switched: (SourceDescriptor) -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.sourceRefresher) private var refresher
    @Environment(\.loadedChannels) private var channels

    var body: some View {
        Section("Source") {
            SourceField(label: "Name", text: $editor.name)
                .accessibilityIdentifier("settings.details.name")
            SourceField(label: linkLabel, text: $editor.link, entry: .link)
                .accessibilityIdentifier("settings.details.link")
            if editor.kind == .m3u {
                SourceField(label: "Guide", text: $editor.guideLink, prompt: "Optional XMLTV link", entry: .link)
                    .accessibilityIdentifier("settings.details.guide")
            }
        }
        if editor.xtreamPanel != nil {
            // source-management/a-playlist-source-switches-to-xtream-in-place
            Section {
                Button(editor.saving ? "Checking…" : XtreamLinkOffer.button) {
                    Task {
                        if let descriptor = await editor.switchToXtream(channels: channels, in: context) { switched(descriptor) }
                    }
                }
                .disabled(editor.saving)
                .accessibilityIdentifier("settings.details.useXtream")
            } footer: {
                Text(XtreamLinkOffer.message)
                    .accessibilityIdentifier("settings.details.xtreamOffer")
            }
        }
        if editor.kind == .xtream || editor.kind == .stalker || editor.kind == .jellyfin {
            Section {
                #if os(tvOS)
                    if !editor.hasLogin {
                        // sources-and-settings/sign-in-on-this-apple-tv
                        Button("Sign in on this Apple TV") {
                            Task {
                                if await editor.save(in: context) { refresher?.refresh([editor.id]) }
                            }
                        }
                        .accessibilityIdentifier("settings.details.signIn")
                    }
                #endif
                if editor.kind == .stalker {
                    SourceField(label: "MAC address", text: $editor.mac, entry: .login)
                        .accessibilityIdentifier("settings.details.mac")
                    SourceField(label: "Login", text: $editor.username, prompt: "Optional", entry: .login)
                        .accessibilityIdentifier("settings.details.username")
                } else {
                    SourceField(label: "Username", text: $editor.username, entry: .login)
                        .accessibilityIdentifier("settings.details.username")
                }
                SourceField(label: "Password", text: $editor.password, prompt: passwordPrompt, entry: .secure)
                    .accessibilityIdentifier("settings.details.password")
            } header: {
                Text("Login")
            } footer: {
                #if os(tvOS)
                    Text("Saved in the Keychain on this Apple TV. Antenna has no servers.")
                #else
                    Text("Saved in your iCloud Keychain only. Antenna has no servers and never sees your login.")
                #endif
            }
        }
        if let error = editor.error {
            Text(error)
                .foregroundStyle(OnboardingForm.errorColor)
                .accessibilityIdentifier("settings.details.error")
        }
    }

    private var linkLabel: String {
        switch editor.kind {
        case .m3u, .m3uFile: "Playlist"
        case .xtream, .jellyfin, .channelsDVR: "Server"
        case .stalker: "Portal"
        }
    }

    /// The dots stand for a saved password; a portal without one shows that the field is optional.
    private var passwordPrompt: String {
        editor.kind == .stalker && !editor.hasPassword ? "Optional" : "••••••••"
    }
}

/// The Guide row: how many channels have no guide, and the Guide sources
/// screen behind it (guide-sources-and-channel-mapping capability).
private struct GuideRowSection: View {
    let id: UUID
    @Environment(\.guideStore) private var store

    var body: some View {
        Section {
            NavigationLink {
                GuideSourcesScreen(id: id)
            } label: {
                LabeledContent("Guide") {
                    if let count = GuideSourcesModel.missingCount(id, store: store) {
                        Text(count == 1 ? "1 channel without guide" : "\(count) channels without guide")
                    }
                }
            }
            .accessibilityIdentifier("settings.details.guide.sources")
        }
    }
}
