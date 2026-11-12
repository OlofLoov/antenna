import Foundation

/// How Start over can play the programme on air now
/// (timeshift-catch-up-and-start-over/start-over-shows-only-when-it-can-work).
public enum StartOverPlan: Sendable, Equatable {
    /// Catch-up from the provider at this address, from the programme's start.
    case catchup(URL, Programme)
    /// The local buffer, which reaches back to the programme's start.
    case buffer(Programme)
    /// Start over is hidden.
    case none

    public var programme: Programme? {
        switch self {
        case .catchup(_, let programme), .buffer(let programme): programme
        case .none: nil
        }
    }

    /// True when Start over shows.
    public var isAvailable: Bool { self != .none }
}

/// Decides whether Start over shows and how it plays: catch-up first, the
/// buffer second, and only for the channel playing and a programme on air.
public enum StartOverPlanner {
    /// - `channel` is the one the overlay or strip describes; `playing` the one on screen.
    /// - `programme` is the one on air at `now` on `channel`, nil without guide data.
    /// - `window` is what the buffer holds, nil without one.
    /// - `catchupURL` builds the catch-up address for a request, nil when none can be built.
    public static func plan(
        channel: Channel, playing: Channel?, programme: Programme?, now: Date, window: TimeshiftWindow?,
        catchupURL: (CatchupRequest) -> URL?
    ) -> StartOverPlan {
        guard channel.id == playing?.id, channel.sourceID == playing?.sourceID, let programme, programme.start <= now, now < programme.stop
        else { return .none }
        let request = CatchupRequest(start: programme.start, duration: programme.stop.timeIntervalSince(programme.start), now: now)
        if let url = catchupURL(request) { return .catchup(url, programme) }
        if let window, window.start <= programme.start { return .buffer(programme) }
        return .none
    }
}
