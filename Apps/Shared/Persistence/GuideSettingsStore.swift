import AntennaCore
import Foundation
import SwiftData

/// One source's guide settings as they sync: the order of its guides, the
/// ones turned off, added links and matches, as a JSON `GuideSettings`. No
/// secret is in it; an added link with a login keeps its whole link in the
/// Keychain. CloudKit can deliver two records for one source; they merge
/// entry by entry when read.
@Model
final class GuideSettingsRecord {
    var sourceID: UUID?
    var payload: Data?
    var modifiedAt: Date = Date.now

    init(sourceID: UUID, payload: Data?, modifiedAt: Date = .now) {
        self.sourceID = sourceID
        self.payload = payload
        self.modifiedAt = modifiedAt
    }

    /// The settings, or nil when the payload does not decode.
    var settings: GuideSettings? {
        guard let payload else { return GuideSettings.empty }
        return try? JSONDecoder().decode(GuideSettings.self, from: payload)
    }
}

/// Reads and writes guide settings
/// (guide-sources-and-channel-mapping/settings-follow-you-to-every-device).
@MainActor
enum GuideSettingsStore {
    /// Every source's settings, duplicates merged. Records that do not
    /// decode are skipped.
    static func all(in context: ModelContext) -> [UUID: GuideSettings] {
        var result: [UUID: GuideSettings] = [:]
        for record in records(in: context) {
            guard let id = record.sourceID, let settings = record.settings else { continue }
            result[id] = result[id].map { $0.merged(with: settings) } ?? settings
        }
        return result
    }

    static func settings(for sourceID: UUID, in context: ModelContext) -> GuideSettings {
        all(in: context)[sourceID] ?? .empty
    }

    /// Applies `change` to the source's merged settings and saves them as
    /// one record, deleting the duplicates it merged. A record that does not
    /// decode is left alone. Nothing is written when `change` returns false.
    @discardableResult
    static func update(_ sourceID: UUID, in context: ModelContext, _ change: (inout GuideSettings) -> Bool) -> Bool {
        let mine = records(in: context).filter { $0.sourceID == sourceID }
        let readable = mine.filter { $0.settings != nil }
        var settings = readable.compactMap(\.settings).reduce(GuideSettings.empty) { $0.merged(with: $1) }
        guard change(&settings), let payload = try? JSONEncoder().encode(settings) else { return false }
        if let first = readable.first {
            first.payload = payload
            first.modifiedAt = .now
            readable.dropFirst().forEach(context.delete)
        } else {
            context.insert(GuideSettingsRecord(sourceID: sourceID, payload: payload))
        }
        try? context.save()
        return true
    }

    /// Deletes the source's settings and the Keychain items of its added
    /// links, in the caller's save.
    static func removeSource(_ sourceID: UUID, in context: ModelContext, credentials: any CredentialStoring) {
        for record in records(in: context) where record.sourceID == sourceID {
            for id in record.settings.map({ Array($0.links.keys) }) ?? [] {
                try? credentials.delete(for: linkKey(sourceID, id))
            }
            context.delete(record)
        }
    }

    /// The Keychain account of an added link: `<sourceID>.guide.<linkID>`.
    static func linkKey(_ sourceID: UUID, _ linkID: String) -> String {
        "\(sourceID.uuidString).guide.\(linkID)"
    }

    /// The whole link of an added guide, when this device has it.
    nonisolated static func link(_ sourceID: UUID, _ linkID: String, credentials: any CredentialStoring) -> URL? {
        guard let item = try? credentials.load(for: "\(sourceID.uuidString).guide.\(linkID)") else { return nil }
        return URL(string: item.password)
    }

    /// Keeps the whole link in the Keychain under its key.
    static func saveLink(_ url: URL, sourceID: UUID, linkID: String, credentials: any CredentialStoring) throws {
        try credentials.save(CredentialStore.Credential(username: "", password: url.absoluteString), for: linkKey(sourceID, linkID))
    }

    private static func records(in context: ModelContext) -> [GuideSettingsRecord] {
        (try? context.fetch(FetchDescriptor<GuideSettingsRecord>())) ?? []
    }
}
