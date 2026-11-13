#if os(tvOS)
    import AntennaCore
    import SwiftUI

    extension FocusedValues {
        /// The remote hints of the screen that holds focus, named by the
        /// screen with `controlHints(_:)` and read by the legend host.
        @Entry var controlHints: ControlHintScreen?
    }

    extension View {
        /// Names the remote hints for this screen while focus is inside it
        /// (control-hints/each-screen-lists-its-own-actions). Nil names none,
        /// so the legend hides.
        func controlHints(_ screen: ControlHintScreen?) -> some View {
            focusedValue(\.controlHints, screen)
        }

        /// Draws the remote hints legend over this view for whichever screen
        /// has focus. Applied once per window and once per full-screen cover.
        func controlHintsLegend() -> some View {
            modifier(ControlHintsHost())
        }
    }

    /// Shows the legend of the focused screen in its corner, inside the
    /// safe area, when the highlight reaches a new place, and fades it after
    /// a few seconds (control-hints/hints-fade-and-come-back-on-a-new-screen).
    /// Nothing shows while "Show remote hints" is off on this device
    /// (control-hints/turn-remote-hints-off).
    private struct ControlHintsHost: ViewModifier {
        @FocusedValue(\.controlHints) private var screen
        @AppStorage(ControlHintsSetting.key) private var stored = Data()
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var schedule = ControlHintSchedule()
        /// When the legend fades; nil while it is hidden.
        @State private var hideAt: ContinuousClock.Instant?

        private var shows: Bool { ControlHintsSetting.decode(stored).shows }

        func body(content: Content) -> some View {
            content
                .overlay {
                    if Self.holds || hideAt != nil, shows, let screen {
                        ControlHints.Legend(screen: screen)
                            .padding(Metrics.televisionSafeArea)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: screen.corner.alignment)
                            .ignoresSafeArea()
                            .transition(.opacity)
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: hideAt == nil)
                .task(id: screen) {
                    if schedule.arrive(at: screen) { hideAt = .now + ControlHintSchedule.visibleFor }
                }
                .task(id: hideAt) { await fade() }
                .onChange(of: shows) { _, on in
                    // Switching hints on shows the current screen's legend straight away.
                    if on { hideAt = .now + ControlHintSchedule.visibleFor }
                }
        }

        private func fade() async {
            guard let hideAt else { return }
            do {
                try await Task.sleep(until: hideAt, clock: .continuous)
                self.hideAt = nil
            } catch {
                // A later arrival moved the moment; its own task waits for it.
            }
        }

        /// The legend never fades in UI tests launched with `-ui-testing-hints`.
        private static var holds: Bool {
            #if DEBUG
                UITestingHints.holds
            #else
                false
            #endif
        }
    }

    extension ControlHintScreen.Corner {
        var alignment: Alignment {
            switch self {
            case .topTrailing: .topTrailing
            case .bottomTrailing: .bottomTrailing
            }
        }
    }
#endif
