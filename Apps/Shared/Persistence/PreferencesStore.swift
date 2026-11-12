import AntennaCore
import Foundation
import SwiftData

/// The synced preferences (sources-and-settings/choose-how-the-app-behaves).
/// One record is meant to exist; CloudKit allows several, so the newest is
/// read and the rest deleted. Every field is defaulted and nothing is unique.
@Model
final class PreferencesRecord {
    var id: UUID = UUID()
    var openOnLaunchRaw: String = AppPreferences.LaunchScreen.live.rawValue
    var guideHours: Int = 2
    /// Hours between scheduled refreshes; 0 is manual only.
    var refreshHours: Int = AppPreferences.RefreshInterval.twelve.rawValue
    var swipeRaw: String = AppPreferences.Swipe.changesChannel.rawValue
    var updatedAt: Date = Date.now

    init() {}

    var preferences: AppPreferences {
        AppPreferences(
            openOnLaunch: AppPreferences.LaunchScreen(rawValue: openOnLaunchRaw) ?? .live, guideHours: guideHours,
            refresh: AppPreferences.RefreshInterval(rawValue: refreshHours) ?? .twelve,
            swipe: AppPreferences.Swipe(rawValue: swipeRaw) ?? .changesChannel)
    }

    func store(_ preferences: AppPreferences, at date: Date) {
        openOnLaunchRaw = preferences.openOnLaunch.rawValue
        guideHours = preferences.guideHours
        refreshHours = preferences.refresh.rawValue
        swipeRaw = preferences.swipe.rawValue
        updatedAt = date
    }
}

/// Reads and writes the preferences record.
@MainActor
enum PreferencesStore {
    /// The preferences in effect: the newest record's, or the defaults when
    /// there is none. Reading inserts nothing; it deletes older duplicates.
    static func current(in context: ModelContext) -> AppPreferences {
        winner(in: context)?.preferences ?? AppPreferences()
    }

    /// `records`' preferences, for a view that queries them.
    static func current(_ records: [PreferencesRecord]) -> AppPreferences {
        let id = AppPreferences.winner(records.map { (id: $0.id.uuidString, updated: $0.updatedAt) })
        return records.first { $0.id.uuidString == id }?.preferences ?? AppPreferences()
    }

    /// Stores `preferences`, in the newest record or a new one.
    static func save(_ preferences: AppPreferences, in context: ModelContext, now: Date = .now) {
        let record =
            winner(in: context)
            ?? {
                let record = PreferencesRecord()
                context.insert(record)
                return record
            }()
        record.store(preferences, at: now)
        try? context.save()
    }

    private static func winner(in context: ModelContext) -> PreferencesRecord? {
        let records = (try? context.fetch(FetchDescriptor<PreferencesRecord>())) ?? []
        guard let id = AppPreferences.winner(records.map { (id: $0.id.uuidString, updated: $0.updatedAt) }) else { return nil }
        let winner = records.first { $0.id.uuidString == id }
        let losers = records.filter { $0.id.uuidString != id }
        if !losers.isEmpty {
            losers.forEach(context.delete)
            try? context.save()
        }
        return winner
    }
}
