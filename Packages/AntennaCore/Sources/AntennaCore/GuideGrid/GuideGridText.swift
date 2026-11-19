import Foundation

/// What a guide row shows in place of programmes
/// (tv-guide-grid/channels-without-a-guide-say-so): one block across the
/// window with the wording the channel overlay and info bar use.
public enum GuidePlaceholder: Sendable, Equatable {
    case loading
    case noGuide
    case failed

    /// Nil for a guide that has loaded programmes for the channel; the row
    /// then shows them, or `.noGuide` when none falls in the window.
    public init?(state: GuideLoadingState) {
        switch state {
        case .loaded: return nil
        case .loading: self = .loading
        case .noData, .unavailable: self = .noGuide
        case .failed: self = .failed
        }
    }

    /// "Loading guide…", "No programme information" or "Guide unavailable".
    public var text: String { text(.autoupdatingCurrent) }

    public func text(_ locale: Locale) -> String {
        switch self {
        case .loading: GuideLine.loading(locale)
        case .noGuide: GuideLine.noProgramme(locale)
        case .failed: ZapBarText.guideUnavailable(locale)
        }
    }
}

/// The guide panel's words (tv-guide-grid/the-panel-describes-the-highlighted-programme).
public enum GuidePanelText {
    /// The title, or "Untitled" when it is blank.
    public static func title(_ programme: Programme, locale: Locale = .autoupdatingCurrent) -> String {
        let title = programme.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? Words(locale)("Untitled") : title
    }

    /// How long from `start` to `stop`, as the info bar counts time left
    /// without the "left": "2 h", "1 h 30 min", "30 min". Minutes round up;
    /// anything shorter than a minute reads "1 min".
    public static func length(from start: Date, to stop: Date, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        let minutes = max(1, Int((stop.timeIntervalSince(start) / 60).rounded(.up)))
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return words("\(rest) min") }
        return rest == 0 ? words("\(hours) h") : words("\(hours) h \(rest) min")
    }

    /// The parts that are there, joined with " · ".
    public static func line(_ parts: [String?], locale: Locale = .autoupdatingCurrent) -> String {
        parts.compactMap { $0?.isEmpty == false ? $0 : nil }.joinedAsDetail(locale)
    }
}
