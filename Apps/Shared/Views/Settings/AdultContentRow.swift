import AntennaCore
import SwiftData
import SwiftUI

/// "Show adult content" for the current profile, in a section of its own
/// with its footer (`iPhone-Settings-Adult`, `iPad-Settings-Adult`,
/// `TV-Settings-Adult`). Turning it on asks for the group passcode, or to
/// set one when there is none; turning it off never asks
/// (adult-content/show-adult-content-with-the-passcode).
struct AdultContentRow: View {
    /// The prompt to show, presented by the screen around the list with
    /// `adultContentPrompt(_:)`: a sheet inside a list row does not present.
    @Binding var prompt: PasscodeFlow?
    @Environment(\.modelContext) private var context
    @Environment(\.currentProfile) private var profile
    @Environment(\.showsAdultContent) private var shows
    @Query private var passcodes: [PasscodeRecord]

    var body: some View {
        Section {
            Toggle("Show adult content", isOn: binding)
                .settingsFooter(.adultContent(shows: shows))
                .accessibilityIdentifier("settings.adultContent")
        } footer: {
            #if !os(tvOS)
                Text(Self.footer(shows: shows))
                    .accessibilityIdentifier("settings.adultContent.footer")
            #endif
        }
    }

    /// The footer under the switch, or in the lead column on Apple TV.
    static func footer(shows: Bool) -> LocalizedStringResource {
        if shows { return "Adult content shows in this profile until you turn this off." }
        return "Adult groups, channels, movies and series are hidden in this profile. Showing them needs the group passcode."
    }

    private var binding: Binding<Bool> {
        Binding(
            get: { shows },
            set: { on in
                guard on else { return ProfileStore.setShowsAdult(profile, false, in: context) }
                prompt = PasscodeStore.current(passcodes) == nil ? .create : .unlock
            })
    }
}

extension View {
    /// The passcode prompt `AdultContentRow` asks for: a sheet on iPhone,
    /// iPad and Mac, a full-screen cover on Apple TV, as for the group
    /// locks. The right passcode turns adult content on for the current profile.
    func adultContentPrompt(_ flow: Binding<PasscodeFlow?>) -> some View {
        modifier(AdultPasscodePrompt(flow: flow))
    }
}

private struct AdultPasscodePrompt: ViewModifier {
    @Binding var flow: PasscodeFlow?
    @Environment(\.modelContext) private var context
    @Environment(\.currentProfile) private var profile

    func body(content: Content) -> some View {
        content
            #if os(tvOS)
                .fullScreenCover(item: $flow) { prompt($0) }
            #else
                .sheet(item: $flow) { prompt($0).interactiveDismissDisabled() }
            #endif
    }

    private func prompt(_ flow: PasscodeFlow) -> some View {
        PasscodePrompt(flow: flow, message: AdultPasscode.message(flow)) { done in
            self.flow = nil
            if done { ProfileStore.setShowsAdult(profile, true, in: context) }
        }
    }
}

/// What the passcode prompt says when it guards adult content.
enum AdultPasscode {
    static func message(_ flow: PasscodeFlow) -> LocalizedStringResource {
        if flow == .create { return "Set a passcode to show adult content. Locked groups use it too." }
        return "Enter the passcode to show adult content in this profile."
    }
}
