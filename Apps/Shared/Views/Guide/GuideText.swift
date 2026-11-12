import AntennaCore
import Foundation

/// The guide's words that depend on the user's clock format and time zone.
enum GuideText {
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "20:00 – 22:00".
    static func times(_ start: Date, _ stop: Date) -> String {
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
    static func spoken(_ cell: GuideCell, channel: Channel, now: Date) -> String {
        if let placeholder = cell.placeholder { return "\(channel.name), \(placeholder.text)" }
        let title = cell.programme.map(GuidePanelText.title) ?? GuideLine.noProgramme
        let timing: String =
            switch GuideTiming(start: cell.start, stop: cell.stop, now: now) {
            case .past: "past"
            case .now: "on now"
            case .future: "later"
            }
        return "\(channel.name), \(title), \(time(cell.start)) to \(time(cell.stop)), \(timing)"
    }

    /// The panel for the highlighted cell on `channel`
    /// (tv-guide-grid/the-panel-describes-the-highlighted-programme).
    /// `quality` is the picture size of the playing stream, given only
    /// for the playing channel.
    static func details(
        _ cell: GuideCell, channel: Channel, timeline: GuideTimeline, now: Date, quality: String?
    ) -> GuidePanel.Details {
        if let placeholder = cell.placeholder {
            return GuidePanel.Details(eyebrow: channel.name, look: .other, title: placeholder.text, meta: quality)
        }
        let onNow = cell.programme != nil && cell.segment.contains(now)
        let day = timeline.dayLabel(cell.start, today: now)
        let eyebrow = onNow ? "Now · \(channel.name)" : "\(day) \(time(cell.start)) · \(channel.name)"
        let meta = GuidePanelText.line([
            times(cell.start, cell.stop), GuidePanelText.length(from: cell.start, to: cell.stop), cell.programme?.category, quality,
        ])
        return GuidePanel.Details(
            eyebrow: eyebrow, look: onNow ? .now : .other, title: cell.programme.map(GuidePanelText.title) ?? GuideLine.noProgramme,
            meta: meta, progress: onNow ? ProgrammeProgress.fraction(start: cell.start, end: cell.stop, now: now) : nil,
            summary: cell.programme?.summary)
    }
}
