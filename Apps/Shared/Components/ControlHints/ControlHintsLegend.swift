#if os(tvOS)
    import AntennaCore
    import SwiftUI

    /// The remote hints legend (control-hints capability; `TV-Hints-Live`,
    /// `TV-Hints-Overlay`, `TV-Hints-Movies`): the Siri Remote, then one line
    /// per control with its glyph, its name and what it does here. It never
    /// takes focus, and VoiceOver reads it as one sentence.
    enum ControlHints {
        /// Where the legend sits on every screen: top right inside the
        /// safe area, under the row the clock takes, so it never covers the
        /// clock, the info bar or the movie player's bar
        /// (control-hints/hints-stay-out-of-the-way).
        static let placement = EdgeInsets(
            top: Metrics.televisionSafeArea.top + clockRow, leading: Metrics.televisionSafeArea.leading,
            bottom: Metrics.televisionSafeArea.bottom, trailing: Metrics.televisionSafeArea.trailing)
        /// The clock's line and the gap under it.
        private static let clockRow: CGFloat = 64

        /// The legend in its one place over a full-screen layer.
        struct Placed: View {
            let screen: ControlHintScreen

            var body: some View {
                Legend(screen: screen)
                    .padding(ControlHints.placement)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }

        struct Legend: View {
            let screen: ControlHintScreen

            var body: some View {
                VStack(alignment: .leading, spacing: Metrics.Spacing.small) {
                    Label("Remote", systemImage: "appletvremote.gen4.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.textMuted)
                    Grid(alignment: .leading, horizontalSpacing: Metrics.Spacing.small, verticalSpacing: Metrics.Spacing.xSmall) {
                        // The glyph, the control's name and the action, in columns so the actions line up.
                        ForEach(screen.hints, id: \.self) { hint in
                            GridRow {
                                Image(systemName: hint.control.symbol)
                                    .font(.caption)
                                    .foregroundStyle(Palette.textMuted)
                                    .gridColumnAlignment(.center)
                                Text(hint.control.name)
                                    .font(.caption.weight(.semibold))
                                Text(hint.action)
                                    .font(.caption)
                                    .foregroundStyle(Palette.textMuted)
                            }
                        }
                    }
                }
                .padding(Metrics.Spacing.large)
                .background(Palette.scrimTint.opacity(0.82), in: Metrics.Corner.large.shape())
                .foregroundStyle(Palette.text)
                .fixedSize()
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(screen.spoken)
                .accessibilityIdentifier("hints.legend")
            }
        }
    }

    extension RemoteControl {
        /// The SF Symbol drawn next to the control's name.
        var symbol: String {
            switch self {
            case .click: "circle.circle"
            case .clickLeftRight: "arrowtriangle.left.and.line.vertical.and.arrowtriangle.right"
            case .hold: "hand.tap"
            case .swipeUpDown: "arrow.up.and.down"
            case .swipeDown: "arrow.down"
            case .swipeLeftRight: "arrow.left.and.right"
            case .swipe: "arrow.up.and.down.and.arrow.left.and.right"
            case .playPause: "playpause"
            case .back: "chevron.backward"
            }
        }
    }

    private struct LegendSample: View {
        let screen: ControlHintScreen

        var body: some View {
            ZStack {
                Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255)
                ControlHints.Placed(screen: screen)
            }
        }
    }

    #Preview("Remote hints, live picture", traits: .fixedLayout(width: 1920, height: 1080)) {
        LegendSample(screen: .livePicture(swipe: .changesChannel))
    }

    #Preview("Remote hints, channel overlay", traits: .fixedLayout(width: 1920, height: 1080)) {
        LegendSample(screen: .overlayChannels)
    }

    #Preview("Remote hints, movies", traits: .fixedLayout(width: 1920, height: 1080)) {
        LegendSample(screen: .titleRows(.movie))
    }
#endif
