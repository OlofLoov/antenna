import AntennaCore
import SwiftData
import SwiftUI

/// "Who's watching?", Manage profiles and the edit screen (profiles capability;
/// `TV-Profiles`, `TV-Profiles-Manage`, `TV-Profiles-Edit`). Calls `choose`
/// with the profile picked; ends on its own when one profile is left.
struct ProfileFlow: View {
    enum Mode: Equatable {
        case picker
        case manage
        /// Editing a profile, or adding one with nil.
        case edit(UUID?)
    }

    let profiles: ProfileList
    let focused: UUID
    let choose: (UUID) -> Void
    @Environment(\.modelContext) private var context
    @State private var mode: Mode = .picker
    @FocusState private var focus: UUID?

    var body: some View {
        switch mode {
        case .picker:
            ProfilePicker(tiles: profiles.profiles.map(ProfileTile.init), focus: $focus, choose: choose) {
                ProfileButton(title: "Manage profiles") { mode = .manage }
                    .accessibilityIdentifier("profiles.manage")
            }
            .defaultFocus($focus, focused)
            #if os(tvOS)
                // Nothing is behind the picker, so Menu stays here.
                .onExitCommand {}
            #endif
        case .manage:
            ProfileManage(profiles: profiles, edit: { mode = .edit($0) }, done: done)
        case .edit(let id):
            ProfileEdit(profile: id.flatMap { id in profiles.profiles.first { $0.id == id } }, profiles: profiles) {
                mode = .manage
            }
        }
    }

    /// Back to the picker, or straight on when one profile is left.
    private func done() {
        if profiles.showsPicker {
            mode = .picker
        } else {
            choose(profiles.profiles[0].id)
        }
    }
}

/// Every profile with an edit mark, then Add profile while there is room,
/// and Done (profiles/adding-a-profile).
private struct ProfileManage: View {
    let profiles: ProfileList
    let edit: (UUID?) -> Void
    let done: () -> Void
    @FocusState private var focus: UUID?

    var body: some View {
        VStack(spacing: 60) {
            Spacer(minLength: 0)
            Text("Manage profiles")
                .font(.system(size: 56, weight: .bold))
            HStack(spacing: 64) {
                ForEach(Array(zip(profiles.profiles.indices, profiles.profiles)), id: \.1.id) { index, profile in
                    Button {
                        edit(profile.id)
                    } label: {
                        ProfileTileLabel(tile: ProfileTile(profile))
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 48))
                                    .accessibilityHidden(true)
                            }
                    }
                    .buttonStyle(.plain)
                    .focused($focus, equals: profile.id)
                    .accessibilityLabel("Edit \(profile.name)")
                    .accessibilityIdentifier("profiles.tile.\(index)")
                }
                if profiles.canAdd {
                    Button {
                        edit(nil)
                    } label: {
                        AddTileLabel()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add profile")
                    .accessibilityIdentifier("profiles.add")
                }
            }
            if !profiles.canAdd {
                Text("You can have up to eight profiles.")
                    .font(.system(size: 26))
                    .foregroundStyle(Palette.textMuted)
                    .accessibilityIdentifier("profiles.limit")
            }
            Spacer(minLength: 0)
            ProfileButton(title: "Done", action: done)
                .accessibilityIdentifier("profiles.done")
                .padding(.bottom, 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.ground)
        .foregroundStyle(Palette.text)
        .defaultFocus($focus, profiles.profiles.first?.id)
        #if os(tvOS)
            .onExitCommand(perform: done)
        #endif
    }
}

private struct AddTileLabel: View {
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        VStack(spacing: 22) {
            Circle()
                .strokeBorder(isFocused ? Palette.focus : Palette.textMuted, style: StrokeStyle(lineWidth: 3, dash: [10, 8]))
                .frame(width: 200, height: 200)
                .overlay(Image(systemName: "plus").font(.system(size: 80, weight: .light)))
            Text("Add profile")
                .font(.system(size: 32, weight: isFocused ? .semibold : .regular))
        }
        .foregroundStyle(isFocused ? Palette.text : ChannelOverlay.tileText)
        .scaleEffect(isFocused ? 1.08 : 1)
    }
}

/// Name, color, Save and Delete profile (profiles/editing-and-deleting-a-profile).
/// Adds a profile when `profile` is nil.
private struct ProfileEdit: View {
    let profile: Profile?
    let profiles: ProfileList
    let finish: () -> Void
    @Environment(\.modelContext) private var context
    @State private var name: String
    @State private var colorIndex: Int
    @State private var confirmingDelete = false

    init(profile: Profile?, profiles: ProfileList, finish: @escaping () -> Void) {
        self.profile = profile
        self.profiles = profiles
        self.finish = finish
        _name = State(initialValue: profile?.name ?? "")
        let used = Set(profiles.profiles.map(\.colorIndex))
        _colorIndex = State(initialValue: profile?.colorIndex ?? (Profile.colors.indices.first { !used.contains($0) } ?? 0))
    }

    var body: some View {
        VStack(spacing: 44) {
            Spacer(minLength: 0)
            ProfileTileLabel(tile: ProfileTile(id: profile?.id ?? UUID(), name: " ", initial: initial, color: Profile.colors[colorIndex]))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 12) {
                Text("NAME")
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Palette.textMuted)
                TextField("Name", text: $name)
                    .font(.system(size: 34))
                    .accessibilityIdentifier("profiles.edit.name")
            }
            .frame(width: 760)
            HStack(spacing: 28) {
                ForEach(Profile.colors.indices, id: \.self) { index in
                    Button {
                        colorIndex = index
                    } label: {
                        Circle()
                            .fill(Color(hex: Profile.colors[index]))
                            .frame(width: 72, height: 72)
                            .overlay(Circle().stroke(index == colorIndex ? Palette.focus : .clear, lineWidth: 5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Color \(index + 1)")
                    .accessibilityAddTraits(index == colorIndex ? .isSelected : [])
                    .accessibilityIdentifier("profiles.edit.color.\(index)")
                }
            }
            HStack(spacing: 24) {
                ProfileButton(title: "Save", action: save)
                    .disabled(ProfileList.validName(name) == nil)
                    .accessibilityIdentifier("profiles.edit.save")
                if let profile, profiles.canDelete(profile.id) {
                    ProfileButton(title: "Delete profile", role: .destructive) { confirmingDelete = true }
                        .accessibilityIdentifier("profiles.edit.delete")
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.ground)
        .foregroundStyle(Palette.text)
        #if os(tvOS)
            .onExitCommand(perform: finish)
        #endif
        .alert("Delete \(profile?.name ?? "")?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) {
                if let profile { ProfileStore.delete(profile.id, in: context) }
                finish()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its favorites, hidden groups and history go too. Sources stay.")
        }
    }

    private var initial: String {
        ProfileList.validName(name).map { Profile(id: UUID(), name: $0, colorIndex: 0, sortOrder: 0, createdAt: .now).initial } ?? "?"
    }

    private func save() {
        if let profile {
            ProfileStore.edit(profile.id, name: name, colorIndex: colorIndex, in: context)
        } else {
            ProfileStore.add(name: name, colorIndex: colorIndex, in: context)
        }
        finish()
    }
}

/// The 26 pt rounded button the profile screens use.
struct ProfileButton: View {
    let title: String
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(title, role: role, action: action)
            .font(.system(size: 26, weight: .semibold))
    }
}
