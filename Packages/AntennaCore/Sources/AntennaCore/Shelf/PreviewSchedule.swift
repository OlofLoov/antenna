import Foundation

/// Which title the Apple TV preview shows, from the highlight's moves
/// (movies-and-series-browsing/preview-of-the-focused-title-on-apple-tv).
/// A title takes over the preview once the highlight has stayed on it for
/// `rest`; titles passed on the way never do. Holds no clock: the caller
/// passes the time of each event.
public struct PreviewSchedule: Sendable, Equatable {
    /// How long the highlight stays on a poster before the preview changes to it.
    public static let rest: Duration = .milliseconds(800)

    /// The title the preview shows, nil before anything has rested.
    public private(set) var shown: String?
    /// The focused title that has not rested yet, and since when.
    public private(set) var pending: String?
    private var since: Date?

    public init(shown: String? = nil) {
        self.shown = shown
    }

    /// The highlight moved onto `title` at `date`. The preview keeps its
    /// title until this one rests.
    public mutating func focused(_ title: String, at date: Date) {
        guard title != shown else {
            pending = nil
            since = nil
            return
        }
        pending = title
        since = date
    }

    /// The highlight left the posters: to the banner, the tab bar, a page,
    /// or a row without titles. The pending title is dropped.
    public mutating func left() {
        pending = nil
        since = nil
    }

    /// Shows `title` at once, for focus put back on a poster on the way
    /// back from its page. Returns the title, which may need asking about.
    @discardableResult
    public mutating func restored(_ title: String) -> String {
        shown = title
        pending = nil
        since = nil
        return title
    }

    /// Starts the preview on `title`, the banner's, when nothing has rested
    /// yet, so the first change fades from the banner title.
    public mutating func start(on title: String?) {
        if shown == nil { shown = title }
    }

    /// When the pending title will have rested, nil when nothing is pending.
    public var due: Date? {
        since.map { $0.addingTimeInterval(Self.seconds(Self.rest)) }
    }

    /// The pending title becomes the shown one once it has been focused for
    /// `rest` by `date`. Returns it, the title to ask the provider about,
    /// or nil when nothing changed.
    public mutating func check(at date: Date) -> String? {
        guard let pending, let due, date >= due else { return nil }
        shown = pending
        self.pending = nil
        since = nil
        return pending
    }

    private static func seconds(_ duration: Duration) -> TimeInterval {
        let parts = duration.components
        return TimeInterval(parts.seconds) + TimeInterval(parts.attoseconds) / 1e18
    }
}

/// Asks about one title at a time
/// (movies-and-series-browsing/title-details-are-asked-once-per-title).
/// A title that comes in while a request is out waits, replacing any title
/// already waiting, so a viewer resting on poster after poster sends one
/// request at a time and only for the latest.
public struct OneAtATime: Sendable, Equatable {
    /// The title being asked about.
    public private(set) var asking: String?
    /// The title to ask about when the current request finishes.
    public private(set) var waiting: String?

    public init() {}

    /// Returns `title` when it can be asked about now, nil when it waits.
    public mutating func ask(_ title: String) -> String? {
        guard asking != nil else {
            asking = title
            return title
        }
        if title != asking { waiting = title }
        return nil
    }

    /// The current request finished. Returns the waiting title, now being
    /// asked about, or nil when nothing waits.
    public mutating func finished() -> String? {
        asking = waiting
        waiting = nil
        return asking
    }
}

extension BannerText {
    /// The banner's words for the Apple TV preview. The eyebrow is the
    /// category alone, empty without one: the row header above the poster
    /// already names the row.
    public init(preview title: ShelfTitle, details: ShelfDetails?) {
        self.init(title, details: details)
        eyebrow = title.category ?? ""
    }
}
