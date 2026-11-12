import AntennaCore
import SwiftData
import SwiftUI

/// Picks the channels of one of the user's groups from every loaded
/// playlist (`TV-Groups-Members`; group-management/build-your-own-group-from-any-playlist).
/// Selecting a row adds or removes it; Done stores the members in the
/// order they were added. Channels whose id holds a link, M3U channels
/// today, are not offered.
struct GroupPicker: View {
    let id: UUID
    let catalogue: Catalogue<PersistentIdentifier>
    let sourceNames: [UUID: String]
    let done: () -> Void

    @Environment(\.modelContext) private var context
    @State private var picked: [RowKey] = []
    @State private var filter = ""
    @State private var names: ChannelNameIndex?

    var body: some View {
        NavigationStack {
            List {
                TextField("Filter channels by name or number", text: $filter)
                    .accessibilityIdentifier("groups.picker.filter")
                ForEach(rows, id: \.self) { key in
                    Button {
                        toggle(key)
                    } label: {
                        row(key)
                    }
                    .accessibilityIdentifier("groups.picker.row.\(key.identifier)")
                    .accessibilityAddTraits(picked.contains(key) ? .isSelected : [])
                }
            }
            .navigationTitle(catalogue.label(of: .own(id)))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }.accessibilityIdentifier("groups.picker.done")
                }
            }
        }
        .onAppear {
            guard names == nil else { return }
            names = ChannelNameIndex(catalogue)
            picked = catalogue.members(of: id)
        }
    }

    private var offered: [RowKey] {
        catalogue.searchRows(includingHidden: true).filter { GroupRules.canSave(channelID: $0.id) }
    }

    /// The offered rows the filter matches. The name index is built once
    /// when the picker opens, so a keystroke only filters.
    private var rows: [RowKey] {
        names?.filter(offered, by: ChannelFilter(filter)) ?? offered
    }

    private func row(_ key: RowKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: picked.contains(key) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(picked.contains(key) ? Palette.accent : Palette.textMuted)
                .accessibilityHidden(true)
            Text(catalogue.channelNumber(for: key).map(\.description) ?? "").monospacedDigit().foregroundStyle(Palette.textMuted)
            Text(catalogue.channel(for: key)?.name ?? "").foregroundStyle(Palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(sourceNames[key.sourceID] ?? "").foregroundStyle(Palette.textMuted)
        }
    }

    private func toggle(_ key: RowKey) {
        if let index = picked.firstIndex(of: key) { picked.remove(at: index) } else { picked.append(key) }
    }

    private func save() {
        let loaded = Set(catalogue.searchRows(includingHidden: true).map(\.sourceID))
        GroupStore.setMembers(of: id, to: picked.compactMap(catalogue.channel(for:)), loaded: loaded, in: context)
        done()
    }
}
