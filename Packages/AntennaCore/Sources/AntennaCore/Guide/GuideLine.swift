import Foundation

/// What a channel row says about its guide: the programme on now with its
/// progress and time left, or a short state line in its place
/// (tv-channel-overlay/each-channel-shows-what-is-on).
public enum GuideLine: Sendable, Equatable {
    case programme(title: String, progress: Double, remaining: String)
    /// No progress bar goes with a message.
    case message(String)

    public static let noProgramme = "No programme information"
    public static let loading = "Loading guide…"

    /// The programme covering `now`, else "Loading guide…" while the
    /// channel's guide has not loaded yet, else "No programme information".
    public init(state: GuideLoadingState, current: Programme?, now: Date) {
        if let current, current.start <= now, now < current.stop {
            self = .programme(
                title: current.title, progress: ProgrammeProgress.fraction(start: current.start, end: current.stop, now: now),
                remaining: RemainingTime.text(until: current.stop, now: now))
        } else if state == .loading {
            self = .message(Self.loading)
        } else {
            self = .message(Self.noProgramme)
        }
    }

    /// The title, or the state line.
    public var text: String {
        switch self {
        case .programme(let title, _, _): title
        case .message(let text): text
        }
    }
}

extension Channel {
    /// The catch-up mark's words: "CATCH-UP 7D" with a day count, "CATCH-UP"
    /// without one, nil for a channel with no catch-up.
    public var catchUpBadge: String? {
        if let days = catchupDays, days > 0 { return "CATCH-UP \(days)D" }
        return hasCatchup ? "CATCH-UP" : nil
    }
}
