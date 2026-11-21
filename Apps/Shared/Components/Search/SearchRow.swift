import AntennaCore
import SwiftUI

/// Search's own parts (boards `iPhone-Search`, `iPad-Search`, `TV-Search`):
/// the programme row, the bell, recent searches and the keyboard cursor.
/// Channels, posters and people are the rest of the app's components:
/// the Live list's row, the shelf's poster card and the title page's cast
/// chip. Each takes values and a closure; the screen decides what picking does.
enum SearchRow {
    /// Sizes per platform, read from the boards: the programme rows,
    /// headers and recent searches, and the chip sizes people take.
    struct Metrics: Sendable {
        var title: CGFloat
        var detail: CGFloat
        var lead: CGFloat
        var leadWidth: CGFloat
        var badge: CGFloat
        var programmeHeight: CGFloat
        var spacing: CGFloat
        var padding: CGFloat
        var corner: CGFloat
        var header: CGFloat
        var headerCount: CGFloat
        /// The cast chips a person result is drawn as.
        var chips: TitlePage.Sizes

        static let phone = Metrics(
            title: 14, detail: 12, lead: 12, leadWidth: 52, badge: 11, programmeHeight: 56, spacing: 12, padding: 10, corner: 10,
            header: 13, headerCount: 13, chips: .phone)
        static let pad = Metrics(
            title: 16, detail: 13, lead: 13, leadWidth: 64, badge: 11, programmeHeight: 56, spacing: 12, padding: 12, corner: 10,
            header: 17, headerCount: 13, chips: .pad)
        static let tv = Metrics(
            title: 24, detail: 18, lead: 20, leadWidth: 120, badge: 18, programmeHeight: 92, spacing: 18, padding: 16, corner: 14,
            header: 26, headerCount: 20, chips: .tv)
    }

    /// Text with the matched letters on the accent tint
    /// (search/results-grouped-best-first). The tint follows the text at any size.
    struct Highlighted: View {
        let text: String
        let ranges: [Range<String.Index>]
        @Environment(\.accent) private var accent

        var body: some View {
            Text(Self.attributed(text, ranges, accent: accent.color))
        }

        static func attributed(_ text: String, _ ranges: [Range<String.Index>], accent: Color) -> AttributedString {
            var attributed = AttributedString(text)
            for range in ranges {
                guard let lower = AttributedString.Index(range.lowerBound, within: attributed),
                    let upper = AttributedString.Index(range.upperBound, within: attributed)
                else { continue }
                attributed[lower..<upper].backgroundColor = accent.opacity(0.35)
            }
            return attributed
        }
    }

    /// A programme as the guide draws one (`iPhone-Guide`, `TV-Guide`): the
    /// guide's surface and small corner, NOW or its start, its title with
    /// the highlight, its channel with the times or the day, a clock arrow
    /// when it has catch-up, and the guide's progress bar along the foot of
    /// a programme on now. On Apple TV it takes the white focus card.
    struct Programme: View {
        /// The start time or day and time; nil shows the NOW badge.
        let lead: String?
        let title: String
        let ranges: [Range<String.Index>]
        let detail: String
        let hasCatchup: Bool
        /// How far into a programme on now, 0 to 1; nil draws no bar.
        var progress: Double?
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
                            GuideBoard.NowBadge(size: metrics.badge)
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
                .frame(maxWidth: .infinity, minHeight: metrics.programmeHeight * scale, alignment: .leading)
                .overlay(alignment: .bottom) {
                    if let progress {
                        GuideBoard.ProgressTrack(fraction: progress)
                    }
                }
                .clipShape(cornerShape(.small))
                .contentShape(cornerShape(.small))
            }
            .buttonStyle(FocusCardStyle(.small, resting: Palette.surface(0.08)))
            .modifier(CursorRing(shape: cornerShape(.small)))
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

    /// A recent search's look (design-system/controls-use-system-styles). On
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

    /// The keyboard cursor on iPad and Mac (search/search-with-a-keyboard):
    /// the Live list's 2 pt ring in the Text color with no fill
    /// (`iPad-Focus`), in the result's own shape.
    struct CursorRing<RingShape: InsettableShape>: ViewModifier {
        let shape: RingShape
        @Environment(\.searchCursor) private var cursor

        func body(content: Content) -> some View {
            content
                .overlay {
                    if cursor {
                        shape.strokeBorder(Palette.text, lineWidth: 2)
                    }
                }
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
