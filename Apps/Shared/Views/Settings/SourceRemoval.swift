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
    static func title(name: String) -> String { "Delete \(name)?" }

    /// "Removes its 412 channels, 3 favorites and guide from every device
    /// signed in to your iCloud account." The channels clause goes when
    /// the source never loaded, the favorites clause at 0, and the ending
    /// reads "from this device." when not signed in to iCloud.
    static func message(channels: Int?, favorites: Int, signedInToICloud: Bool, text: SetupText = SetupText()) -> String {
        var parts: [String] = []
        if let channels { parts.append("its \(channels == 1 ? "1 channel" : "\(text.count(channels)) channels")") }
        if favorites > 0 { parts.append(favorites == 1 ? "1 favorite" : "\(text.count(favorites)) favorites") }
        parts.append(parts.isEmpty ? "its guide" : "guide")
        let list = parts.count == 1 ? parts[0] : parts.dropLast().joined(separator: ", ") + " and " + (parts.last ?? "")
        let ending = signedInToICloud ? "from every device signed in to your iCloud account." : "from this device."
        return "Removes \(list) \(ending)"
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
