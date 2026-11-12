import AntennaCore
import Foundation
import SwiftData

/// One reminder, synced through iCloud (programme-reminders capability).
/// Every property is defaulted and nothing is unique, as CloudKit needs;
/// copies of one programme are merged in code. Holds no channel id, link
/// or login.
@Model
final class ReminderRecord {
    var id: UUID = UUID()
    var sourceID: UUID?
    var guideID: String = ""
    var start: Date = Date.distantPast
    var stop: Date?
    var title: String = ""
    var channelName: String = ""
    var movedFrom: Date?
    var notListed: Bool = false
    var createdAt: Date = Date.now

    init(_ reminder: Reminder) {
        id = reminder.id
        createdAt = reminder.createdAt
        store(reminder)
    }

    /// Nil for a damaged record with no source or guide id.
    var reminder: Reminder? {
        guard let sourceID, !guideID.isEmpty else { return nil }
        return Reminder(
            id: id, sourceID: sourceID, guideID: guideID, start: start, stop: stop, title: title, channelName: channelName,
            movedFrom: movedFrom, notListed: notListed, createdAt: createdAt)
    }

    /// Writes what a guide update may change, and the identity.
    func store(_ reminder: Reminder) {
        sourceID = reminder.sourceID
        guideID = reminder.guideID
        start = reminder.start
        stop = reminder.stop
        title = reminder.title
        channelName = reminder.channelName
        movedFrom = reminder.movedFrom
        notListed = reminder.notListed
    }
}

/// Reads and writes reminder records.
@MainActor
enum ReminderStore {
    static func records(in context: ModelContext) -> [ReminderRecord] {
        (try? context.fetch(FetchDescriptor<ReminderRecord>())) ?? []
    }

    /// Saves a reminder for `programme` on `channel`; nothing when the
    /// channel has no guide id or the programme already has one.
    @discardableResult
    static func set(_ programme: Programme, on channel: Channel, in context: ModelContext, now: Date = .now) -> Bool {
        guard let reminder = Reminder(programme: programme, channel: channel, now: now) else { return false }
        let all = records(in: context)
        guard !all.contains(where: { $0.reminder?.key == reminder.key }) else { return false }
        context.insert(ReminderRecord(reminder))
        try? context.save()
        return true
    }

    /// Deletes every copy of `key` (programme-reminders/remove-a-reminder-anywhere).
    static func remove(_ key: ReminderKey, in context: ModelContext) {
        for record in records(in: context) where record.reminder?.key == key {
            context.delete(record)
        }
        try? context.save()
    }

    /// Deletes every reminder on a deleted source.
    static func removeSource(_ sourceID: UUID, in context: ModelContext) {
        let source: UUID? = sourceID
        let doomed = (try? context.fetch(FetchDescriptor<ReminderRecord>(predicate: #Predicate { $0.sourceID == source }))) ?? []
        doomed.forEach(context.delete)
    }

    /// Deletes ended reminders ten minutes past their end, duplicates that
    /// lost to an earlier copy, and damaged records.
    static func tidy(in context: ModelContext, now: Date = .now) {
        let all = records(in: context)
        let reminders = all.compactMap(\.reminder)
        let doomed = Set(ReminderList.expired(reminders, now: now) + ReminderList.duplicates(in: reminders))
        var changed = false
        for record in all where record.reminder == nil || doomed.contains(record.id) {
            context.delete(record)
            changed = true
        }
        if changed { try? context.save() }
    }

    /// Moves, renames or marks each reminder that has not started by the
    /// guide in `index` (programme-reminders/reminders-follow-a-programme-that-moves).
    static func follow(_ index: GuideIndex, in context: ModelContext, now: Date = .now) {
        var changed = false
        for record in records(in: context) {
            guard let reminder = record.reminder, reminder.start > now else { continue }
            let programmes = index.programmes(for: [reminder.guideKey], in: ReminderMatching.window(for: reminder))[reminder.guideKey] ?? []
            guard let updated = ReminderMatching.match(reminder, programmes: programmes, coverage: index.span(for: reminder.guideKey))
            else { continue }
            record.store(updated)
            changed = true
        }
        if changed { try? context.save() }
    }
}
