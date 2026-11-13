import AntennaCore
import SwiftData
import SwiftUI

/// The Groups screen on every platform (group-management capability;
/// `TV-Groups`, `iPad-Groups`, `iPhone-Groups` and their empty and locked
/// boards): every group with its badges and count, New group, the settings
/// for groups that are gone, and the passcode controls. While a group is
/// locked and the locks are closed, the passcode prompt comes first
/// (group-management/unlock-with-the-passcode).
struct GroupsScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.loadedChannels) private var channels
    @Environment(\.currentProfile) private var profile
    @Environment(GroupLocks.self) private var locks: GroupLocks?
    @Query private var groups: [GroupRecord]
    @Query private var members: [GroupMemberRecord]
    @Query private var hidden: [HiddenGroupRecord]
    @Query private var passcodes: [PasscodeRecord]
    @Query(sort: SourceRecord.displayOrder) private var sources: [SourceRecord]
    @AppStorage(GroupDefaults.searchHidden) private var searchHidden = false
    @State private var naming = false
    @State private var newName = ""
    @State private var changing = false

    var body: some View {
        let data = GroupsData(channels: channels, groups: groups, members: members, hidden: hidden, sources: sources, profile: profile)
        Group {
            if needsPasscode(data) {
                PasscodePrompt(flow: .unlock, message: "Groups has locked groups.") { opened in
                    if !opened { dismiss() }
                }
            } else if channels.isEmpty {
                Text("No groups yet. Add a source in Settings and its groups appear here.")
                    .foregroundStyle(Palette.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(32)
                    .accessibilityIdentifier("groups.empty")
            } else {
                list(data)
            }
        }
        .navigationTitle("Groups")
        .alert("New group", isPresented: $naming) {
            TextField("Name", text: $newName).accessibilityIdentifier("groups.newName")
            Button("Create") {
                GroupStore.create(named: newName, after: data.groups, in: context)
                newName = ""
            }
            Button("Cancel", role: .cancel) { newName = "" }
        }
        .sheet(isPresented: $changing) {
            PasscodePrompt(flow: .change, message: "Enter the current passcode first.") { _ in changing = false }
        }
    }

    private func needsPasscode(_ data: GroupsData) -> Bool {
        !data.rules.locked.isEmpty && !(locks?.isOpen ?? false)
    }

    private func list(_ data: GroupsData) -> some View {
        List {
            Section {
                ForEach(data.groups, id: \.self) { group in
                    NavigationLink {
                        GroupDetailScreen(group: group)
                    } label: {
                        GroupRow(
                            name: data.catalogue.label(of: group), count: data.catalogue.memberCount(of: group), badges: badges(group, data)
                        )
                    }
                    .accessibilityIdentifier(identifier(group, data))
                    .moveDisabled(group == .all)
                }
                .onMove { from, to in
                    var order = data.groups
                    order.move(fromOffsets: from, toOffset: max(1, to))
                    GroupStore.reorder(order, in: context)
                }
                Button("New group") { naming = true }
                    .accessibilityIdentifier("groups.new")
            } header: {
                Text("Groups · \(data.groups.count)").accessibilityIdentifier("groups.list")
            } footer: {
                Text("Hide, lock, rename and reorder. Changes reach every device signed into your iCloud.")
            }
            orphans(data)
            passcodeSection
        }
    }

    @ViewBuilder private func orphans(_ data: GroupsData) -> some View {
        let gone = data.orphans
        if !gone.isEmpty {
            Section {
                ForEach(gone, id: \.self) { group in
                    HStack {
                        Text(data.caption(group)).frame(maxWidth: .infinity, alignment: .leading)
                        Button("Remove") { GroupStore.remove(group, in: context) }
                            .accessibilityIdentifier("groups.orphan.remove.\(group.storageKey)")
                    }
                }
            } header: {
                Text("Not in any source").accessibilityIdentifier("groups.orphans")
            }
        }
    }

    private var passcodeSection: some View {
        Section {
            if !passcodes.isEmpty {
                Button("Change passcode") { changing = true }
                    .accessibilityIdentifier("groups.setPasscode")
            }
            if locks?.isOpen == true {
                Button("Lock now") {
                    locks?.close()
                    dismiss()
                }
                .accessibilityIdentifier("groups.lockNow")
            }
            Toggle("Include hidden channels in search", isOn: $searchHidden)
                .accessibilityIdentifier("groups.searchHidden")
        } header: {
            Text("Passcode")
        }
    }

    private func badges(_ group: CatalogueGroup, _ data: GroupsData) -> [GroupRow.Badge] {
        var badges: [GroupRow.Badge] = []
        if data.isLocked(group) { badges.append(.locked) }
        if data.isHidden(group) { badges.append(.hidden) }
        if case .own = group { badges.append(.custom) }
        return badges
    }

    /// `groups.row.<groupKey>`, with `.locked`, `.hidden` or `.custom` when
    /// the row carries that badge (`TV-Groups`).
    private func identifier(_ group: CatalogueGroup, _ data: GroupsData) -> String {
        let suffix = badges(group, data).first.map { ".\($0.rawValue.lowercased())" } ?? ""
        return "groups.row.\(group.storageKey)\(suffix)"
    }
}

/// The Groups row in Sources and Settings, opening the Groups screen.
struct GroupsSettingsRow: View {
    var body: some View {
        NavigationLink {
            GroupsScreen()
        } label: {
            Text("Groups")
        }
        .accessibilityIdentifier("settings.groups")
    }
}
