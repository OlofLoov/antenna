import Foundation

/// How long before start reminders go off on this device
/// (programme-reminders/choose-how-early-reminders-go-off).
public enum ReminderLeadTime: Int, CaseIterable, Codable, Sendable {
    case atStart = 0
    case five = 5
    case ten = 10
    case fifteen = 15
    case thirty = 30

    public static let standard = ReminderLeadTime.five

    public var interval: TimeInterval { TimeInterval(rawValue * 60) }

    /// "At start" or "5 minutes".
    public var title: String {
        self == .atStart ? "At start" : "\(rawValue) minutes"
    }
}

/// What this device has done about reminders, kept per device.
public struct ReminderDelivery: Codable, Equatable, Sendable {
    /// Keys this device has reminded about, by notification or banner.
    public var reminded: Set<String>
    /// The notifications scheduled last time, by key, with when each goes off.
    public var scheduled: [String: Date]

    public init(reminded: Set<String> = [], scheduled: [String: Date] = [:]) {
        self.reminded = reminded
        self.scheduled = scheduled
    }

    /// Without entries for reminders that are gone.
    public func pruned(keeping keys: Set<String>) -> ReminderDelivery {
        ReminderDelivery(reminded: reminded.intersection(keys), scheduled: scheduled.filter { keys.contains($0.key) })
    }
}

/// When reminders go off and what this device schedules
/// (programme-reminders/a-notification-before-the-programme-starts,
/// programme-reminders/a-banner-while-antenna-is-open).
public struct ReminderSchedule: Sendable {
    /// The most notifications iOS keeps pending for one app.
    public static let pendingLimit = 64
    /// A notification for a reminder already due goes off this long after scheduling.
    public static let immediate: TimeInterval = 1

    public var lead: ReminderLeadTime

    public init(lead: ReminderLeadTime) {
        self.lead = lead
    }

    /// When `reminder` goes off: the lead time before its start.
    public func fireDate(_ reminder: Reminder) -> Date {
        reminder.start.addingTimeInterval(-lead.interval)
    }

    /// One notification to schedule.
    public struct Notification: Equatable, Sendable {
        public var reminder: Reminder
        public var fireAt: Date
    }

    /// The notifications to keep pending, and the delivery state after.
    public struct Plan: Equatable, Sendable {
        public var notifications: [Notification]
        public var delivery: ReminderDelivery
    }

    /// The earliest 64 reminders this device has not reminded about and
    /// that have not ended, each at its fire date, or a second from now when
    /// that has passed. A notification scheduled earlier whose time has come
    /// counts as reminded and is left out.
    public func notifications(for reminders: [Reminder], delivery: ReminderDelivery, now: Date) -> Plan {
        var delivery = delivery
        for (key, fireAt) in delivery.scheduled where fireAt <= now {
            delivery.reminded.insert(key)
        }
        let pending = waiting(reminders, delivery: delivery, now: now).prefix(Self.pendingLimit)
        let notifications = pending.map { Notification(reminder: $0, fireAt: max(fireDate($0), now.addingTimeInterval(Self.immediate))) }
        delivery.scheduled = Dictionary(notifications.map { ($0.reminder.key.text, $0.fireAt) }, uniquingKeysWith: min)
        return Plan(notifications: notifications, delivery: delivery)
    }

    /// Reminders whose time has come and that this device has not reminded
    /// about, soonest first. A programme that has ended is never due.
    public func due(_ reminders: [Reminder], delivery: ReminderDelivery, now: Date) -> [Reminder] {
        waiting(reminders, delivery: delivery, now: now).filter { fireDate($0) <= now }
    }

    /// When the next reminder this device has not reminded about goes off, after `now`.
    public func nextFire(_ reminders: [Reminder], delivery: ReminderDelivery, now: Date) -> Date? {
        waiting(reminders, delivery: delivery, now: now).map(fireDate).filter { $0 > now }.min()
    }

    private func waiting(_ reminders: [Reminder], delivery: ReminderDelivery, now: Date) -> [Reminder] {
        ReminderList.upcoming(reminders, now: now)
            .filter { !delivery.reminded.contains($0.key.text) }
            .sorted { fireDate($0) != fireDate($1) ? fireDate($0) < fireDate($1) : ReminderList.soonest($0, $1) }
    }
}
