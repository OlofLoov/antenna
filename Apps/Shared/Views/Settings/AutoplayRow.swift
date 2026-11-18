import AntennaCore
import SwiftUI

/// "Autoplay next episode" in Settings on every platform (`iPhone-Settings`,
/// `TV-Settings-Hints`; up-next/turn-autoplay-off). On until switched off,
/// kept on this device only.
struct AutoplayRow: View {
    @AppStorage(AutoplaySetting.key) private var stored = Data()

    var body: some View {
        Section {
            Toggle("Autoplay next episode", isOn: plays)
                .accessibilityIdentifier("settings.autoplayNext")
        } footer: {
            Text(AutoplaySetting.footer)
        }
    }

    private var plays: Binding<Bool> {
        Binding(
            get: { AutoplaySetting.decode(stored).plays },
            set: { stored = AutoplaySetting(plays: $0).encoded() ?? Data() })
    }
}
