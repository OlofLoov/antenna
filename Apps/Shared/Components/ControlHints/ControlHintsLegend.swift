#if os(tvOS)
    import AntennaCore
    import SwiftUI

    /// The remote hints legend (control-hints capability; `TV-Hints-Live`,
    /// `TV-Hints-Overlay`, `TV-Hints-Movies`): the Siri Remote, then one line
    /// per control with its glyph, its name and what it does here. It never
    /// takes focus, and VoiceOver reads it as one sentence.
    enum ControlHints {
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
            case .swipeLeftRight: "arrow.left.and.right"
            case .swipe: "arrow.up.and.down.and.arrow.left.and.right"
            case .playPause: "playpause"
            case .back: "chevron.backward"
            }
        }
    }

    private struct LegendSample: View {
        let screen: ControlHintScreen
        let alignment: Alignment

        var body: some View {
            ZStack(alignment: alignment) {
                Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255)
                ControlHints.Legend(screen: screen)
                    .padding(Metrics.televisionSafeArea)
            }
        }
    }

    #Preview("Remote hints, live picture", traits: .fixedLayout(width: 1920, height: 1080)) {
        LegendSample(screen: .livePicture(swipe: .changesChannel), alignment: .topTrailing)
    }

    #Preview("Remote hints, channel overlay", traits: .fixedLayout(width: 1920, height: 1080)) {
        LegendSample(screen: .overlayChannels, alignment: .bottomTrailing)
    }

    #Preview("Remote hints, movies", traits: .fixedLayout(width: 1920, height: 1080)) {
        LegendSample(screen: .titleRows(.movie), alignment: .bottomTrailing)
    }
#endif
