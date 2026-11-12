import AntennaCore
import Foundation
import SwiftData

/// Moves favorites and own-group channels saved with an M3U channel's
/// earlier id, which held the stream link, to its id now
/// (favorites/favorites-saved-before-the-id-change-carry-over).
@MainActor
enum ChannelIDMigration {
    /// Rewrites each favorite of `source`, or with no source, and each
    /// own-group channel of `source` whose id `formerIDs` names. A record
    /// whose new id is already saved with the same profile and source, or
    /// in the same group, is deleted instead. Saves once, and only when
    /// something changed. Rewritten ids hold no link, so a second run finds
    /// nothing.
    static func apply(_ formerIDs: [String: String], source: UUID, in context: ModelContext) {
        guard !formerIDs.isEmpty else { return }
        let favorites = migrateFavorites(formerIDs, source: source, in: context)
        let members = migrateMembers(formerIDs, source: source, in: context)
        if favorites || members { try? context.save() }
    }

    /// True for an id from before m3u-playlists/stable-and-unique-ids.
    static func isEarlier(_ channelID: String) -> Bool {
        channelID.contains("://")
    }

    private struct FavoriteKey: Hashable {
        var channelID: String
        var sourceID: UUID?
        var profileID: UUID?

        init(_ record: FavoriteRecord) {
            channelID = record.channelID
            sourceID = record.sourceID
            profileID = record.profileID
        }
    }

    private struct MemberKey: Hashable {
        var groupID: UUID?
        var channelID: String
        var sourceID: UUID?

        init(_ record: GroupMemberRecord) {
            groupID = record.groupID
            channelID = record.channelID
            sourceID = record.sourceID
        }
    }

    private static func migrateFavorites(_ formerIDs: [String: String], source: UUID, in context: ModelContext) -> Bool {
        let all = (try? context.fetch(FetchDescriptor<FavoriteRecord>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        var saved = Set(all.filter { !isEarlier($0.channelID) }.map(FavoriteKey.init))
        var changed = false
        for record in all where isEarlier(record.channelID) && (record.sourceID == nil || record.sourceID == source) {
            guard let id = formerIDs[record.channelID] else { continue }
            record.channelID = id
            if !saved.insert(FavoriteKey(record)).inserted { context.delete(record) }
            changed = true
        }
        return changed
    }

    private static func migrateMembers(_ formerIDs: [String: String], source: UUID, in context: ModelContext) -> Bool {
        let all = (try? context.fetch(FetchDescriptor<GroupMemberRecord>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        var saved = Set(all.filter { !isEarlier($0.channelID) }.map(MemberKey.init))
        var changed = false
        for record in all where isEarlier(record.channelID) && record.sourceID == source {
            guard let id = formerIDs[record.channelID] else { continue }
            record.channelID = id
            if !saved.insert(MemberKey(record)).inserted { context.delete(record) }
            changed = true
        }
        return changed
    }
}
