import AntennaCore
import Foundation
import SwiftData

/// Deleting a source and everything that came with it
/// (sources-and-settings/delete-a-source-and-everything-that-came-with-it):
/// the record, its login, its favorites in every profile, its watch
/// history, its reminders (programme-reminders/remove-a-reminder-anywhere),
/// its guide and its last load time. The channels go when the
/// screens see the record gone.
@MainActor
struct SourceRemoval {
    var credentials: any CredentialStoring = CredentialStore()
    var guide: AppGuideStore?
    var refresher: SourceRefresher?

    /// "Delete <name>?"
    static func title(name: String) -> LocalizedStringResource { "Delete \(name)?" }

    /// "Removes its 412 channels, 3 favorites and guide from every device
    /// signed in to your iCloud account." The channels clause goes when
    /// the source never loaded, the favorites clause at 0, and the ending
    /// reads "from this device." when not signed in to iCloud. Each shape
    /// is one whole sentence, so a translation can order it freely.
    static func message(channels: Int?, favorites: Int, signedInToICloud: Bool) -> LocalizedStringResource {
        let channelCount = channels.map(Self.channelCount)
        let favoriteCount = favorites == 0 ? nil : Self.favoriteCount(favorites)
        switch (channelCount, favoriteCount, signedInToICloud) {
        case (let channels?, let favorites?, true):
            return "Removes its \(channels), \(favorites) and guide from every device signed in to your iCloud account."
        case (let channels?, let favorites?, false):
            return "Removes its \(channels), \(favorites) and guide from this device."
        case (let channels?, nil, true):
            return "Removes its \(channels) and guide from every device signed in to your iCloud account."
        case (let channels?, nil, false):
            return "Removes its \(channels) and guide from this device."
        case (nil, let favorites?, true):
            return "Removes \(favorites) and guide from every device signed in to your iCloud account."
        case (nil, let favorites?, false):
            return "Removes \(favorites) and guide from this device."
        case (nil, nil, true):
            return "Removes its guide from every device signed in to your iCloud account."
        case (nil, nil, false):
            return "Removes its guide from this device."
        }
    }

    // Xcode does not extract a literal declared as `LocalizedStringResource?`
    // next to another literal, so each count is a function with `return`s.
    private static func channelCount(_ count: Int) -> LocalizedStringResource {
        if count == 1 { return "1 channel" }
        return "\(count) channels"
    }

    private static func favoriteCount(_ count: Int) -> LocalizedStringResource {
        if count == 1 { return "1 favorite" }
        return "\(count) favorites"
    }

    /// How many favorites, in every profile, point at `id`.
    static func favorites(of id: UUID, in context: ModelContext) -> Int {
        let source: UUID? = id
        return (try? context.fetchCount(FetchDescriptor<FavoriteRecord>(predicate: #Predicate { $0.sourceID == source }))) ?? 0
    }

    func delete(_ record: SourceRecord, in context: ModelContext) async {
        let id = record.id
        let source: UUID? = id
        for favorite in (try? context.fetch(FetchDescriptor<FavoriteRecord>(predicate: #Predicate { $0.sourceID == source }))) ?? [] {
            context.delete(favorite)
        }
        GroupStore.removeSource(id, in: context)
        ReminderStore.removeSource(id, in: context)
        GuideSettingsStore.removeSource(id, in: context, credentials: credentials)
        SourceRecord.delete(record, from: context, credentials: credentials)
        try? context.save()
        refresher?.forget(id)
        await guide?.remove(sourceID: id)
    }
}
