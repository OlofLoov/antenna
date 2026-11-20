import AntennaCore
import SwiftData
import SwiftUI

/// Appearance in Settings on every platform (`iPhone-Settings-Appearance`,
/// `iPad-Settings-Appearance`, `Mac-Settings-Appearance`, `TV-Settings-Appearance`):
/// the accent of the current profile (sources-and-settings/pick-the-accent-for-your-profile)
/// and, on iPhone, iPad and Apple TV, the app icon of this device
/// (sources-and-settings/pick-the-app-icon-on-this-device).
struct AppearanceSection: View {
    @Environment(\.modelContext) private var context
    @Environment(\.currentProfile) private var currentProfile
    /// What the app draws with now, which the row reads out, so a UI test
    /// sees the environment follow the pick.
    @Environment(\.accent) private var accent
    @Query private var profiles: [ProfileRecord]

    static var footer: LocalizedStringResource {
        #if os(macOS)
            return "The accent is for this profile on every device."
        #else
            return "The accent is for this profile on every device. The app icon is for this device only."
        #endif
    }

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
            #if !os(macOS)
                AppIconRow(footer: Self.footer)
                    .settingsFooter(.appearance)
            #endif
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

#if !os(macOS)
    /// The App icon row. The system keeps the chosen icon per device and
    /// reports it; the row shows what the system reports, so a refused
    /// change leaves the row as it was.
    private struct AppIconRow: View {
        let footer: LocalizedStringResource
        @State private var current = AppIconChoice(alternateName: UIApplication.shared.alternateIconName)

        var body: some View {
            SwatchChoiceRow(
                label: "App icon", footer: footer, selection: selection, choices: AppIconChoice.allCases, id: \.rawValue,
                title: \.title
            ) { icon, side in
                AppIconTile(icon: icon, side: side)
            }
            .accessibilityValue(Text(current.title))
            .accessibilityIdentifier("settings.appearance.icon")
        }

        private var selection: Binding<AppIconChoice> {
            Binding(get: { current }, set: { pick($0) })
        }

        private func pick(_ icon: AppIconChoice) {
            guard icon != current, UIApplication.shared.supportsAlternateIcons else { return }
            Task {
                try? await UIApplication.shared.setAlternateIconName(icon.alternateName)
                current = AppIconChoice(alternateName: UIApplication.shared.alternateIconName)
            }
        }
    }
#endif
