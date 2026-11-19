import Foundation

/// The words Search shows, in the user's calendar, time zone and locale,
/// which tests pass in.
public struct SearchText: Sendable {
    public var calendar: Calendar
    public var locale: Locale

    var words: Words { Words(locale) }

    public init(calendar: Calendar = .autoupdatingCurrent, locale: Locale = .autoupdatingCurrent) {
        self.calendar = calendar
        self.locale = locale
    }

    public static func placeholder(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Search channels, programmes, movies and series")
    }
    public static func hint(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Check the spelling or try a channel number.")
    }
    public static func someStillLoading(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Some sources are still loading.")
    }
    public static func channelsLoading(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Channels are still loading")
    }
    public static func nextSevenDays(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Next 7 days")
    }

    /// "No results for “<query>”" (search/nothing-found).
    public static func noResults(_ query: SearchQuery, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("No results for “\(words.source(query.text))”")
    }

    /// "Showing 500 of 612" under a capped Channels section
    /// (search/very-long-result-lists).
    public static func showing(_ shown: Int, of total: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Showing \(shown) of \(total)")
    }

    /// "See all 12".
    public static func seeAll(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("See all \(count)")
    }

    /// A chip's label: "Channels · 3".
    public static func chip(_ scope: SearchScope, count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        return "\(name(scope, locale: locale)) · \(count)"
    }

    public static func name(_ scope: SearchScope, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return switch scope {
        case .all: words("All")
        case .channels: words("Channels")
        case .guide: words("Guide")
        case .movies: words("Movies")
        case .series: words("Series")
        }
    }

    /// A channel's second line: "201 · Now: Late Edition", "201 · Matches
    /// Northern Report" for a group match, or the number alone.
    public static func channelLine(
        _ hit: SearchResults.ChannelHit, now programme: String?, locale: Locale = .autoupdatingCurrent
    ) -> String {
        let words = Words(locale)
        let number = hit.channel.number.map { ChannelNumber(major: $0, minor: hit.channel.minorNumber).text(locale) }
        let detail: String? =
            if hit.match == .group, let group = hit.channel.group {
                words("Matches \(words.source(group))")
            } else {
                programme.map { words("Now: \(words.source($0))") }
            }
        return [number, detail].compactMap(\.self).joined(separator: " · ")
    }

    /// The programme's line: its title, then " · " and its episode title when it has one.
    public static func programmeTitle(_ programme: Programme, locale: Locale = .autoupdatingCurrent) -> String {
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
        return "\(format(start, .weekday)) \(time(start))"
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
        "\(day(programme.start, now: now)) \(time(programme.start)) · \(Self.programmeTitle(programme, locale: locale))"
    }

    /// "Today", "Tomorrow" or the weekday's name.
    public func day(_ date: Date, now: Date) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return words("Today") }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return words("Tomorrow")
        }
        return format(date, .longWeekday)
    }

    /// A time of day in the locale's style, "21:00" or "9:00 PM".
    public func time(_ date: Date) -> String {
        format(date, .time)
    }

    private enum Shape { case weekday, longWeekday, weekdayAndDate, time }

    private func format(_ date: Date, _ shape: Shape) -> String {
        let style = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        return switch shape {
        case .weekday: date.formatted(style.weekday(.abbreviated))
        case .longWeekday: date.formatted(style.weekday(.wide))
        case .weekdayAndDate: date.formatted(style.weekday(.abbreviated).day().month(.abbreviated))
        case .time: date.formatted(style.hour().minute())
        }
    }
}
