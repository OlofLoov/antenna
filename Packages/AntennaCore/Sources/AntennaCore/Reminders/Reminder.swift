import Foundation

/// A reminder for one programme on one channel's guide
/// (programme-reminders capability). Holds no channel id, link or login:
/// the channel is found again through its source and guide id.
public struct Reminder: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var sourceID: UUID
    /// The channel's guide id, as `GuideKey.epgID`.
    public var guideID: String
    public var start: Date
    /// Nil when the guide gave none; the programme then counts as ending
    /// three hours after it starts.
    public var stop: Date?
    public var title: String
    public var channelName: String
    /// The first start before a guide update moved the programme.
    public var movedFrom: Date?
    /// A loaded guide covering the start no longer lists the programme.
    public var notListed: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(), sourceID: UUID, guideID: String, start: Date, stop: Date?, title: String, channelName: String,
        movedFrom: Date? = nil, notListed: Bool = false, createdAt: Date
    ) {
        self.id = id
        self.sourceID = sourceID
        self.guideID = guideID
        self.start = start
        self.stop = stop
        self.title = title
        self.channelName = channelName
        self.movedFrom = movedFrom
        self.notListed = notListed
        self.createdAt = createdAt
    }

    /// A reminder for `programme` on `channel`; nil when the channel has no guide key.
    public init?(programme: Programme, channel: Channel, now: Date, id: UUID = UUID()) {
        guard let key = GuideKey(channel: channel) else { return nil }
        self.init(
            id: id, sourceID: key.sourceID, guideID: key.epgID, start: programme.start, stop: programme.stop,
            title: GuidePanelText.title(programme), channelName: channel.name, createdAt: now)
    }

    public var key: ReminderKey { ReminderKey(sourceID: sourceID, guideID: guideID, start: start) }

    public var guideKey: GuideKey { GuideKey(sourceID: sourceID, epgID: guideID) }

    /// How long a programme with no stop counts as running.
    public static let assumedLength: TimeInterval = 3 * 3600
    /// How long after it hides an ended reminder is deleted, so one device
    /// with a fast clock does not delete it for every device.
    public static let deleteDelay: TimeInterval = 10 * 60

    /// When the reminder leaves every list: its stop, or three hours after start.
    public var hidesAt: Date { stop ?? start.addingTimeInterval(Self.assumedLength) }

    /// Ended: hidden from lists and never delivered.
    public func isHidden(at now: Date) -> Bool { now >= hidesAt }

    /// Ten minutes past hiding: any device may delete the record.
    public func isExpired(at now: Date) -> Bool { now >= hidesAt.addingTimeInterval(Self.deleteDelay) }

    /// The channel Watch plays: the first in `channels`, given in All
    /// channels order, with this reminder's source and guide id.
    public func channel(in channels: [Channel]) -> Channel? {
        channels.first { GuideKey(channel: $0) == guideKey }
    }
}

/// What makes two reminders the same: the source, the guide id and the start.
public struct ReminderKey: Hashable, Sendable, Codable {
    public var sourceID: UUID
    public var guideID: String
    public var start: Date

    public init(sourceID: UUID, guideID: String, start: Date) {
        self.sourceID = sourceID
        self.guideID = guideID
        self.start = start
    }

    /// The programme `programme` on `channel` would be reminded under; nil without a guide key.
    public init?(programme: Programme, channel: Channel) {
        guard let key = GuideKey(channel: channel) else { return nil }
        self.init(sourceID: key.sourceID, guideID: key.epgID, start: programme.start)
    }

    /// A stable text form for notification ids and per-device state.
    /// Holds no stream data.
    public var text: String {
        "\(sourceID.uuidString)|\(guideID)|\(Int(start.timeIntervalSince1970))"
    }
}

/// The reminders as every device shows them (programme-reminders/see-every-upcoming-reminder-in-one-list).
public enum ReminderList {
    /// One reminder per key, keeping the earliest created-at and then the
    /// lowest id, sorted soonest first. Hidden reminders are left out.
    public static func upcoming(_ copies: [Reminder], now: Date) -> [Reminder] {
        merged(copies).filter { !$0.isHidden(at: now) }
    }

    /// One reminder per key, soonest first, ended ones included.
    public static func merged(_ copies: [Reminder]) -> [Reminder] {
        Resolution(copies, usable: { _ in true }, key: \.key, wins: wins).winners.sorted(by: soonest)
    }

    /// The ids of every copy of `key`, for removing all of them.
    public static func copies(of key: ReminderKey, in reminders: [Reminder]) -> [UUID] {
        reminders.filter { $0.key == key }.map(\.id)
    }

    /// The ids of copies that lost to another copy of the same key.
    public static func duplicates(in copies: [Reminder]) -> [UUID] {
        Resolution(copies, usable: { _ in true }, key: \.key, wins: wins).losers.map { copies[$0].id }
    }

    /// The ids of reminders any device may delete: ten minutes past their end.
    public static func expired(_ reminders: [Reminder], now: Date) -> [UUID] {
        reminders.filter { $0.isExpired(at: now) }.map(\.id)
    }

    /// The ids of reminders on a deleted source.
    public static func onSource(_ sourceID: UUID, in reminders: [Reminder]) -> [UUID] {
        reminders.filter { $0.sourceID == sourceID }.map(\.id)
    }

    static func wins(_ lhs: Reminder, _ rhs: Reminder) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    static func soonest(_ lhs: Reminder, _ rhs: Reminder) -> Bool {
        if lhs.start != rhs.start { return lhs.start < rhs.start }
        if lhs.channelName != rhs.channelName { return lhs.channelName < rhs.channelName }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
