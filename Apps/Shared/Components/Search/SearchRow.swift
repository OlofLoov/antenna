import AntennaCore
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
            posterName: 20, header: 26, headerCount: 20)
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
                        .clipShape(cornerShape(.small))
                    VStack(alignment: .leading, spacing: 3) {
                        Highlighted(text: name, ranges: nameRanges)
                            .font(.boardStyle(metrics.title))
                            .lineLimit(1)
                        Highlighted(text: detail, ranges: detailRanges)
                            .font(.boardStyle(metrics.detail))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, metrics.padding)
                .frame(minHeight: metrics.channelHeight * scale)
                .contentShape(Rectangle())
            }
            .modifier(RowLook())
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
                                .font(.boardStyle(metrics.lead).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        } else {
                            NowBadge()
                        }
                    }
                    .frame(width: metrics.leadWidth, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Highlighted(text: title, ranges: ranges)
                            .font(.boardStyle(metrics.title))
                            .lineLimit(1)
                        Text(detail)
                            .font(.boardStyle(metrics.detail))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if hasCatchup {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.boardStyle(metrics.detail))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, metrics.padding)
                .frame(minHeight: metrics.programmeHeight * scale)
                .contentShape(Rectangle())
            }
            .modifier(RowLook())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spoken)
            .accessibilityAddTraits(.isButton)
        }

        private var spoken: LocalizedStringResource {
            let when: LocalizedStringResource = lead.map { .verbatim($0) } ?? "Now"
            return hasCatchup ? "In the guide, \(title), \(when) \(detail), catch-up" : "In the guide, \(title), \(when) \(detail)"
        }
    }

    /// The bell at the end of a later programme's row on iPhone, iPad and
    /// Mac: sets or removes its reminder without opening anything
    /// (search/pick-a-programme, programme-reminders/set-a-reminder-in-one-tap).
    struct Bell: View {
        let isSet: Bool
        let toggle: () -> Void
        @Environment(\.searchMetrics) private var metrics
        @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

        var body: some View {
            Button(action: toggle) {
                Image(systemName: isSet ? "bell.fill" : "bell")
                    .font(.boardStyle(metrics.title))
                    .foregroundStyle(isSet ? Palette.text : Palette.textMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSet ? ReminderText.reminderSet() : ReminderText.remindMe())
            .accessibilityAddTraits(isSet ? .isSelected : [])
        }
    }

    /// The accent NOW badge.
    struct NowBadge: View {
        @Environment(\.searchMetrics) private var metrics
        /// Grows with the text size, so rows and highlights follow large text.
        @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

        var body: some View {
            Text("NOW")
                .font(.boardStyle(metrics.badge, weight: .bold))
                .letterSpacing(1)
                .foregroundStyle(Palette.ground)
                .padding(.horizontal, metrics.badge * 0.6)
                .padding(.vertical, 3)
                .background(Palette.accent, in: cornerShape(.small))
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
                                    .font(.boardStyle(metrics.badge, weight: .bold))
                                    .letterSpacing(1)
                                    .foregroundStyle(Palette.text)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Palette.scrimTint.opacity(0.72), in: cornerShape(.small))
                                    .padding(8)
                            }
                        }
                    Highlighted(text: name, ranges: ranges)
                        .font(.boardStyle(metrics.posterName))
                        .lineLimit(1)
                        .frame(width: metrics.poster.width, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .posterButtonStyle()
            .modifier(PosterCursor())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isSeries ? "Movies & series, \(name), series" : "Movies & series, \(name)")
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
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(text)
                        .font(.boardStyle(metrics.title))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, metrics.padding)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .modifier(RowLook())
            .accessibilityLabel("Recent search, \(text)")
        }
    }

    /// A result row's look (design-system/controls-use-system-styles). On
    /// Apple TV the row is a bordered button, which rests translucent and
    /// takes the light platter with dark text when focused. Elsewhere it is
    /// borderless on the row surface, brighter under the keyboard cursor.
    struct RowLook: ViewModifier {
        @Environment(\.searchMetrics) private var metrics
        @Environment(\.searchCursor) private var cursor

        func body(content: Content) -> some View {
            #if os(tvOS)
                content
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: metrics.corner))
            #else
                content
                    .buttonStyle(.borderless)
                    .tint(Palette.text)
                    .background(Palette.surface(cursor ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: metrics.corner))
            #endif
        }
    }

    /// The keyboard cursor on a poster on iPad and Mac (search/search-with-a-keyboard).
    struct PosterCursor: ViewModifier {
        @Environment(\.searchCursor) private var cursor

        func body(content: Content) -> some View {
            content
                .overlay {
                    if cursor {
                        posterCursorShape.stroke(Palette.text, lineWidth: 3).padding(-5)
                    }
                }
        }
    }
}

extension EnvironmentValues {
    /// The sizes Search's rows use; each platform's screen sets its own.
    @Entry var searchMetrics: SearchRow.Metrics = .pad
    /// True on the row the arrow keys are on (search/search-with-a-keyboard).
    @Entry var searchCursor = false
}

/// Read here because `SearchRow.Metrics` hides the app-wide `Metrics` inside the enum.
private let posterCursorShape = Metrics.Corner.medium.shape()
