import AntennaCore
import Foundation

/// The guide's words that depend on the user's language, clock format and
/// time zone. Views pass their `@Environment(\.locale)`.
struct GuideText {
    let locale: Locale

    private var words: Words { Words(locale) }

    func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
    }

    /// "20:00 – 22:00".
    func times(_ start: Date, _ stop: Date) -> String {
        "\(time(start)) – \(time(stop))"
    }

    /// The block's accessibility identifier from the board:
    /// `guide.block.<rowKey>.<start>`, `guide.gap.<rowKey>.<start>`, or
    /// `guide.loading`, `guide.noGuide` and `guide.failed` with the row
    /// key. The start is in seconds since 1970. Never the stream link.
    static func identifier(_ cell: GuideCell, key: RowKey) -> String {
        let row = key.identifier
        switch cell.placeholder {
        case .loading: return "guide.loading.\(row)"
        case .noGuide: return "guide.noGuide.\(row)"
        case .failed: return "guide.failed.\(row)"
        case nil:
            let start = Int(cell.start.timeIntervalSince1970)
            return cell.programme == nil ? "guide.gap.\(row).\(start)" : "guide.block.\(row).\(start)"
        }
    }

    /// What VoiceOver reads for a block: channel, title, times, and
    /// whether it is past, on now or still to come.
    func spoken(_ cell: GuideCell, channel: Channel, now: Date) -> String {
        if let placeholder = cell.placeholder { return words("\(channel.name), \(placeholder.text(locale))") }
        let title = cell.programme.map { GuidePanelText.title($0, locale: locale) } ?? GuideLine.noProgramme(locale)
        let timing =
            switch GuideTiming(start: cell.start, stop: cell.stop, now: now) {
            case .past: words("past")
            case .now: words("on now")
            case .future: words("later")
            }
        return words("\(channel.name), \(title), \(time(cell.start)) to \(time(cell.stop)), \(timing)")
    }

    /// The panel for the highlighted cell on `channel`
    /// (tv-guide-grid/the-panel-describes-the-highlighted-programme).
    /// `quality` is the picture size of the playing stream, given only
    /// for the playing channel.
    func details(
        _ cell: GuideCell, channel: Channel, timeline: GuideTimeline, now: Date, quality: String?
    ) -> GuidePanel.Details {
        if let placeholder = cell.placeholder {
            return GuidePanel.Details(eyebrow: channel.name, look: .other, title: placeholder.text(locale), meta: quality)
        }
        let onNow = cell.programme != nil && cell.segment.contains(now)
        let day = timeline.dayLabel(cell.start, today: now, locale: locale)
        let eyebrow =
            onNow ? words("Now · \(channel.name)") : words("\(day) \(time(cell.start)) · \(channel.name)")
        let meta = GuidePanelText.line([
            times(cell.start, cell.stop), GuidePanelText.length(from: cell.start, to: cell.stop, locale: locale), cell.programme?.category,
            quality,
        ])
        return GuidePanel.Details(
            eyebrow: eyebrow, look: onNow ? .now : .other,
            title: cell.programme.map { GuidePanelText.title($0, locale: locale) } ?? GuideLine.noProgramme(locale),
            meta: meta, progress: onNow ? ProgrammeProgress.fraction(start: cell.start, end: cell.stop, now: now) : nil,
            summary: cell.programme?.summary)
    }
}
