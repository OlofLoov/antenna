import AntennaCore
import SwiftData
import SwiftUI

/// A source's details (`iPhone-Settings-Detail`, `iPad-Settings`,
/// `TV-Settings`): what it holds, its editable name, link, guide link and
/// login, Refresh now, Move up and Move down on Apple TV, and Delete source.
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
                form(record)
            } else {
                Color.clear
            }
        }
        .navigationTitle(record?.name ?? "")
        .deleteSourceConfirmation($deleting, signedInToICloud: signedInToICloud, delete: delete)
        #if !os(tvOS)
            .modifier(SettingsFileImport(ask: $reimport))
        #endif
        .onChange(of: record == nil) { _, gone in
            if gone { dismiss() }
        }
        .task(id: record?.descriptor) {
            guard editor == nil || editor?.id != id, let descriptor = record?.descriptor else { return }
            editor = SourceEditor(descriptor, connector: SourceConnector())
        }
    }

    @ViewBuilder private func form(_ record: SourceRecord) -> some View {
        Form {
            Section {
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(statusLines(record, now: timeline.date).enumerated()), id: \.offset) { _, line in
                            Text(line.text)
                                .foregroundStyle(line.style == .error ? OnboardingForm.errorColor : Palette.textMuted)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("settings.details.status")
                }
            } header: {
                Text(SourceRowLabel.badge(record.kind))
            }
            if let editor, record.url != nil {
                SourceFieldsSection(editor: editor)
            }
            Section {
                if record.url != nil, record.kind != .stalker {
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
        .toolbar {
            if let editor, record.url != nil {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(editor) }
                        .disabled(editor.saving)
                        .accessibilityIdentifier("settings.details.save")
                }
            }
        }
    }

    private func statusLines(_ record: SourceRecord, now: Date) -> [SourceStatusText.Line] {
        #if os(tvOS)
            let text = SourceStatusText(television: true)
        #else
            let text = SourceStatusText()
        #endif
        var lines =
            SettingsView.fileLines(record) + text.detailLines(SettingsView.status(of: record, refresher: refresher), account: nil, now: now)
        #if os(tvOS)
            if record.kind == .stalker { lines.append(.init("Its login cannot reach this Apple TV.", style: .muted)) }
        #endif
        return lines
    }

    private func save(_ editor: SourceEditor) {
        Task {
            let checked = editor.needsCheck
            if await editor.save(in: context), checked { refresher?.refresh([editor.id]) }
        }
    }
}

/// The editable fields: Name, the link, the guide link for a playlist, and
/// the login for Xtream with the password field empty.
private struct SourceFieldsSection: View {
    @Bindable var editor: SourceEditor
    @Environment(\.modelContext) private var context
    @Environment(\.sourceRefresher) private var refresher

    var body: some View {
        Section("Source") {
            TextField("Name", text: $editor.name)
                .accessibilityIdentifier("settings.details.name")
            if editor.kind != .stalker {
                TextField(editor.kind == .m3u ? "Playlist" : "Server", text: $editor.link)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("settings.details.link")
            }
            if editor.kind == .m3u {
                TextField("Guide", text: $editor.guideLink, prompt: Text("Optional XMLTV link"))
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("settings.details.guide")
            }
        }
        if editor.kind == .xtream {
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
                TextField("Username", text: $editor.username)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("settings.details.username")
                SecureField("Password", text: $editor.password, prompt: Text("••••••••"))
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
}
