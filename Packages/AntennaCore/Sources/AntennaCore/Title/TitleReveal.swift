import Foundation

/// What a title page shows while its details load
/// (title-detail-and-episode-picker/the-page-shows-in-one-go). The page
/// stays hidden until the details arrive or fail, then shows in one go.
/// A load that takes longer than `delay` shows the mark tuning meanwhile,
/// and Got it once the wait is over.
public enum TitleReveal: Sendable, Hashable {
    /// Loading for less than `delay`: the ground alone, so a fast load
    /// never flashes the mark.
    case waiting
    /// Loading for longer: the mark tunes.
    case tuning
    /// The details are in after the mark showed: Got it, then the page.
    case gotIt
    /// The page, with everything known.
    case page

    /// How long a load runs before the mark shows.
    public static let delay = Duration.milliseconds(300)

    /// The stage a page opens in: the page at once when the details are
    /// already known.
    public static func opening(loading: Bool) -> TitleReveal {
        loading ? .waiting : .page
    }

    /// `delay` passed and the details are still on their way.
    public func delayPassed() -> TitleReveal {
        self == .waiting ? .tuning : self
    }

    /// The details arrived or failed: the page, through Got it if the mark
    /// was showing.
    public func loaded() -> TitleReveal {
        switch self {
        case .waiting, .page: .page
        case .tuning, .gotIt: .gotIt
        }
    }

    /// Got it played its part.
    public func gotItPlayed() -> TitleReveal {
        self == .gotIt ? .page : self
    }

    /// Loading started again, as Retry does: a shown page stays, since it
    /// shows its own loading line, and so does the mark.
    public func loadingAgain() -> TitleReveal {
        self == .gotIt ? .page : self
    }

    public var showsPage: Bool { self == .page }

    /// The mark's moment, nil while it is hidden.
    public var moment: MarkMoment? {
        switch self {
        case .waiting, .page: nil
        case .tuning: .tuning
        case .gotIt: .gotIt
        }
    }

    /// How long Got it plays before the page fades in over it: half the
    /// moment, so the page waits at most 0.6 s for the mark.
    public static func gotItHold(reduceMotion: Bool) -> Double {
        (MarkMotion.duration(.gotIt, reduceMotion: reduceMotion) ?? 0) / 2
    }
}
