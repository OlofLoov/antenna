import AntennaCore
import SwiftUI

/// The guides with their status and Add guide URL, the channels without a
/// guide, and the channels matched by name
/// (guide-sources-and-channel-mapping/find-the-channels-without-a-guide).
/// Selecting a channel sets `model.selected`.
struct GuideSourcesList: View {
    @Bindable var model: GuideSourcesModel
    @State private var acting: GuideRow?
    @State private var adding: AddForm?

    /// The add form, empty or filled to re-enter an added link's login.
    struct AddForm: Identifiable {
        var replacing: String?
        var prefill: String
        var id: String { replacing ?? "new" }
    }

    var body: some View {
        List {
            guides
            channels
            named
        }
        #if os(tvOS)
            // The search field at the top opens the full-screen keyboard
            // (guide-sources-and-channel-mapping/find-the-channels-without-a-guide).
            .searchable(text: $model.filter, prompt: GuideSourcesText.filterPrompt)
        #endif
        .confirmationDialog(
            acting.map { model.name($0.reference) } ?? "", isPresented: Binding(get: { acting != nil }, set: { if !$0 { acting = nil } }),
            titleVisibility: .visible, presenting: acting
        ) { row in
            actions(row)
        }
        .sheet(item: $adding) { form in
            GuideAddLinkSheet(model: model, replacing: form.replacing, text: form.prefill)
        }
    }

    // MARK: Guides

    private var guides: some View {
        Section(GuideSourcesText.title) {
            ForEach(Array(model.status.rows.enumerated()), id: \.element.reference) { position, row in
                GuideSourcesRows.Guide(
                    name: model.name(row.reference), address: model.text.address(row, link: model.link(row.reference)),
                    status: model.statusLine(row), identifier: "guideSources.row.\(position)", select: { acting = row },
                    retry: retry(row))
            }
            Button(GuideSourcesText.addGuide) { adding = AddForm(replacing: nil, prefill: "") }
                .accessibilityIdentifier("guideSources.add")
        }
    }

    /// Retry now on a failed or offline row; Re-enter link on an added link
    /// whose login is not on this device.
    private func retry(_ row: GuideRow) -> (() -> Void)? {
        guard case .failed(let error) = row.status else { return nil }
        if error == .credentialMissing {
            guard case .added(let id) = row.reference, let link = model.link(row.reference) else { return nil }
            return { adding = AddForm(replacing: id, prefill: "\(link.scheme)://\(link.host)\(link.port.map { ":\($0)" } ?? "")") }
        }
        return { model.retry(row.reference) }
    }

    @ViewBuilder private func actions(_ row: GuideRow) -> some View {
        let references = model.status.rows.map(\.reference)
        if references.first != row.reference {
            Button("Move up") { model.move(row.reference, by: -1) }
                .accessibilityIdentifier("guideSources.action.moveUp")
        }
        if references.last != row.reference {
            Button("Move down") { model.move(row.reference, by: 1) }
                .accessibilityIdentifier("guideSources.action.moveDown")
        }
        Button(row.enabled ? "Turn off" : "Turn on") { model.toggle(row) }
            .accessibilityIdentifier("guideSources.action.toggle")
        if case .failed(let error) = row.status, error != .credentialMissing {
            Button(GuideSourcesText.retry) { model.retry(row.reference) }
                .accessibilityIdentifier("guideSources.action.retry")
        }
        if row.reference.isRemovable {
            Button("Remove", role: .destructive) { model.remove(row.reference) }
                .accessibilityIdentifier("guideSources.action.remove")
        }
        Button("Cancel", role: .cancel) {}
    }

    // MARK: Channels

    @ViewBuilder private var channels: some View {
        let missing = model.missing
        switch model.column {
        case .noChannels:
            Section(model.text.header(nil)) {
                Text(model.text.noChannels(source: model.source))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("guideSources.channels.empty")
            }
        case .sharedReason(let reason, let count):
            Section {
                if let first = model.channels.first {
                    GuideSourcesRows.Card(card: model.card(for: first))
                }
                if model.expanded {
                    rows(missing)
                } else {
                    Button(model.text.showAll(count)) { model.expanded = true }
                        .accessibilityIdentifier("guideSources.channels.showAll")
                }
            } header: {
                header(model.text.header(count))
            }
            .id(GuideSourcesText.label(reason))
        case .waiting:
            Section(model.text.header(nil)) {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(GuideSourcesText.waitingForGuide)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("guideSources.channels.empty")
            }
        case .everyChannel:
            Section {
                Text(model.text.everyChannel(source: model.source))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("guideSources.channels.empty")
            } header: {
                header(model.text.header(0))
            }
        case .rows:
            Section {
                #if !os(tvOS)
                    TextField(GuideSourcesText.filterPrompt, text: $model.filter)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("guideSources.channels.filter")
                #endif
                rows(model.filtered(missing))
            } header: {
                header(model.text.header(missing.count))
            }
        }
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .accessibilityIdentifier("guideSources.channels.header")
    }

    private func rows(_ list: [GuideSourcesModel.Missing]) -> some View {
        ForEach(Array(list.enumerated()), id: \.element.id) { position, item in
            GuideSourcesRows.Channel(
                name: item.channel.name, number: number(item.channel), logo: item.channel.logoURL,
                label: GuideSourcesText.label(item.reason), identifier: "guideSources.channels.row.\(position)",
                select: { model.selected = item.channel.id })
        }
    }

    private func number(_ channel: Channel) -> String? {
        channel.number.map { ChannelNumber(major: $0, minor: channel.minorNumber).description }
    }

    // MARK: Matched by name

    @ViewBuilder private var named: some View {
        let named = model.named
        if !named.isEmpty {
            Section {
                ForEach(Array(named.enumerated()), id: \.element.id) { position, channel in
                    let entry = model.index.key(for: channel).map(\.epgID) ?? ""
                    GuideSourcesRows.Channel(
                        name: channel.name, number: number(channel), logo: channel.logoURL,
                        label: model.entryName(entry), identifier: "guideSources.named.row.\(position)",
                        select: { model.selected = channel.id })
                }
            } header: {
                Text(model.text.namedHeader(named.count))
                    .accessibilityIdentifier("guideSources.named.header")
            }
        }
    }
}

/// Enter a guide link; saving checks it and adds it to the end of the list,
/// or puts a re-entered link back in its place
/// (guide-sources-and-channel-mapping/add-a-guide-link).
struct GuideAddLinkSheet: View {
    let model: GuideSourcesModel
    let replacing: String?
    @State var text: String
    @State private var problem: String?
    @State private var saving = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Guide URL", text: $text, prompt: Text("https://"))
                        .autocorrectionDisabled()
                        #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                        #endif
                        .accessibilityIdentifier("guideSources.addForm.field")
                    if let problem {
                        Text(problem)
                            .foregroundStyle(OnboardingForm.errorColor)
                            .accessibilityIdentifier("guideSources.addForm.error")
                    }
                } footer: {
                    Text("A link with a login or token is kept in your iCloud Keychain only.")
                }
                Section {
                    Button("Save", action: save)
                        .disabled(saving)
                        .accessibilityIdentifier("guideSources.addForm.save")
                }
            }
            .navigationTitle(replacing == nil ? GuideSourcesText.addGuide : GuideSourcesText.reenter)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save() {
        saving = true
        Task {
            let found = await model.add(text, replacing: replacing)
            saving = false
            if let found {
                problem = found.message
            } else {
                dismiss()
            }
        }
    }
}
