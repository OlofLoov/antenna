import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// The reminder center against an in-memory store with no iCloud, a
/// scripted notification center and a fixed clock.
@MainActor
@Suite struct ReminderCenterTests {
    let container: ModelContainer
    let defaults: UserDefaults
    let source = UUID()
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
        let name = "reminder-center-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
    }

    private var context: ModelContext { container.mainContext }

    private var channel: Channel {
        Channel.tagged(
            [Channel(id: "1", name: "Sport One", streamURL: URL(filePath: "/1.ts"), epgID: "s1", number: 104)], sourceID: source)[0]
    }

    private func programme(_ title: String = "Match of the Day", in minutes: Double = 120) -> Programme {
        Programme(
            channelID: "s1", start: now.addingTimeInterval(minutes * 60), stop: now.addingTimeInterval(minutes * 60 + 3600), title: title)
    }

    private func center(_ notifier: RecordingNotifier, at clock: @escaping @MainActor () -> Date) async -> ReminderCenter {
        let center = ReminderCenter(context: context, notifier: notifier, defaults: defaults, clock: clock)
        await center.refreshAuthorization()
        center.reload()
        return center
    }

    // programme-reminders/set-a-reminder-in-one-tap, not signed in to iCloud and offline
    @Test func settingSavesLocallyAndAsksAfterSaving() async throws {
        let notifier = RecordingNotifier(state: .notDetermined)
        let center = await center(notifier) { now }
        notifier.onAsk = { [context] in
            #expect((try? context.fetchCount(FetchDescriptor<ReminderRecord>())) == 1, "asked before saving")
        }
        center.toggle(programme(), on: channel)
        #expect(center.isSet(programme(), on: channel))
        #expect(center.upcoming.map(\.title) == ["Match of the Day"])
        try await waitUntil { notifier.asks == 1 }
        center.toggle(programme(), on: channel)
        center.toggle(programme(), on: channel)
        try await Task.sleep(for: .milliseconds(100))
        #expect(notifier.asks == 1)
    }

    // programme-reminders/remove-a-reminder-anywhere: every copy goes and nothing is delivered after
    @Test func removingDeletesEveryCopyAndUnschedules() async throws {
        let notifier = RecordingNotifier(state: .allowed)
        let center = await center(notifier) { now }
        let reminder = try #require(Reminder(programme: programme(), channel: channel, now: now))
        context.insert(ReminderRecord(reminder))
        var copy = reminder
        copy.id = UUID()
        context.insert(ReminderRecord(copy))
        try context.save()
        center.reload()
        #expect(center.upcoming.count == 1)
        try await waitUntil { notifier.pending.count == 1 }
        #expect(notifier.pending.first?.body == "Starts at \(ReminderText().time(reminder.start)) on Sport One")

        center.remove(center.upcoming[0])
        #expect(try context.fetchCount(FetchDescriptor<ReminderRecord>()) == 0)
        try await waitUntil { notifier.pending.isEmpty }
    }

    // programme-reminders/remove-a-reminder-anywhere, a source is deleted
    @Test func deletingASourceRemovesItsReminders() async throws {
        let record = SourceRecord(descriptor: SourceDescriptor(id: source, name: "Home", kind: .m3u, url: URL(filePath: "/home.m3u")))
        context.insert(record)
        ReminderStore.set(programme(), on: channel, in: context, now: now)
        await SourceRemoval(credentials: HeldCredentialStore()).delete(record, in: context)
        #expect(try context.fetchCount(FetchDescriptor<ReminderRecord>()) == 0)
    }

    // programme-reminders/choose-how-early-reminders-go-off, per device
    @Test func theLeadTimeIsKeptOnThisDevice() async throws {
        let notifier = RecordingNotifier(state: .allowed)
        let center = await center(notifier) { now }
        #expect(center.leadTime == .five)
        center.toggle(programme(), on: channel)
        try await waitUntil { notifier.pending.first?.fireAt == now.addingTimeInterval(115 * 60) }
        center.setLeadTime(.thirty)
        try await waitUntil { notifier.pending.first?.fireAt == now.addingTimeInterval(90 * 60) }
        let again = ReminderCenter(context: context, notifier: notifier, defaults: defaults) { now }
        #expect(again.leadTime == .thirty)
    }

    // programme-reminders/reminders-follow-a-programme-that-moves
    @Test func aGuideUpdateMovesTheStoredReminder() async throws {
        let center = await center(RecordingNotifier(state: .allowed)) { now }
        center.toggle(programme(), on: channel)
        let index = GuideIndex(programmes: [source: [programme(in: 150)]])
        center.follow(index)
        #expect(center.upcoming.first?.start == programme(in: 150).start)
        #expect(center.upcoming.first?.movedFrom == programme().start)
    }

    // programme-reminders/see-every-upcoming-reminder-in-one-list: ended reminders go
    @Test func tidyingDeletesEndedReminders() async throws {
        var clock = now
        let center = await center(RecordingNotifier(state: .allowed)) { clock }
        center.toggle(programme(in: 10), on: channel)
        clock = now.addingTimeInterval(75 * 60)
        center.reload()
        #expect(center.upcoming.isEmpty)
        center.tidy()
        #expect(try context.fetchCount(FetchDescriptor<ReminderRecord>()) == 1, "deleted before the ten minutes")
        clock = now.addingTimeInterval(81 * 60)
        center.tidy()
        #expect(try context.fetchCount(FetchDescriptor<ReminderRecord>()) == 0)
    }

    // programme-reminders/a-banner-while-antenna-is-open: once, and only without notifications
    @Test func aBannerShowsOnceWhenNotificationsAreOff() async throws {
        var clock = now
        let notifier = RecordingNotifier(state: .denied)
        let center = await center(notifier) { clock }
        center.toggle(programme(in: 3), on: channel)
        #expect(center.banner?.title == "Match of the Day")
        center.dismissBanner()
        clock = now.addingTimeInterval(60)
        center.reload()
        #expect(center.banner == nil)

        let allowed = await self.center(RecordingNotifier(state: .allowed)) { now }
        allowed.toggle(programme("Other", in: 2), on: channel)
        #expect(allowed.banner == nil)
    }

    // programme-reminders/a-banner-while-antenna-is-open, returning to a missed reminder
    @Test func aReminderMissedInTheBackgroundShowsOnReturn() async throws {
        var clock = now
        let center = await center(RecordingNotifier(state: .denied)) { clock }
        center.active = false
        center.toggle(programme(in: 3), on: channel)
        #expect(center.banner == nil, "a banner while in the background")
        clock = now.addingTimeInterval(10 * 60)
        center.active = true
        center.reload()
        #expect(center.banner?.title == "Match of the Day")
        center.dismissBanner()
        center.active = false
        center.active = true
        center.reload()
        #expect(center.banner == nil, "the banner came back")
    }

    // programme-reminders/a-banner-while-antenna-is-open: a programme that ended is not shown on return
    @Test func anEndedProgrammeShowsNoBannerOnReturn() async throws {
        var clock = now
        let center = await center(RecordingNotifier(state: .denied)) { clock }
        center.active = false
        center.toggle(programme(in: 3), on: channel)
        clock = now.addingTimeInterval(64 * 60)
        center.active = true
        center.reload()
        #expect(center.banner == nil)
    }

    // programme-reminders/watch-plays-the-channel, the paid unlock has lapsed
    @Test func lockedShowsNoBannerAndWatchesNothing() async throws {
        let center = await center(RecordingNotifier(state: .denied)) { now }
        center.locked = true
        center.toggle(programme(in: 3), on: channel)
        #expect(center.banner == nil)
        center.locked = false
        center.reload()
        #expect(center.banner != nil)
        center.watchBanner()
        #expect(center.watchRequest == GuideKey(channel: channel))
        center.locked = true
        #expect(center.watchRequest == nil)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<100 where !condition() {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(condition())
    }
}

/// Answers as told and keeps what was scheduled.
@MainActor
final class RecordingNotifier: ReminderNotifying {
    var state: ReminderAuthorization
    var asks = 0
    var onAsk: () -> Void = {}
    var pending: [ReminderNotificationRequest] = []

    init(state: ReminderAuthorization) {
        self.state = state
    }

    func authorization() async -> ReminderAuthorization { state }

    func requestAuthorization() async -> Bool {
        asks += 1
        onAsk()
        state = .allowed
        return true
    }

    func schedule(_ requests: [ReminderNotificationRequest]) async {
        pending = requests
    }

    func listen(opened: @escaping @MainActor (String) -> Void, presented: @escaping @MainActor (String) -> Void) {}
}
