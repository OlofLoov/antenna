import AntennaCore
import SwiftUI

/// "Autoplay next episode" in a section of its own with its footer, on
/// iPhone, iPad and Mac (`iPhone-Settings`; up-next/turn-autoplay-off).
struct AutoplayRow: View {
    var body: some View {
        Section {
            AutoplayToggle()
        } footer: {
            Text(AutoplaySetting.footer)
        }
    }
}

/// The "Autoplay next episode" toggle. On Apple TV it sits in Preferences
/// and its footer shows in the lead column (`TV-Settings-Preferences`).
/// On until switched off, kept on this device only.
struct AutoplayToggle: View {
    @AppStorage(AutoplaySetting.key) private var stored = Data()

    var body: some View {
        Toggle("Autoplay next episode", isOn: plays)
            .accessibilityIdentifier("settings.autoplayNext")
    }

    private var plays: Binding<Bool> {
        Binding(
            get: { AutoplaySetting.decode(stored).plays },
            set: { stored = AutoplaySetting(plays: $0).encoded() ?? Data() })
    }
}
