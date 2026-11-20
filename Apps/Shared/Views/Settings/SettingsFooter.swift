import AntennaCore
import SwiftUI

/// The footer a focused Settings row shows in the Apple TV lead column.
enum SettingsFooter: Hashable {
    /// The iCloud note, for the Sources rows.
    case iCloud
    /// What the Subtitles choice does.
    case subtitles
    /// What Autoplay next episode does.
    case autoplay
    /// What Show adult content does, on or off.
    case adultContent(shows: Bool)
}

extension FocusedValues {
    /// The footer of the focused Settings row, read by the lead column.
    @Entry var settingsFooter: SettingsFooter?
}

/// The lead column's footer: the one the focused row names, or nothing.
/// Reads focus here, not in the screen, so moving focus redraws only the
/// footer and leaves the list and its navigation alone.
struct SettingsLeadFooter: View {
    let iCloud: LocalizedStringResource
    let subtitles: String
    @FocusedValue(\.settingsFooter) private var footer

    var body: some View {
        switch footer {
        case .iCloud:
            Text(iCloud)
                .accessibilityIdentifier("settings.iCloudFooter")
        case .subtitles:
            Text(subtitles)
                .accessibilityIdentifier("settings.subtitles.footer")
        case .autoplay:
            Text(AutoplaySetting.footer())
                .accessibilityIdentifier("settings.autoplayNext.footer")
        case .adultContent(let shows):
            Text(AdultContentRow.footer(shows: shows))
                .accessibilityIdentifier("settings.adultContent.footer")
        case nil:
            EmptyView()
        }
    }
}

extension View {
    /// Names the footer the Apple TV lead column shows while this row has
    /// focus; nothing elsewhere, where the footer sits under its section.
    @ViewBuilder func settingsFooter(_ footer: SettingsFooter) -> some View {
        #if os(tvOS)
            focusedValue(\.settingsFooter, footer)
        #else
            self
        #endif
    }
}
