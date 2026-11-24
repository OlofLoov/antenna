#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// Which tab a group button and its sheet sit in. Only the identifiers
    /// differ, so a test reads the same rows the chips had.
    enum GroupListPlace {
        case live, guide

        var button: String {
            switch self {
            case .live: "browse.groups"
            case .guide: "guide.groups"
            }
        }

        func row(_ group: CatalogueGroup, index: Int) -> String {
            switch self {
            case .live: group == .new ? "groups.new" : "browse.group.\(index)"
            case .guide: "guide.group.\(index)"
            }
        }
    }

    /// The open group under the now-playing line on iPhone, and above the
    /// day chips in the Guide (`iPhone-Live-Groups`). Tapping it opens the
    /// Groups sheet; a locked group picked there asks for the passcode once
    /// the sheet has closed, since the prompt is a sheet of its own. The
    /// screen holds whether the sheet is open, so the player's error can open
    /// it too (player-controls-and-playback-errors/go-to-another-group-from-the-error).
    struct LiveGroupButton: View {
        let place: GroupListPlace
        @Binding var isPresented: Bool
        @Environment(LiveModel.self) private var live
        @Environment(\.unlockGroup) private var unlock
        @State private var lockedPick: CatalogueGroup?

        var body: some View {
            Browse.GroupButton(name: live.catalogue.label(of: live.group), count: live.catalogue.count(of: live.group)) {
                isPresented = true
            }
            .accessibilityIdentifier(place.button)
            .sheet(isPresented: $isPresented, onDismiss: askForPasscode) {
                LiveGroupSheet(place: place) { lockedPick = $0 }
                    .presentationDetents([.medium, .large])
            }
        }

        private func askForPasscode() {
            guard let group = lockedPick else { return }
            lockedPick = nil
            unlock?(group)
        }
    }

    /// Every group the user may open, with search (`iPhone-Live-Groups`,
    /// `iPhone-Live-Groups-Search`; live-tv-on-iphone-ipad-mac/pick-a-group,
    /// live-tv-on-iphone-ipad-mac/find-a-group-among-many): the built-in
    /// groups, then the rest in the catalogue's order with their counts and a
    /// checkmark on the open one, then the locked groups. Picking a group
    /// opens it and closes the sheet.
    struct LiveGroupSheet: View {
        let place: GroupListPlace
        /// A locked group was picked; the sheet closes on its own.
        let pickLocked: (CatalogueGroup) -> Void
        @Environment(LiveModel.self) private var live
        @Environment(\.dismiss) private var dismiss
        @State private var query = ""

        var body: some View {
            let choices = GroupChoices(live.catalogue, query: query) { live.catalogue.label(of: $0) }
            NavigationStack {
                ScrollViewReader { proxy in
                    List {
                        if !choices.builtIn.isEmpty {
                            Section {
                                ForEach(choices.builtIn, id: \.self, content: row)
                            }
                        }
                        if !choices.groups.isEmpty || !choices.locked.isEmpty {
                            Section {
                                ForEach(choices.groups, id: \.self, content: row)
                                ForEach(choices.locked, id: \.self) { choice in
                                    locked(choice.group)
                                }
                            }
                        }
                    }
                    // Rows drop their vertical insets and stay 44 pt, so the
                    // medium detent shows about eight groups.
                    .environment(\.defaultMinListRowHeight, 44)
                    .accessibilityIdentifier("browse.groups.sheet")
                    .overlay {
                        if choices.isEmpty {
                            ContentUnavailableView.search(text: query)
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("browse.groups.empty")
                        }
                    }
                    // A group far down a long list is in view when the sheet opens.
                    .onAppear { proxy.scrollTo(live.group, anchor: .center) }
                }
                .navigationTitle(Text("Groups"))
                .groupSearch($query)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) { dismiss() }
                            .accessibilityIdentifier("browse.groups.close")
                    }
                }
            }
        }

        private func row(_ choice: GroupChoices.Choice) -> some View {
            let group = choice.group
            let count = live.catalogue.count(of: group)
            return Browse.GroupChoiceRow(
                name: live.catalogue.label(of: group), systemImage: group.systemImage, count: count, isSelected: group == live.group
            ) {
                live.show(group)
                dismiss()
            }
            .listRowInsets(.vertical, 0)
            .id(group)
            .accessibilityIdentifier(place.row(group, index: choice.index ?? 0))
        }

        private func locked(_ group: CatalogueGroup) -> some View {
            Browse.GroupChoiceRow(name: live.catalogue.label(of: group), systemImage: nil, count: nil, isSelected: false) {
                pickLocked(group)
                dismiss()
            }
            .listRowInsets(.vertical, 0)
            .accessibilityIdentifier("browse.locked.\(group.storageKey)")
        }
    }

    extension View {
        /// The sheet's search field, always shown under the title on iPhone.
        @ViewBuilder fileprivate func groupSearch(_ query: Binding<String>) -> some View {
            #if os(iOS)
                navigationBarTitleDisplayMode(.inline)
                    .searchable(text: query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search groups"))
            #else
                searchable(text: query, prompt: Text("Search groups"))
            #endif
        }
    }
#endif
