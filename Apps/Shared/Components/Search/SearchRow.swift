import SwiftUI

/// Search's result rows, recent searches and section parts (boards
/// `iPhone-Search`, `iPad-Search`, `TV-Search`). Each takes values and a
/// closure; the screen decides what picking does.
enum SearchRow {
    /// Sizes per platform, read from the boards.
    struct Metrics: Sendable {
        var title: CGFloat
        var detail: CGFloat
        var lead: CGFloat
        var leadWidth: CGFloat
        var badge: CGFloat
        var logo: CGSize
        var initials: CGFloat
        var channelHeight: CGFloat
        var programmeHeight: CGFloat
        var spacing: CGFloat
        var padding: CGFloat
        var corner: CGFloat
        var poster: CGSize
        var posterName: CGFloat
        var header: CGFloat
        var headerCount: CGFloat
        /// Apple TV lifts the focused row as a white card; touch platforms tint it.
        var liftsOnFocus = false

        static let phone = Metrics(
            title: 15, detail: 12, lead: 12, leadWidth: 52, badge: 10, logo: CGSize(width: 52, height: 34), initials: 11,
            channelHeight: 56, programmeHeight: 56, spacing: 12, padding: 8, corner: 10, poster: CGSize(width: 108, height: 162),
            posterName: 13, header: 13, headerCount: 13)
        static let pad = Metrics(
            title: 16, detail: 13, lead: 13, leadWidth: 64, badge: 11, logo: CGSize(width: 56, height: 36), initials: 12,
            channelHeight: 66, programmeHeight: 54, spacing: 12, padding: 12, corner: 10, poster: CGSize(width: 132, height: 198),
            posterName: 14, header: 17, headerCount: 13)
        static let tv = Metrics(
            title: 24, detail: 18, lead: 20, leadWidth: 120, badge: 18, logo: CGSize(width: 84, height: 56), initials: 18,
            channelHeight: 112, programmeHeight: 76, spacing: 18, padding: 20, corner: 14, poster: CGSize(width: 180, height: 270),
            posterName: 20, header: 26, headerCount: 20, liftsOnFocus: true)
    }

    /// Text with the matched letters on the accent tint
    /// (search/results-grouped-best-first). The tint follows the text at any size.
    struct Highlighted: View {
        let text: String
        let ranges: [Range<String.Index>]

        var body: some View {
            Text(Self.attributed(text, ranges))
        }

        static func attributed(_ text: String, _ ranges: [Range<String.Index>]) -> AttributedString {
            var attributed = AttributedString(text)
            for range in ranges {
                guard let lower = AttributedString.Index(range.lowerBound, within: attributed),
                    let upper = AttributedString.Index(range.upperBound, within: attributed)
                else { continue }
                attributed[lower..<upper].backgroundColor = Palette.accent.opacity(0.35)
            }
            return attributed
        }
    }

    /// A channel: logo or initials, the name with its highlight, and a
    /// muted line with the number and what is on, or the group it matched.
    struct Channel: View {
        let name: String
        let nameRanges: [Range<String.Index>]
        let detail: String
        let detailRanges: [Range<String.Index>]
        let initials: String
        let logo: URL?
        let select: () -> Void
        @Environment(\.searchMetrics) private var metrics
        /// Grows with the text size, so rows and highlights follow large text.
        @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

