#if os(iOS) || os(macOS)
    import AVKit
    import SwiftUI

    /// The system's AirPlay button, which lists the devices the stream can
    /// go to (player-controls-and-playback-errors/extra-buttons-on-iphone-ipad-and-mac).
    /// 44 pt, in the text color.
    struct AirPlayPicker: View {
        var body: some View {
            RoutePicker()
                .frame(width: 44, height: 44)
                .accessibilityLabel("AirPlay")
                .accessibilityIdentifier("player.airplay")
        }
    }

    #if os(iOS)
        private struct RoutePicker: UIViewRepresentable {
            func makeUIView(context: Context) -> AVRoutePickerView {
                let view = AVRoutePickerView()
                view.tintColor = UIColor(Palette.text)
                view.activeTintColor = UIColor(Palette.accent)
                view.prioritizesVideoDevices = true
                return view
            }

            func updateUIView(_ view: AVRoutePickerView, context: Context) {}
        }
    #else
        private struct RoutePicker: NSViewRepresentable {
            func makeNSView(context: Context) -> AVRoutePickerView {
                let view = AVRoutePickerView()
                view.setRoutePickerButtonColor(NSColor(Palette.text), for: .normal)
                view.setRoutePickerButtonColor(NSColor(Palette.accent), for: .active)
                return view
            }

            func updateNSView(_ view: AVRoutePickerView, context: Context) {}
        }
    #endif
#endif
