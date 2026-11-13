#if os(tvOS)
    import AntennaCore
    import SwiftUI

    /// "Show remote hints" in Settings on Apple TV (`TV-Settings-Hints`;
    /// control-hints/turn-remote-hints-off). On until switched off, kept on
    /// this device only.
    struct RemoteHintsRow: View {
        @AppStorage(ControlHintsSetting.key) private var stored = Data()

        var body: some View {
            Toggle("Show remote hints", isOn: shows)
                .accessibilityIdentifier("settings.remoteHints")
        }

        private var shows: Binding<Bool> {
            Binding(
                get: { ControlHintsSetting.decode(stored).shows },
                set: { stored = ControlHintsSetting(shows: $0).encoded() ?? Data() })
        }
    }
#endif
