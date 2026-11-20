#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// Opens Settings from the iPhone tabs, which have no Settings tab.
    struct ShowSettingsAction {
        let perform: @MainActor () -> Void

        @MainActor func callAsFunction() { perform() }
    }

    extension EnvironmentValues {
        /// Set by the iPhone tab bar; nil in the sidebar layout and on Apple TV.
        @Entry var showSettings: ShowSettingsAction?
        /// Closes Settings shown as a sheet; nil where Settings is a tab or a sidebar section.
        @Entry var closeSettings: ShowSettingsAction?
    }

    /// The profile button at the top right of Live, the Guide, Movies and
    /// Series on iPhone and in a narrow iPad window (`iPhone-Profile-Menu`;
    /// live-tv-on-iphone-ipad-mac/settings-from-the-profile-button, profiles/switching-profile).
    /// With two or more profiles it opens a menu with Switch profile and
    /// Settings; with one it opens Settings. Nothing outside the tab bar layout.
    struct ProfileMenuButton: View {
        @Query private var records: [ProfileRecord]
        @Environment(\.currentProfile) private var current
        @Environment(\.switchProfile) private var switchProfile
        @Environment(\.showSettings) private var showSettings

        var body: some View {
            if let showSettings {
                let profiles = ProfileStore.list(records)
                if profiles.showsPicker, let profile = profiles.profiles.first(where: { $0.id == current }) ?? profiles.profiles.first {
                    let tile = ProfileTile(profile)
                    Menu {
                        Section(tile.name) {
                            Button("Switch profile", systemImage: "person.2") { switchProfile?() }
                                .accessibilityIdentifier("profile.switch")
                            Button("Settings", systemImage: "gearshape") { showSettings() }
                                .accessibilityIdentifier("profile.settings")
                        }
                    } label: {
                        ProfileCornerLabel(tile: tile)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Profile, \(tile.name)")
                    .accessibilityIdentifier("profile.button")
                } else {
                    Button {
                        showSettings()
                    } label: {
                        ProfileCornerLabel(tile: nil)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("profile.button")
                }
            }
        }
    }

    /// Close in the top bar of Settings opened as a sheet from the profile
    /// button. Nothing where Settings is a tab or a sidebar section.
    struct SettingsSheetClose: ViewModifier {
        @Environment(\.closeSettings) private var closeSettings

        func body(content: Content) -> some View {
            content.toolbar {
                if let closeSettings {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) { closeSettings() }
                            .accessibilityIdentifier("settings.close")
                    }
                }
            }
        }
    }

    extension View {
        /// This row with the profile button at its trailing end, as the
        /// group button on Live and in the Guide.
        func withProfileButton() -> some View {
            HStack(spacing: 0) {
                self
                ProfileMenuButton()
                    .padding(.trailing, 12)
            }
        }

        /// The profile button over the top right corner, for a tab's
        /// whole-screen message, which has no row to hold it.
        func profileButtonInCorner() -> some View {
            overlay(alignment: .topTrailing) {
                ProfileMenuButton()
                    .padding(.trailing, 12)
            }
        }
    }
#endif
