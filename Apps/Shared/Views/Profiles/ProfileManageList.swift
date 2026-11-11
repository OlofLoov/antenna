#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// Manage profiles on iPhone, iPad and Mac, from "Who's watching?" or
    /// from Settings: every profile, Add profile while there is room, the
    /// eight-profile line and Done (profiles/adding-a-profile). A row opens
    /// the edit sheet (`iPhone-Profiles-Edit`).
    struct ProfileManageFlow: View {
        let profiles: ProfileList
        let done: () -> Void
        @State private var editing: Editing?

        /// The sheet's subject: a profile, or a new one.
        enum Editing: Identifiable {
            case add
            case profile(Profile)

            var id: UUID? {
                if case .profile(let profile) = self { return profile.id }
                return nil
            }
        }

        var body: some View {
            NavigationStack {
                List {
                    Section {
                        ForEach(Array(zip(profiles.profiles.indices, profiles.profiles)), id: \.1.id) { index, profile in
                            Button {
                                editing = .profile(profile)
                            } label: {
                                ProfileRow(tile: ProfileTile(profile))
                            }
                            .accessibilityLabel("Edit \(profile.name)")
                            .accessibilityIdentifier("profiles.tile.\(index)")
                        }
                        if profiles.canAdd {
                            Button("Add profile") { editing = .add }
                                .accessibilityIdentifier("profiles.add")
                        }
                    } footer: {
                        if !profiles.canAdd {
                            Text("You can have up to eight profiles.")
                                .accessibilityIdentifier("profiles.limit")
                        }
                    }
                }
                .navigationTitle("Manage profiles")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: done)
                            .accessibilityIdentifier("profiles.done")
                    }
                }
                .sheet(item: $editing) { subject in
                    ProfileEditSheet(profile: subject.profile, profiles: profiles)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    extension ProfileManageFlow.Editing {
        fileprivate var profile: Profile? {
            if case .profile(let profile) = self { return profile }
            return nil
        }
    }

    /// One profile in Manage profiles: its color and initial, then its name.
    private struct ProfileRow: View {
        let tile: ProfileTile

        var body: some View {
            HStack(spacing: 14) {
                ProfileBadge(tile: tile, size: 36)
                Text(tile.name)
                    .foregroundStyle(Palette.text)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.textMuted)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
    }

    /// The edit sheet (`iPhone-Profiles-Edit`): name, the eight colors,
    /// Cancel and Save, and Delete profile unless it is the last
    /// (profiles/editing-and-deleting-a-profile). Adds a profile when
    /// `profile` is nil.
    struct ProfileEditSheet: View {
        let profile: Profile?
        let profiles: ProfileList
        @Environment(\.modelContext) private var context
        @Environment(\.dismiss) private var dismiss
        @State private var name: String
        @State private var colorIndex: Int
        @State private var confirmingDelete = false

        init(profile: Profile?, profiles: ProfileList) {
            self.profile = profile
            self.profiles = profiles
            _name = State(initialValue: profile?.name ?? "")
            let used = Set(profiles.profiles.map(\.colorIndex))
            _colorIndex = State(initialValue: profile?.colorIndex ?? (Profile.colors.indices.first { !used.contains($0) } ?? 0))
        }

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 28) {
                        ProfileBadge(tile: tile, size: 112)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Name")
                                .font(.footnote.weight(.semibold))
                                .textCase(.uppercase)
                                .foregroundStyle(Palette.textMuted)
                                .padding(.horizontal, 4)
                            TextField("Name", text: $name)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 48)
                                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                                .accessibilityIdentifier("profiles.edit.name")
                        }
                        ProfileColorRow(selected: colorIndex) { colorIndex = $0 }
                        if let profile, profiles.canDelete(profile.id) {
                            Button("Delete profile", role: .destructive) { confirmingDelete = true }
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                                .accessibilityIdentifier("profiles.edit.delete")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 28)
                }
                .background(Palette.ground)
                .foregroundStyle(Palette.text)
                .navigationTitle(profile == nil ? "Add profile" : "Edit profile")
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: save)
                            .disabled(ProfileList.validName(name) == nil)
                            .accessibilityIdentifier("profiles.edit.save")
                    }
                }
                .alert("Delete \(profile?.name ?? "")?", isPresented: $confirmingDelete) {
                    Button("Delete", role: .destructive) {
                        if let profile { ProfileStore.delete(profile.id, in: context) }
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Its favorites, hidden groups and history go too. Sources stay.")
                }
            }
            .preferredColorScheme(.dark)
        }

        private var tile: ProfileTile {
            let initial = ProfileList.validName(name).map {
                Profile(id: UUID(), name: $0, colorIndex: 0, sortOrder: 0, createdAt: .now).initial
            }
            return ProfileTile(id: profile?.id ?? UUID(), name: name, initial: initial ?? "?", color: Profile.colors[colorIndex])
        }

        private func save() {
            if let profile {
                ProfileStore.edit(profile.id, name: name, colorIndex: colorIndex, in: context)
            } else {
                ProfileStore.add(name: name, colorIndex: colorIndex, in: context)
            }
            dismiss()
        }
    }
#endif
