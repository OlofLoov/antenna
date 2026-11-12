import Foundation

/// The words Search shows, in the user's calendar, time zone and locale,
/// which tests pass in.
public struct SearchText: Sendable {
    public var calendar: Calendar
    public var locale: Locale

    public init(calendar: Calendar = .autoupdatingCurrent, locale: Locale = .autoupdatingCurrent) {
        self.calendar = calendar
        self.locale = locale
    }

    public static let placeholder = "Search channels, programmes, movies and series"
    public static let hint = "Check the spelling or try a channel number."
    public static let someStillLoading = "Some sources are still loading."
    public static let channelsLoading = "Channels are still loading"
    public static let nextSevenDays = "Next 7 days"

    /// "No results for “<query>”" (search/nothing-found).
    public static func noResults(_ query: SearchQuery) -> String {
        "No results for “\(query.text)”"
    }

    /// "Showing 500 of 612" under a capped Channels section
    /// (search/very-long-result-lists).
    public static func showing(_ shown: Int, of total: Int) -> String {
        "Showing \(shown) of \(total)"
    }

    /// "See all 12".
    public static func seeAll(_ count: Int) -> String {
        "See all \(count)"
    }

    /// A chip's label: "Channels · 3".
    public static func chip(_ scope: SearchScope, count: Int) -> String {
        "\(name(scope)) · \(count)"
    }

    public static func name(_ scope: SearchScope) -> String {
        switch scope {
        case .all: "All"
        case .channels: "Channels"
        case .guide: "Guide"
        case .movies: "Movies"
        case .series: "Series"
        }
    }

    /// A channel's second line: "201 · Now: Late Edition", "201 · Matches
    /// Northern Report" for a group match, or the number alone.
    public static func channelLine(_ hit: SearchResults.ChannelHit, now programme: String?) -> String {
        let number = hit.channel.number.map { ChannelNumber(major: $0, minor: hit.channel.minorNumber).description }
        let detail: String? =
            if hit.match == .group, let group = hit.channel.group {
                "Matches \(group)"
            } else {
                programme.map { "Now: \($0)" }
            }
        return [number, detail].compactMap(\.self).joined(separator: " · ")
    }

    /// The programme's line: its title, then " · " and its episode title when it has one.
    public static func programmeTitle(_ programme: Programme) -> String {
        guard let subtitle = programme.subtitle, !subtitle.isEmpty else { return programme.title }
        return "\(programme.title) · \(subtitle)"
    }

    /// What leads a programme row: nil for one on now, which shows NOW;
    /// the start time for one later today; the short day and time otherwise
    /// ("Tue 20:00").
    public func lead(_ hit: SearchResults.ProgrammeHit, now: Date) -> String? {
        guard !hit.isOnNow else { return nil }
        let start = hit.programme.start
        if calendar.isDate(start, inSameDayAs: now) { return time(start) }
        return "\(format(start, template: "EEE")) \(time(start))"
    }

    /// A programme's second line: "Docu HD · 21:00 – 22:00" when on now,
    /// otherwise the channel and "Today", "Tomorrow" or the weekday.
    public func detail(_ hit: SearchResults.ProgrammeHit, now: Date) -> String {
        let channel = hit.channel.name
        if hit.isOnNow { return "\(channel) · \(time(hit.programme.start)) – \(time(hit.programme.stop))" }
        return "\(channel) · \(day(hit.programme.start, now: now))"
    }

    /// The Live screen's line for a programme picked in Search
    /// (search/pick-a-programme): "Tomorrow 20:00 · Northern Soul Night".
    public func later(_ programme: Programme, now: Date) -> String {
        "\(day(programme.start, now: now)) \(time(programme.start)) · \(Self.programmeTitle(programme))"
    }

    /// "Today", "Tomorrow" or the weekday's name.
    public func day(_ date: Date, now: Date) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        return format(date, template: "EEEE")
    }

    /// A time of day in the locale's style, "21:00" or "9:00 PM".
    public func time(_ date: Date) -> String {
        format(date, template: "jmm")
    }

    private func format(_ date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}
