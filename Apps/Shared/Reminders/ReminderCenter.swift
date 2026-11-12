import AntennaCore
import Foundation
import Observation
import SwiftData
import SwiftUI

/// Reminders on this device (programme-reminders capability): the list
/// every screen reads, setting and removing, the lead time, notifications
/// and the in-app banner. The app keeps one for its whole life.
@MainActor @Observable
final class ReminderCenter {
    /// Upcoming reminders, one per programme, soonest first.
    private(set) var upcoming: [Reminder] = []
    private(set) var keys: Set<ReminderKey> = []
    /// Nil until the notification center has answered.
    private(set) var authorization: ReminderAuthorization?
    /// The reminder the banner shows, or nil.
    private(set) var banner: Reminder?
    /// A channel the user asked to watch from a banner or notification, by its guide key.
    var watchRequest: GuideKey?
    private(set) var leadTime: ReminderLeadTime

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let notifier: any ReminderNotifying
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let clock: @MainActor () -> Date
    @ObservationIgnored private var all: [Reminder] = []
    @ObservationIgnored private var delivery: ReminderDelivery
    /// Banners show only while the app is in front.
    @ObservationIgnored var active = true
    /// While locked behind the paywall no banner shows and Watch plays nothing.
    @ObservationIgnored var locked = false {
        didSet {
            guard locked else { return }
            banner = nil
            watchRequest = nil
        }
    }

    static let leadTimeKey = "reminders.leadTime"
    static let deliveryKey = "reminders.delivery"

    init(
        context: ModelContext, notifier: any ReminderNotifying, defaults: UserDefaults = .standard,
        clock: @escaping @MainActor () -> Date = { .now }
    ) {
        self.context = context
        self.notifier = notifier
        self.defaults = defaults
        self.clock = clock
        leadTime = Self.read(ReminderLeadTime.self, Self.leadTimeKey, from: defaults) ?? .standard
        delivery = Self.read(ReminderDelivery.self, Self.deliveryKey, from: defaults) ?? ReminderDelivery()
        notifier.listen(
            opened: { [weak self] key in self?.opened(key) },
            presented: { [weak self] key in self?.presented(key) })
    }

    // MARK: Reading

    func isSet(_ programme: Programme, on channel: Channel) -> Bool {
        ReminderKey(programme: programme, key: GuideLookup.key(for: channel)).map(keys.contains) ?? false
    }

    /// Remind me shows for a programme that has not started on a channel with a guide id
    /// (programme-reminders/remind-me-appears-only-before-a-programme-starts).
    func offers(_ programme: Programme, on channel: Channel, now: Date) -> Bool {
        programme.start > now && GuideLookup.key(for: channel) != nil
    }

    // MARK: Changing

    /// Sets or removes the reminder for `programme`
    /// (programme-reminders/set-a-reminder-in-one-tap). Setting the first
    /// one asks for notification permission, after it is saved
    /// (programme-reminders/permission-is-asked-only-when-it-is-needed).
    func toggle(_ programme: Programme, on channel: Channel) {
        guard let key = ReminderKey(programme: programme, key: GuideLookup.key(for: channel)) else { return }
        if keys.contains(key) {
            ReminderStore.remove(key, in: context)
            reload()
            return
        }
        guard ReminderStore.set(programme, on: channel, in: context, now: clock()) else { return }
        reload()
        Task { await askIfNeeded() }
    }

    /// Removes every copy of `reminder` (programme-reminders/remove-a-reminder-anywhere).
    func remove(_ reminder: Reminder) {
        ReminderStore.remove(reminder.key, in: context)
        reload()
    }

    func setLeadTime(_ lead: ReminderLeadTime) {
        leadTime = lead
        Self.write(lead, Self.leadTimeKey, to: defaults)
        deliver()
    }

    /// Reads the stored reminders again, after this device or iCloud changed them.
    func reload() {
        all = ReminderList.merged(ReminderStore.records(in: context).compactMap(\.reminder))
        let now = clock()
        let shown = all.filter { !$0.isHidden(at: now) }
        if shown != upcoming { upcoming = shown }
        let newKeys = Set(shown.map(\.key))
        if newKeys != keys { keys = newKeys }
        if let banner, !newKeys.contains(banner.key) { self.banner = nil }
        deliver()
    }

    /// Deletes ended and duplicate records, then reads them again.
    func tidy() {
        ReminderStore.tidy(in: context, now: clock())
        reload()
    }

    /// Follows guide changes for reminders that have not started.
    func follow(_ index: GuideIndex) {
        ReminderStore.follow(index, in: context, now: clock())
        reload()
    }

    func refreshAuthorization() async {
        let value = await notifier.authorization()
        guard value != authorization else { return }
        authorization = value
        deliver()
    }

    /// Asks for notification permission from the Reminders page's Allow notifications.
    func requestAuthorization() async {
        _ = await notifier.requestAuthorization()
        await refreshAuthorization()
    }

    private func askIfNeeded() async {
        guard await notifier.authorization() == .notDetermined else { return }
        _ = await notifier.requestAuthorization()
        await refreshAuthorization()
    }

    // MARK: Delivering

    /// Schedules notifications when allowed, otherwise shows the next due
    /// reminder as a banner while in front.
    func deliver() {
        guard let authorization else { return }
        let now = clock()
        let schedule = ReminderSchedule(lead: leadTime)
        delivery = delivery.pruned(keeping: Set(all.map(\.key.text)))
        if authorization == .allowed {
            let plan = schedule.notifications(for: all, delivery: delivery, now: now)
            delivery = plan.delivery
            let text = ReminderText()
            let requests = plan.notifications.map {
                ReminderNotificationRequest(
                    id: ReminderNotificationRequest.prefix + $0.reminder.key.text, title: $0.reminder.title,
                    body: text.notificationBody($0.reminder, lead: leadTime), fireAt: $0.fireAt)
            }
            Task { await notifier.schedule(requests) }
        } else if active, !locked, banner == nil, let due = schedule.due(all, delivery: delivery, now: now).first {
            delivery.reminded.insert(due.key.text)
            banner = due
        }
        Self.write(delivery, Self.deliveryKey, to: defaults)
    }

    /// When `deliver` next has something to do, or nil.
    func nextWake() -> Date? {
        ReminderSchedule(lead: leadTime).nextFire(all, delivery: delivery, now: clock())
    }

    func dismissBanner() {
        banner = nil
        deliver()
    }

    /// Watch on the banner (programme-reminders/watch-plays-the-channel).
    func watchBanner() {
        guard let banner else { return }
        self.banner = nil
        if !locked { watchRequest = banner.guideKey }
        deliver()
    }

    private func opened(_ keyText: String) {
        delivery.reminded.insert(keyText)
        Self.write(delivery, Self.deliveryKey, to: defaults)
        guard !locked, let reminder = all.first(where: { $0.key.text == keyText }) else { return }
        watchRequest = reminder.guideKey
    }

    private func presented(_ keyText: String) {
        delivery.reminded.insert(keyText)
        Self.write(delivery, Self.deliveryKey, to: defaults)
    }

    // MARK: Storage

    private static func read<Value: Decodable>(_ type: Value.Type, _ key: String, from defaults: UserDefaults) -> Value? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    private static func write<Value: Encodable>(_ value: Value, _ key: String, to defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }
}

extension EnvironmentValues {
    /// The app's reminders. Nil in previews that do not set one.
    @Entry var reminders: ReminderCenter? = .none
}
