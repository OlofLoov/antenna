import SwiftUI
import SwiftData
import AntennaCore

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SourceRecord.sortOrder) private var sources: [SourceRecord]
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Sources") {
                    ForEach(sources) { source in
                        VStack(alignment: .leading) {
                            Text(source.name)
                            Text(source.url?.absoluteString ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets {
                            if let key = sources[i].credentialKey { try? CredentialStore().delete(for: key) }
                            context.delete(sources[i])
                        }
                    }
                    Button("Add source…") { showingAdd = true }
                }
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
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
    @Query private var existing: [SourceRecord]

    @State private var kind: SourceKind = .m3u
    @State private var name = ""
    @State private var url = ""
    @State private var epgURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) {
                    Text("M3U playlist").tag(SourceKind.m3u)
                    Text("Xtream Codes").tag(SourceKind.xtream)
                    Text("Stalker portal").tag(SourceKind.stalker)
                }
                TextField("Name", text: $name)
                TextField(kind == .m3u ? "Playlist URL" : "Server URL", text: $url)
                    #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    #endif
                if kind == .m3u {
                    TextField("EPG URL (optional)", text: $epgURL)
                }
                if kind != .m3u {
                    TextField(kind == .stalker ? "MAC address" : "Username", text: $username)
                    SecureField("Password", text: $password)
                }
                if let error {
                    Text(error).foregroundStyle(.red)
                }
            }
            .navigationTitle("Add source")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
    }

    private func save() {
        guard let serverURL = URL(string: url.trimmingCharacters(in: .whitespaces)), serverURL.scheme != nil else {
            error = "Enter a valid URL."
            return
        }
        var descriptor = SourceDescriptor(
            name: name.isEmpty ? serverURL.host() ?? "Source" : name,
            kind: kind,
            url: serverURL,
            epgURL: URL(string: epgURL)
        )
        if kind != .m3u {
            let key = descriptor.id.uuidString
            do {
                try CredentialStore().save(.init(username: username, password: password), for: key)
            } catch {
                self.error = "Could not store credentials: \(error)"
                return
            }
            descriptor.credentialKey = key
        }
        context.insert(SourceRecord(descriptor: descriptor, sortOrder: existing.count))
        dismiss()
    }
}
