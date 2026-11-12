import AntennaCore
import SwiftData
import SwiftUI

/// One group's settings (`iPhone-Groups-Detail`, the right-hand editor on
/// `iPad-Groups` and the panel on `TV-Groups`): its name, Hidden, Locked,
/// Move up and Move down, and for the user's own group its channels, Add
/// channels and Delete group.
struct GroupDetailScreen: View {
    let group: CatalogueGroup

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
    @State private var name = ""
    @State private var refused = false
    @State private var prompt: PasscodeFlow?
    @State private var picking = false

    var body: some View {
        let data = GroupsData(channels: channels, groups: groups, members: members, hidden: hidden, sources: sources, profile: profile)
        Form {
            if group != .all {
                Section("Name") {
                    TextField(placeholder, text: $name)
                        .onSubmit { rename() }
                        .accessibilityIdentifier("groups.name")
                    Button("Rename") { rename() }
                        .accessibilityIdentifier("groups.rename")
                    if refused {
                        Text("Your own group needs a name.").foregroundStyle(Palette.textMuted)
                    }
                }
            }
            Section {
                Toggle("Hidden", isOn: hiddenBinding(data)).accessibilityIdentifier("groups.hide")
                if group != .all {
                    Toggle("Locked", isOn: lockedBinding(data)).accessibilityIdentifier("groups.lock")
                }
            }
            if group != .all { moves(data) }
            if case .own(let id) = group { own(id, data) }
        }
        .navigationTitle(data.catalogue.label(of: group))
        .onAppear { name = data.catalogue.customName(of: group) ?? "" }
        .sheet(item: $prompt) { flow in
            PasscodePrompt(flow: flow, message: "\(data.catalogue.label(of: group)) will be locked.") { done in
                prompt = nil
                if done { GroupStore.setLocked(group, true, in: context) }
            }
        }
        .sheet(isPresented: $picking) {
            if case .own(let id) = group {
                GroupPicker(id: id, catalogue: data.catalogue, sourceNames: data.sourceNames) { picking = false }
            }
        }
    }

    private var loaded: Set<UUID> { Set(channels.compactMap(\.sourceID)) }

    private var placeholder: String {
        if case .named(_, let provider) = group { return provider }
        return group.label
    }

    private func rename() {
        refused = !GroupStore.rename(group, to: name, in: context)
    }

    private func hiddenBinding(_ data: GroupsData) -> Binding<Bool> {
        Binding(get: { data.isHidden(group) }, set: { GroupStore.setHidden(group, $0, profile: profile, in: context) })
    }

    /// Locking asks for a new passcode the first time, and for the current
    /// one while the locks are closed (group-management/unlock-with-the-passcode).
    private func lockedBinding(_ data: GroupsData) -> Binding<Bool> {
        Binding(
            get: { data.isLocked(group) },
            set: { locked in
                guard locked else { return GroupStore.setLocked(group, false, in: context) }
                if PasscodeStore.current(passcodes) == nil {
                    prompt = .create
                } else if !(locks?.isOpen ?? false) {
                    prompt = .unlock
                } else {
                    GroupStore.setLocked(group, true, in: context)
                }
            })
    }

    private func moves(_ data: GroupsData) -> some View {
        let order = data.groups
        let place = order.firstIndex(of: group) ?? 0
        return Section {
            Button("Move up") { move(order, from: place, to: place - 1) }
                .disabled(place <= 1)
                .accessibilityIdentifier("groups.moveUp")
            Button("Move down") { move(order, from: place, to: place + 1) }
                .disabled(place >= order.count - 1)
                .accessibilityIdentifier("groups.moveDown")
        }
    }

    private func move(_ order: [CatalogueGroup], from: Int, to: Int) {
        guard order.indices.contains(to), to >= 1 else { return }
        var order = order
        order.swapAt(from, to)
        GroupStore.reorder(order, in: context)
    }

    private func own(_ id: UUID, _ data: GroupsData) -> some View {
        let keys = data.catalogue.members(of: id)
        return Group {
            Section("Channels · \(keys.count)") {
                ForEach(keys, id: \.self) { key in
                    let channel = data.catalogue.channel(for: key)
                    HStack {
                        Text(channel?.name ?? "").frame(maxWidth: .infinity, alignment: .leading)
                        Text(data.sourceNames[key.sourceID] ?? "").foregroundStyle(Palette.textMuted)
                    }
                    .accessibilityIdentifier("groups.member.\(key.identifier)")
                }
                .onMove { from, to in
                    var moved = keys
                    moved.move(fromOffsets: from, toOffset: to)
                    GroupStore.setMembers(of: id, to: moved.compactMap(data.catalogue.channel(for:)), loaded: loaded, in: context)
                }
                .onDelete { offsets in
                    var kept = keys
                    kept.remove(atOffsets: offsets)
                    GroupStore.setMembers(of: id, to: kept.compactMap(data.catalogue.channel(for:)), loaded: loaded, in: context)
                }
                Button("Add channels") { picking = true }
                    .accessibilityIdentifier("groups.addChannels")
            }
            Section {
                Button("Delete group", role: .destructive) {
                    GroupStore.delete(own: id, in: context)
                    dismiss()
                }
                .accessibilityIdentifier("groups.delete")
            }
        }
    }
}

extension PasscodeFlow: Identifiable {
    var id: Self { self }
}
