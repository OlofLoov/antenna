import SwiftUI

/// The parts of a multi-view tile and the words around the grid (boards
/// `TV-MultiView`, `TV-MultiView-Failed`, `TV-MultiView-Swap`,
/// `iPad-MultiView`). Each takes values only; the screen owns the session.
enum MultiViewParts {
    /// Sizes for the Apple TV screen and the Mac window.
    struct Metrics: Equatable {
        var number: CGFloat
        var name: CGFloat
        var glyph: CGFloat
        var labelHeight: CGFloat
        var labelInset: CGFloat
        var corner: CGFloat
        var ring: CGFloat
        var failedGlyph: CGFloat
        var failedTitle: CGFloat
        var failedBody: CGFloat
        var failedHint: CGFloat

        static let television = Metrics(
            number: 22, name: 26, glyph: 24, labelHeight: 52, labelInset: 20, corner: 14, ring: 44, failedGlyph: 44, failedTitle: 29,
            failedBody: 22, failedHint: 18)
        static let mac = Metrics(
            number: 13, name: 15, glyph: 16, labelHeight: 30, labelInset: 10, corner: 10, ring: 28, failedGlyph: 28, failedTitle: 15,
            failedBody: 13, failedHint: 12)
    }

    static let tileFill = Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255)
    static let secondary = Color(red: 0xD7 / 255, green: 0xDE / 255, blue: 0xE8 / 255)
    static let mutedOnCard = Color(red: 0x4B / 255, green: 0x55 / 255, blue: 0x63 / 255)

    /// Number, name and the sound glyph in the tile's bottom left: a dark
    /// card, white while the tile has the highlight.
    struct Label: View {
        let number: Int?
        let name: String
        let audible: Bool
        let highlighted: Bool
        /// `multiView.tile.<n>`; the glyph adds `.audio`.
        let identifier: String
        @Environment(\.multiViewMetrics) private var metrics

        var body: some View {
            HStack(spacing: metrics.labelInset * 0.7) {
                if let number {
                    Text(String(number))
                        .font(.system(size: metrics.number).monospacedDigit())
                        .foregroundStyle(highlighted ? MultiViewParts.mutedOnCard : Palette.textMuted)
                }
                Text(name)
                    .font(.system(size: metrics.name, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: audible ? "speaker.wave.2" : "speaker.slash")
                    .font(.system(size: metrics.glyph * 0.8))
                    .frame(width: metrics.glyph, height: metrics.glyph)
                    .foregroundStyle(highlighted ? Palette.ground : audible ? Palette.text : Palette.textMuted)
                    .accessibilityIdentifier("\(identifier).audio")
                    .accessibilityValue(audible ? "on" : "off")
            }
            .foregroundStyle(highlighted ? Palette.ground : Palette.text)
            .padding(.horizontal, metrics.labelInset * 0.9)
            .frame(height: metrics.labelHeight)
            .background(
                highlighted ? Palette.focus : Palette.scrimTint.opacity(0.88), in: RoundedRectangle(cornerRadius: metrics.corner - 2)
            )
            .padding(metrics.labelInset)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("\(identifier).label")
        }
    }

    /// The ring over a loading tile's last frame, with no caption.
    struct Waiting: View {
        @Environment(\.multiViewMetrics) private var metrics

        var body: some View {
            PlayerStatus.Ring(size: metrics.ring, stroke: metrics.ring / 11)
        }
    }

    /// A failed tile's glyph, title, explanation and hint, above the label.
    struct Failure<Action: View>: View {
        let title: String
        let explanation: String
        /// "Hold select for options" on Apple TV; nil on a Mac.
        let hint: String?
        let identifier: String
        @ViewBuilder var action: Action
        @Environment(\.multiViewMetrics) private var metrics

        var body: some View {
            VStack(spacing: metrics.failedBody * 0.6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: metrics.failedGlyph * 0.8))
                    .foregroundStyle(Palette.textMuted)
                Text(title)
                    .font(.system(size: metrics.failedTitle, weight: .semibold))
                    .accessibilityIdentifier("\(identifier).title")
                Text(explanation)
                    .font(.system(size: metrics.failedBody))
                    .foregroundStyle(MultiViewParts.secondary)
                    .accessibilityIdentifier("\(identifier).body")
                if let hint {
                    Text(hint)
                        .font(.system(size: metrics.failedHint))
                        .foregroundStyle(Palette.textMuted)
                }
                action
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, metrics.failedGlyph * 1.4)
            .padding(.bottom, metrics.labelHeight + metrics.labelInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(identifier)
        }
    }

    /// The keys and what they do, shown for a few seconds after entering
    /// on Apple TV. Never focusable.
    struct Hint: View {
        let keys: [(key: String, action: String)]

        var body: some View {
            HStack(spacing: 28) {
                ForEach(keys, id: \.key) { item in
                    Text("\(Text(item.key).fontWeight(.semibold).foregroundStyle(Palette.text)) \(item.action)")
                }
            }
            .font(.system(size: 24))
            .foregroundStyle(MultiViewParts.secondary)
            .padding(.horizontal, 28)
            .frame(height: 60)
            .background(Palette.scrimTint.opacity(0.88), in: Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("multiView.hint")
        }
    }

    /// "Multi-view · tile 2 of 4" over a full-screen tile.
    struct Badge: View {
        let text: String
        let hint: String

        var body: some View {
            HStack(spacing: 16) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 24))
                Text(text).fontWeight(.semibold)
                Text(hint).foregroundStyle(Palette.textMuted)
            }
            .font(.system(size: 24))
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 24)
            .frame(height: 60)
            .background(Palette.scrimTint.opacity(0.82), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("multiView.swapBadge")
        }
    }
}

extension EnvironmentValues {
    /// Multi-view's sizes; the Mac window sets `.mac`.
    @Entry var multiViewMetrics = MultiViewParts.Metrics.television
}

#Preview("Multi-view tile label, highlighted and audible", traits: .fixedLayout(width: 903, height: 507)) {
    MultiViewParts.Label(number: 104, name: "Sport One", audible: true, highlighted: true, identifier: "multiView.tile.2")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .background(MultiViewParts.tileFill)
}

#Preview("Multi-view tile label, muted", traits: .fixedLayout(width: 903, height: 507)) {
    MultiViewParts.Label(number: 101, name: "Eurosport 1", audible: false, highlighted: false, identifier: "multiView.tile.1")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .background(MultiViewParts.tileFill)
}

#Preview("Multi-view tile waiting", traits: .fixedLayout(width: 903, height: 507)) {
    MultiViewParts.Waiting()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MultiViewParts.tileFill)
}

#Preview("Multi-view tile failed", traits: .fixedLayout(width: 903, height: 507)) {
    MultiViewParts.Failure(
        title: "Your provider refused another stream", explanation: "Many providers allow one or two streams per account at a time.",
        hint: "Hold select for options", identifier: "multiView.tile.3.failed"
    ) {
        EmptyView()
    }
}

#Preview("Multi-view hint and badge", traits: .fixedLayout(width: 1920, height: 300)) {
    VStack(spacing: 40) {
        MultiViewParts.Hint(keys: [
            ("Select", "change channel"), ("Hold select", "options"), ("Play/Pause", "full screen"), ("Menu", "leave multi-view"),
        ])
        MultiViewParts.Badge(text: "Multi-view · tile 2 of 4", hint: "Play/Pause to return")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(MultiViewParts.tileFill)
}
