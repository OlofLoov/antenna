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
        if rewrite(formerIDs, source: source, only: isEarlier, in: context) { try? context.save() }
    }

    /// Rewrites, as `apply` does, every favorite and own-group channel of
    /// `source` whose id `ids` names, whatever its form, and does not save.
    /// For a playlist switched to Xtream
    /// (source-management/a-playlist-source-switches-to-xtream-in-place).
    /// Returns true when something changed.
    @discardableResult
    static func rewrite(_ ids: [String: String], source: UUID, in context: ModelContext) -> Bool {
        guard !ids.isEmpty else { return false }
        return rewrite(ids, source: source, only: { ids[$0] != nil }, in: context)
    }

    private static func rewrite(_ ids: [String: String], source: UUID, only: (String) -> Bool, in context: ModelContext) -> Bool {
        let favorites = migrateFavorites(ids, source: source, only: only, in: context)
        let members = migrateMembers(ids, source: source, only: only, in: context)
        return favorites || members
    }

    /// Moves what this device remembers per channel of `source`, for every
    /// profile, and the source's hand-picked guide matches to the ids `ids`
    /// names: recents, the last channel, language picks and matches
    /// (source-management/switching-to-xtream-keeps-what-was-remembered-per-channel).
    /// Saves the guide settings when a match moved.
    static func moveRemembered(_ ids: [String: String], source: UUID, defaults: UserDefaults, in context: ModelContext) {
        guard !ids.isEmpty else { return }
        RecentsStore.renameChannels(ids, source: source, in: defaults)
        ChannelLanguageStore.renameChannels(ids, source: source, in: defaults)
        GuideSettingsStore.update(source, in: context) { $0.moveMatches(ids, at: .now) }
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

    private static func migrateFavorites(
        _ formerIDs: [String: String], source: UUID, only: (String) -> Bool, in context: ModelContext
    ) -> Bool {
        let all = (try? context.fetch(FetchDescriptor<FavoriteRecord>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        var saved = Set(all.filter { !only($0.channelID) }.map(FavoriteKey.init))
        var changed = false
        for record in all where only(record.channelID) && (record.sourceID == nil || record.sourceID == source) {
            guard let id = formerIDs[record.channelID] else { continue }
            record.channelID = id
            if !saved.insert(FavoriteKey(record)).inserted { context.delete(record) }
            changed = true
        }
        return changed
    }

    private static func migrateMembers(
        _ formerIDs: [String: String], source: UUID, only: (String) -> Bool, in context: ModelContext
    ) -> Bool {
        let all = (try? context.fetch(FetchDescriptor<GroupMemberRecord>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        var saved = Set(all.filter { !only($0.channelID) }.map(MemberKey.init))
        var changed = false
        for record in all where only(record.channelID) && record.sourceID == source {
            guard let id = formerIDs[record.channelID] else { continue }
            record.channelID = id
            if !saved.insert(MemberKey(record)).inserted { context.delete(record) }
            changed = true
        }
        return changed
    }
}
