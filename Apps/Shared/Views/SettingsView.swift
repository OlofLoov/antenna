import SwiftUI
import SwiftData
import AntennaCore

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: SourceRecord.displayOrder) private var sources: [SourceRecord]
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ProfileSettingsRow()
                }
                Section("Sources") {
                    ForEach(sources) { source in
                        VStack(alignment: .leading) {
                            Text(source.name)
                            Text(source.url?.absoluteString ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .accessibilityIdentifier("settings.source.\(source.id.uuidString)")
                    }
                    .onDelete { offsets in
                        for i in offsets {
                            SourceRecord.delete(sources[i], from: context, credentials: CredentialStore())
                        }
                    }
                    Button("Add source…") { showingAdd = true }
                        .accessibilityIdentifier("settings.addSource")
                }
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                    NavigationLink("FFmpeg") { FFmpegNoticeView() }
                        .accessibilityIdentifier("settings.ffmpegNotice")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAdd) {
                AddSourceView()
            }
        }
    }
}

struct AddSourceView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var form = NewSource()
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $form.kind) {
                    Text("M3U playlist").tag(SourceKind.m3u)
                    Text("Xtream Codes").tag(SourceKind.xtream)
                    Text("Stalker portal").tag(SourceKind.stalker)
                }
                TextField("Name", text: $form.name)
                TextField(form.kind == .m3u ? "Playlist URL" : "Server URL", text: $form.url)
                    #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    #endif
                if form.kind == .m3u {
                    TextField("EPG URL (optional)", text: $form.epgURL)
                }
                if form.kind != .m3u {
                    TextField(form.kind == .stalker ? "MAC address" : "Username", text: $form.username)
                    SecureField("Password", text: $form.password)
                }
                if let error {
                    Text(error).foregroundStyle(.red)
                        .accessibilityIdentifier("addSource.error")
                }
            }
            .navigationTitle("Add source")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).accessibilityIdentifier("addSource.save") }
            }
        }
    }

    private func save() {
        do {
            try form.save(into: context, credentials: CredentialStore())
            dismiss()
        } catch {
            self.error = error.message
        }
    }
}
