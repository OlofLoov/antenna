import AntennaCore
import SwiftData
import SwiftUI

/// Appearance in Settings on every platform (`iPhone-Settings-Appearance`,
/// `iPad-Settings-Appearance`, `Mac-Settings-Appearance`, `TV-Settings-Appearance`):
/// the accent of the current profile (sources-and-settings/pick-the-accent-for-your-profile).
struct AppearanceSection: View {
    @Environment(\.modelContext) private var context
    @Environment(\.currentProfile) private var currentProfile
    /// What the app draws with now, which the row reads out, so a UI test
    /// sees the environment follow the pick.
    @Environment(\.accent) private var accent
    @Query private var profiles: [ProfileRecord]

    static let footer: LocalizedStringResource = "The accent is for this profile on every device."

    var body: some View {
        Section {
            SwatchChoiceRow(
                label: "Accent", footer: Self.footer, selection: selection, choices: ProfileAccent.allCases, id: \.rawValue,
                title: \.title
            ) { choice, side in
                AccentSwatch(accent: choice, side: side)
            }
            .accessibilityValue(Text(accent.title))
            .settingsFooter(.appearance)
            .accessibilityIdentifier("settings.appearance.accent")
        } header: {
            Text("Appearance")
        } footer: {
            #if !os(tvOS)
                Text(Self.footer)
            #endif
        }
    }

    private var selection: Binding<ProfileAccent> {
        Binding(
            get: { ProfileStore.list(profiles).profiles.first { $0.id == currentProfile }?.accent ?? .blue },
            set: { ProfileStore.setAccent($0, of: currentProfile, in: context) })
    }
}
