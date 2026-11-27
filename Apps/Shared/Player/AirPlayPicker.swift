#if os(iOS) || os(macOS)
    import AntennaCore
    import AVKit
    import SwiftUI

    /// The system's AirPlay button, which lists the devices the stream can
    /// go to (player-controls-and-playback-errors/extra-buttons-on-iphone-ipad-and-mac).
    /// 44 pt, in the text color. `opened` and `closed` run as the list opens
    /// and closes; `attach` gets the button before it shows, so a Mac can
    /// name the player it routes.
    struct AirPlayPicker: View {
        var opened: () -> Void = {}
        var closed: () -> Void = {}
        var attach: (AVRoutePickerView) -> Void = { _ in }

        var body: some View {
            RoutePicker(opened: opened, closed: closed, attach: attach)
                .frame(width: 44, height: 44)
                .accessibilityLabel("AirPlay")
                .accessibilityIdentifier("player.airplay")
        }
    }

    /// The AirPlay button where the stream cannot go to AirPlay: it looks
    /// like the system's and says why on press
    /// (playback-engine/a-source-whose-hls-failed-cannot-airplay).
    struct AirPlayRefusedButton: View {
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: "airplayvideo")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("AirPlay")
            .accessibilityIdentifier("player.airplay")
        }
    }

    /// Forwards the list's opening and closing.
    @MainActor private final class RouteListDelegate: NSObject, @MainActor AVRoutePickerViewDelegate {
        var opened: () -> Void = {}
        var closed: () -> Void = {}

        func routePickerViewWillBeginPresentingRoutes(_ routePickerView: AVRoutePickerView) {
            opened()
        }

        func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) {
            closed()
        }
    }

    #if os(iOS)
        private struct RoutePicker: UIViewRepresentable {
            let opened: () -> Void
            let closed: () -> Void
            let attach: (AVRoutePickerView) -> Void

            func makeCoordinator() -> RouteListDelegate { RouteListDelegate() }

            func makeUIView(context: Context) -> AVRoutePickerView {
                let view = AVRoutePickerView()
                view.tintColor = UIColor(Palette.text)
                view.activeTintColor = UIColor(context.environment.accent.color)
                view.prioritizesVideoDevices = true
                view.delegate = context.coordinator
                return view
            }

            func updateUIView(_ view: AVRoutePickerView, context: Context) {
                view.activeTintColor = UIColor(context.environment.accent.color)
                context.coordinator.opened = opened
                context.coordinator.closed = closed
                attach(view)
            }
        }
    #else
        private struct RoutePicker: NSViewRepresentable {
            let opened: () -> Void
            let closed: () -> Void
            let attach: (AVRoutePickerView) -> Void

            func makeCoordinator() -> RouteListDelegate { RouteListDelegate() }

            func makeNSView(context: Context) -> AVRoutePickerView {
                let view = AVRoutePickerView()
                view.setRoutePickerButtonColor(NSColor(Palette.text), for: .normal)
                view.setRoutePickerButtonColor(NSColor(context.environment.accent.color), for: .active)
                view.delegate = context.coordinator
                return view
            }

            func updateNSView(_ view: AVRoutePickerView, context: Context) {
                view.setRoutePickerButtonColor(NSColor(context.environment.accent.color), for: .active)
                context.coordinator.opened = opened
                context.coordinator.closed = closed
                attach(view)
            }
        }
    #endif

    #Preview("AirPlay buttons") {
        HStack {
            AirPlayPicker()
            AirPlayRefusedButton {}
        }
        .foregroundStyle(Palette.text)
        .padding()
        .background(Palette.ground)
    }
#endif
