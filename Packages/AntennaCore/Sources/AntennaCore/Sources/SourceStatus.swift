import Foundation

/// How one source is doing on this device, for its row and its details in
/// Sources and Settings (sources-and-settings/see-how-each-source-is-doing).
/// Holds counts and times only, never a link or a login.
public struct SourceStatus: Equatable, Sendable {
    public enum Load: Equatable, Sendable {
        /// Not asked to load yet in this run of the app.
        case idle
        case loading
        case loaded
        /// The last load failed with this sentence.
        case failed(String)
        /// An Xtream source whose login is not on this device.
        case waitingForLogin
        /// A record that synced without its link.
        case waitingForICloud
        /// A Stalker portal, which loads nothing yet.
        case unsupported
    }

    public enum Guide: Equatable, Sendable {
        /// The source names no guide.
        case none
        case notStarted
        case downloading
        case loaded(days: Int, matched: Int, total: Int)
        case failed
    }

    public var load: Load
    /// From the last load that worked in this run, nil before one.
    public var channels: Int?
    public var groups: Int?
    /// When a load last worked on this device, kept across launches.
    public var lastSuccess: Date?
    public var guide: Guide
    /// The last guide that loaded in this run, kept when a later one fails.
    public var lastGuideDays: Int?

    public init(
        load: Load = .idle, channels: Int? = nil, groups: Int? = nil, lastSuccess: Date? = nil, guide: Guide = .notStarted,
        lastGuideDays: Int? = nil
    ) {
        self.load = load
        self.channels = channels
        self.groups = groups
        self.lastSuccess = lastSuccess
        self.guide = guide
        self.lastGuideDays = lastGuideDays
    }
}

/// The status lines' wording, from the change's copy tables.
public struct SourceStatusText: Sendable {
    /// One status line and how it is drawn.
    public struct Line: Equatable, Sendable {
        public enum Style: Equatable, Sendable { case normal, muted, error }
        public var text: String
        public var style: Style
        /// Draws the indeterminate indicator beside it.
        public var busy: Bool

        public init(_ text: String, style: Style = .normal, busy: Bool = false) {
            self.text = text
            self.style = style
            self.busy = busy
        }
    }

    public var locale: Locale
    /// True on Apple TV, which words the missing login differently.
    public var television: Bool

    public init(locale: Locale = .current, television: Bool = false) {
        self.locale = locale
        self.television = television
    }

    private var setup: SetupText { SetupText(locale: locale) }

    /// "12 minutes ago", "yesterday".
    public func relative(_ date: Date, now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }

    /// The row's lines: the first always, the second only after a failed refresh.
    public func rowLines(_ status: SourceStatus, now: Date) -> [Line] {
        switch status.load {
        case .waitingForLogin:
            return [Line(television ? "Not signed in on this Apple TV" : "Waiting for login from iCloud", style: .muted)]
        case .waitingForICloud:
            return [Line("Waiting for iCloud…", style: .muted)]
        case .unsupported:
            return [Line("Stalker portals are coming later", style: .muted)]
        case .idle, .loading:
            if let channels = status.channels, status.load == .loading {
                return [Line("\(count(channels)) · Refreshing…", busy: true)]
            }
            if let channels = status.channels {
                return [loadedLine(channels, status, now: now)]
            }
            if let last = status.lastSuccess {
                return [Line("Loading… · last loaded \(relative(last, now: now))", busy: true)]
            }
            return [Line("Loading…", busy: true)]
        case .loaded:
            return [loadedLine(status.channels ?? 0, status, now: now)]
        case .failed(let sentence):
            guard let channels = status.channels else { return [Line(sentence, style: .error)] }
            return [loadedLine(channels, status, now: now), Line("Could not refresh: \(sentence)", style: .error)]
        }
    }

    /// "412 channels · Guide 7 days · 12 minutes ago".
    private func loadedLine(_ channels: Int, _ status: SourceStatus, now: Date) -> Line {
        let parts = [count(channels), guidePart(status), status.lastSuccess.map { relative($0, now: now) }]
        return Line(parts.compactMap(\.self).joined(separator: " · "))
    }

    /// "412 channels", or "1 channel".
    public func count(_ channels: Int) -> String {
        channels == 1 ? "1 channel" : "\(setup.count(channels)) channels"
    }

    public func guidePart(_ status: SourceStatus) -> String {
        switch status.guide {
        case .none: "No guide"
        case .notStarted: "Loading guide…"
        case .downloading: "Downloading guide…"
        case .loaded(let days, _, _): "Guide \(setup.days(days))"
        case .failed: status.lastGuideDays.map { "Guide \(setup.days($0))" } ?? "Guide failed"
        }
    }

    /// The details' status block, one line each.
    public func detailLines(_ status: SourceStatus, account: String?, now: Date) -> [Line] {
        switch status.load {
        case .waitingForLogin, .waitingForICloud, .unsupported:
            return rowLines(status, now: now)
        case .idle, .loading, .loaded, .failed:
            break
        }
        var lines: [Line] = []
        if let channels = status.channels {
            lines.append(Line("\(count(channels)) in \(setup.groups(status.groups ?? 0))"))
            if case .loaded(let days, let matched, let total) = status.guide {
                lines.append(Line(setup.guide(days: days, matched: matched, total: total)))
            }
            if let last = status.lastSuccess { lines.append(Line("Refreshed \(relative(last, now: now))")) }
            if let account { lines.append(Line(account)) }
        }
        if case .failed(let sentence) = status.load {
            lines.append(Line(status.channels == nil ? sentence : "Could not refresh: \(sentence)", style: .error))
        } else if status.channels == nil {
            lines.append(Line(status.load == .loading ? "Loading…" : "Not loaded yet", style: .muted, busy: status.load == .loading))
        }
        return lines
    }
}
