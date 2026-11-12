import Foundation

/// What one source's channels add up to, for the onboarding checklist and
/// summary (first-run-onboarding/the-checklist-shows-real-progress).
public struct ChannelTally: Equatable, Sendable {
    public var channels: Int
    /// The source's groups in catalogue order, Favorites and All channels
    /// left out. A source's ungrouped channels count as one group named
    /// "Ungrouped".
    public var groups: [String]
    /// Channels that offer catch-up.
    public var catchUpChannels: Int
    /// The catch-up window most of those channels give, nil when none gives one.
    public var catchUpDays: Int?
    /// The lowest-numbered channel of the first group, the one Start watching plays.
    public var firstChannel: Channel?
    /// The number the catalogue shows for `firstChannel`.
    public var firstNumber: Int?

    public init(channels: Int = 0, groups: [String] = [], catchUpChannels: Int = 0, catchUpDays: Int? = nil, firstChannel: Channel? = nil) {
        self.channels = channels
        self.groups = groups
        self.catchUpChannels = catchUpChannels
        self.catchUpDays = catchUpDays
        self.firstChannel = firstChannel
    }

    /// Counts `channels`, already tagged with one source's id, in
    /// `channel-catalogue` order.
    public init(tagged channels: [Channel]) {
        let catalogue = Catalogue<Int>(channels: channels, groupOrder: [:], favorites: [])
        let groups = catalogue.groups.filter { $0 != .favorites && $0 != .all }
        self.channels = catalogue.count(of: .all)
        self.groups = groups.map { group in
            if case .named(_, let name) = group { return name }
            return "Ungrouped"
        }
        let catchUp = channels.filter(\.hasCatchup)
        catchUpChannels = catchUp.count
        let days = Dictionary(grouping: catchUp.compactMap(\.catchupDays).filter { $0 > 0 }, by: { $0 })
        catchUpDays = days.max { ($0.value.count, $1.key) < ($1.value.count, $0.key) }?.key
        let first = groups.first.flatMap { catalogue.rows(in: $0).first }
        firstChannel = first.flatMap(catalogue.channel(for:))
        firstNumber = first.flatMap(catalogue.number(for:))
    }
}

/// The checklist and summary sentences. Counts use `locale`'s grouping
/// separator and dates its long style.
public struct SetupText: Sendable {
    public var locale: Locale
    public var timeZone: TimeZone

    public init(locale: Locale = .current, timeZone: TimeZone = .current) {
        self.locale = locale
        self.timeZone = timeZone
    }

    public func count(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }

    /// The line under "Signed in", from `user_info`: "Account active until
    /// <date>" and the connections, whichever exist, joined by " · ". Nil
    /// when the server gave neither.
    public func account(expiry: String?, connections: String?) -> String? {
        var parts: [String] = []
        if let seconds = expiry.flatMap(Self.positive) {
            var style = Date.FormatStyle(date: .long, time: .omitted).locale(locale)
            style.timeZone = timeZone
            parts.append("Account active until \(Date(timeIntervalSince1970: TimeInterval(seconds)).formatted(style))")
        }
        if let count = connections.flatMap(Self.positive) {
            parts.append(count == 1 ? "1 connection" : "\(self.count(count)) connections")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "412 live channels in 18 groups".
    public func channels(_ tally: ChannelTally) -> String {
        "\(liveChannels(tally.channels)) in \(groups(tally.groups.count))"
    }

    /// "412 live channels", or "1 live channel".
    public func liveChannels(_ value: Int) -> String {
        value == 1 ? "1 live channel" : "\(count(value)) live channels"
    }

    /// "18 groups", or "1 group".
    public func groups(_ value: Int) -> String {
        value == 1 ? "1 group" : "\(count(value)) groups"
    }

    /// The first eight group names, then "and <n> more".
    public func groupNames(_ names: [String]) -> String {
        let shown = names.prefix(8).joined(separator: ", ")
        return names.count > 8 ? "\(shown) and \(count(names.count - 8)) more" : shown
    }

    /// "1 240 movies and 86 series".
    public func movies(_ movies: Int, series: Int) -> String {
        "\(movies == 1 ? "1 movie" : "\(count(movies)) movies") and \(count(series)) series"
    }

    /// "Downloading the guide · 2,4 MB".
    public func downloading(bytes: Int64) -> String {
        "Downloading the guide · \(bytes.formatted(.byteCount(style: .file).locale(locale)))"
    }

    /// "Guide for 7 days · 388 of 412 channels".
    public func guide(days: Int, matched: Int, total: Int) -> String {
        "Guide for \(self.days(days)) · \(count(matched)) of \(count(total)) channels"
    }

    /// "7 days", or "1 day".
    public func days(_ value: Int) -> String {
        value == 1 ? "1 day" : "\(count(value)) days"
    }

    private static func positive(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if let value = Int(trimmed), value > 0 { return value }
        if let value = Double(trimmed), value >= 1, value < Double(Int.max) { return Int(value) }
        return nil
    }
}