        var body: some View {
            Button(action: select) {
                HStack(spacing: metrics.spacing) {
                    Browse.Logo(url: logo, initials: initials, isSelected: false)
                        .frame(width: metrics.logo.width, height: metrics.logo.height)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 3) {
                        Highlighted(text: name, ranges: nameRanges)
                            .font(.system(size: metrics.title * scale))
                            .lineLimit(1)
                        Highlighted(text: detail, ranges: detailRanges)
                            .font(.system(size: metrics.detail * scale))
                            .foregroundStyle(Palette.textMuted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, metrics.padding)
                .frame(minHeight: metrics.channelHeight * scale)
                .contentShape(Rectangle())
            }
            .buttonStyle(RowStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Channels, \(name), \(detail)")
            .accessibilityAddTraits(.isButton)
        }
    }

    /// A programme: NOW or its start, its title with the highlight, and its
    /// channel with the times or the day; a clock arrow when it has catch-up.
    struct Programme: View {
        /// The start time or day and time; nil shows the NOW badge.
        let lead: String?
        let title: String
        let ranges: [Range<String.Index>]
        let detail: String
        let hasCatchup: Bool
        let select: () -> Void
        @Environment(\.searchMetrics) private var metrics
        /// Grows with the text size, so rows and highlights follow large text.
        @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

        var body: some View {
            Button(action: select) {
                HStack(spacing: metrics.spacing) {
                    Group {
                        if let lead {
                            Text(lead)
                                .font(.system(size: metrics.lead * scale).monospacedDigit())
                                .foregroundStyle(Browse.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        } else {
                            NowBadge()
                        }
                    }
                    .frame(width: metrics.leadWidth, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Highlighted(text: title, ranges: ranges)
                            .font(.system(size: metrics.title * scale))
                            .lineLimit(1)
                        Text(detail)
                            .font(.system(size: metrics.detail * scale))
                            .foregroundStyle(Palette.textMuted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if hasCatchup {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: metrics.detail * scale))
                            .foregroundStyle(Palette.textMuted)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, metrics.padding)
                .frame(minHeight: metrics.programmeHeight * scale)
                .contentShape(Rectangle())
            }
            .buttonStyle(RowStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("In the guide, \(title), \(lead ?? "Now") \(detail)\(hasCatchup ? ", catch-up" : "")")
            .accessibilityAddTraits(.isButton)
        }
    }

    /// The accent NOW badge.
    struct NowBadge: View {
        @Environment(\.searchMetrics) private var metrics
        /// Grows with the text size, so rows and highlights follow large text.
        @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

        var body: some View {
            Text("NOW")
                .font(.system(size: metrics.badge * scale, weight: .bold))
                .tracking(1)
                .foregroundStyle(Palette.ground)
                .padding(.horizontal, metrics.badge * 0.6)
                .padding(.vertical, 3)
                .background(Palette.accent, in: RoundedRectangle(cornerRadius: 5))
        }
    }

    /// A movie or series: the poster, or its name on a tile, SERIES on a
    /// series, and the name with its highlight underneath.
    struct Title<Poster: View>: View {
        let name: String
        let ranges: [Range<String.Index>]
        let isSeries: Bool
        let select: () -> Void
        @ViewBuilder var poster: Poster
        @Environment(\.searchMetrics) private var metrics
        /// Grows with the text size, so rows and highlights follow large text.
        @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

        var body: some View {
            Button(action: select) {
                VStack(alignment: .leading, spacing: 6) {
                    poster
                        .frame(width: metrics.poster.width, height: metrics.poster.height)
                        .overlay(alignment: .topLeading) {
                            if isSeries {
                                Text("SERIES")
                                    .font(.system(size: metrics.badge * scale, weight: .bold))
                                    .tracking(1)
                                    .foregroundStyle(Palette.text)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Palette.scrimTint.opacity(0.72), in: RoundedRectangle(cornerRadius: 4))
                                    .padding(8)
                            }
                        }
                    Highlighted(text: name, ranges: ranges)
                        .font(.system(size: metrics.posterName * scale))
                        .lineLimit(1)
                        .frame(width: metrics.poster.width, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PosterStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Movies & series, \(name)\(isSeries ? ", series" : "")")
            .accessibilityAddTraits(.isButton)
        }
    }

    /// One recent search; picking it runs it again (search/recent-searches).
    struct Recent: View {
        let text: String
        let select: () -> Void
        @Environment(\.searchMetrics) private var metrics
        /// Grows with the text size, so rows and highlights follow large text.
        @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

        var body: some View {
            Button(action: select) {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(Palette.textMuted)
                        .accessibilityHidden(true)
                    Text(text)
                        .font(.system(size: metrics.title * scale))
                        .foregroundStyle(Browse.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, metrics.padding)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(RowStyle())
            .accessibilityLabel("Recent search, \(text)")
        }
    }

    /// Touch platforms tint the pressed row; Apple TV lifts the focused one
    /// as a white card (design-system/focus-is-the-lifted-white-card).
    struct RowStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            RowLabel(label: configuration.label, isPressed: configuration.isPressed)
        }
    }

    private struct RowLabel<Label: View>: View {
        let label: Label
        let isPressed: Bool
        @Environment(\.isFocused) private var isFocused
        @Environment(\.searchMetrics) private var metrics
        @Environment(\.searchCursor) private var cursor

        var body: some View {
            let lifted = isFocused && metrics.liftsOnFocus
            label
                .foregroundStyle(lifted ? Palette.ground : Palette.text)
                .background(
                    RoundedRectangle(cornerRadius: metrics.corner)
                        .fill(lifted ? Palette.focus : Palette.surface(isPressed || cursor ? 0.12 : 0.06))
                )
                .shadow(color: lifted ? Palette.focusShadow : .clear, radius: 16, y: 12)
                .scaleEffect(lifted ? 1.03 : 1)
                .animation(.easeOut(duration: 0.15), value: lifted)
        }
    }

    private struct PosterStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            PosterLabel(label: configuration.label, isPressed: configuration.isPressed)
        }
    }

    private struct PosterLabel<Label: View>: View {
        let label: Label
        let isPressed: Bool
        @Environment(\.isFocused) private var isFocused
        @Environment(\.searchCursor) private var cursor

        var body: some View {
            label
                .foregroundStyle(Palette.text)
                .scaleEffect(isFocused ? 1.06 : 1)
                .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 16, y: 12)
                .opacity(isPressed ? 0.7 : 1)
                .overlay {
                    if cursor {
                        RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.text, lineWidth: 3).padding(-4)
                    }
                }
                .animation(.easeOut(duration: 0.15), value: isFocused)
        }
    }
}

extension EnvironmentValues {
    /// The sizes Search's rows use; each platform's screen sets its own.
    @Entry var searchMetrics: SearchRow.Metrics = .pad
    /// True on the row the arrow keys are on (search/search-with-a-keyboard).
    @Entry var searchCursor = false
}
