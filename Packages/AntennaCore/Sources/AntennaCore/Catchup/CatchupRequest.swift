import Foundation

/// The part of a programme catch-up should play: from `start` for
/// `duration`, asked for at `now`.
public struct CatchupRequest: Sendable, Hashable {
    public var start: Date
    /// Length in seconds.
    public var duration: TimeInterval
    public var now: Date

    public init(start: Date, duration: TimeInterval, now: Date) {
        self.start = start
        self.duration = duration
        self.now = now
    }

    /// The programme's end.
    public var end: Date { start.addingTimeInterval(duration) }
    /// Seconds from the start to now.
    public var offset: TimeInterval { now.timeIntervalSince(start) }
    /// The length in whole minutes, rounded up.
    public var durationMinutes: Int { Int((duration / 60).rounded(.up)) }
}

/// What catch-up for an Xtream channel needs besides the channel: the
/// login, and the panel's time zone once it is known.
///
/// `description` and `debugDescription` are the server host only, so the
/// value can be interpolated into logs without leaking the login.
public struct XtreamCatchupContext: Sendable, Hashable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var credentials: XtreamCredentials
    /// Nil until `accountInfo()` named a zone this device knows.
    public var timeZone: TimeZone?

    public init(credentials: XtreamCredentials, timeZone: TimeZone?) {
        self.credentials = credentials
        self.timeZone = timeZone
    }

    /// The zone for an `accountInfo()` time zone name, nil for nil or a
    /// name this device does not know.
    public init(credentials: XtreamCredentials, timeZoneName: String?) {
        self.init(credentials: credentials, timeZone: timeZoneName.flatMap(TimeZone.init(identifier:)))
    }

    public var description: String { credentials.description }
    public var debugDescription: String { description }
    /// Shows the host only, so `dump` does not print the login either.
    public var customMirror: Mirror { Mirror(self, children: ["host": description]) }
}

/// Date parts written the way catch-up addresses expect them.
enum CatchupDateText {
    /// `yyyy-MM-dd:HH-mm` in `zone`, as Xtream's `/timeshift/` path takes it.
    static func xtream(_ date: Date, in zone: TimeZone) -> String {
        let parts = components(date, in: zone)
        return "\(parts.year)-\(pad(parts.month))-\(pad(parts.day)):\(pad(parts.hour))-\(pad(parts.minute))"
    }

    struct Parts {
        var year: Int
        var month: Int
        var day: Int
        var hour: Int
        var minute: Int
        var second: Int
    }

    static func components(_ date: Date, in zone: TimeZone) -> Parts {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return Parts(
            year: c.year ?? 0, month: c.month ?? 0, day: c.day ?? 0, hour: c.hour ?? 0, minute: c.minute ?? 0, second: c.second ?? 0)
    }

    static func pad(_ value: Int) -> String {
        value < 10 ? "0\(value)" : String(value)
    }
}
