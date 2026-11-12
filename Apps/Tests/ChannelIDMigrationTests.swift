import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// Favorites and own-group channels saved with an M3U channel's earlier id,
/// rewritten when the playlist loads, against an in-memory store.
@MainActor
@Suite struct ChannelIDMigrationTests {
    let container: ModelContainer
    let source = UUID()

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
    }

    private var context: ModelContext { container.mainContext }

    private static let text = """
        #EXTM3U
        #EXTINF:-1 tvg-id="bbc1.uk" group-title="UK",BBC One
        http://panel:8080/live/alice/s3cr3t/42.ts
        #EXTINF:-1 group-title="Family",Kids TV
        http://panel:8080/live/alice/s3cr3t/43.ts
        """
    private static let bbcEarlier = "bbc1.uk#http://panel:8080/live/alice/s3cr3t/42.ts"
    private static let kidsEarlier = "m3u#http://panel:8080/live/alice/s3cr3t/43.ts#2"

    private var playlist: Playlist { M3UParser().parse(Self.text) }

    private var channels: [Channel] { Channel.tagged(playlist.channels, sourceID: source) }

    private func favorites() throws -> [FavoriteRecord] {
        try context.fetch(FetchDescriptor<FavoriteRecord>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    private func members() throws -> [GroupMemberRecord] {
        try context.fetch(FetchDescriptor<GroupMemberRecord>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    @Test("favorites/favorites-saved-before-the-id-change-carry-over a favorite keeps its place and loses the link")
    func rewritesFavorites() throws {
        let profile = UUID()
        context.insert(FavoriteRecord(channelID: Self.kidsEarlier, sourceID: source, sortOrder: 0, profileID: profile))
        context.insert(FavoriteRecord(channelID: Self.bbcEarlier, sourceID: nil, sortOrder: 1))
        try context.save()

        ChannelIDMigration.apply(playlist.formerIDs, source: source, in: context)

        let stored = try favorites()
        #expect(stored.map(\.channelID) == [channels[1].id, channels[0].id])
        #expect(stored.map(\.profileID) == [profile, nil])
        #expect(stored.map(\.sourceID) == [source, nil])
        for record in stored {
            #expect(!record.channelID.contains("alice") && !record.channelID.contains("s3cr3t") && !record.channelID.contains("://"))
        }
        let catalogue = Catalogue<PersistentIdentifier>.shell(channels: channels, favorites: stored)
        #expect(catalogue.rows(in: .favorites).map(\.id) == [channels[0].id])
        let kids = Catalogue<PersistentIdentifier>.shell(channels: channels, favorites: stored, profile: profile)
        #expect(kids.rows(in: .favorites).map(\.id) == [channels[1].id])
    }

    @Test("favorites/favorites-saved-before-the-id-change-carry-over a second load and another device write nothing more")
    func runsOnce() throws {
        context.insert(FavoriteRecord(channelID: Self.bbcEarlier, sourceID: source, sortOrder: 0))
        try context.save()
        ChannelIDMigration.apply(playlist.formerIDs, source: source, in: context)
        let first = try favorites().map(\.channelID)

        ChannelIDMigration.apply(playlist.formerIDs, source: source, in: context)
        #expect(!context.hasChanges)
        #expect(try favorites().map(\.channelID) == first)
    }

    @Test("favorites/favorites-saved-before-the-id-change-carry-over a channel saved with the old and the new id is kept once")
    func mergesDuplicates() throws {
        context.insert(FavoriteRecord(channelID: channels[0].id, sourceID: source, sortOrder: 0))
        context.insert(FavoriteRecord(channelID: Self.bbcEarlier, sourceID: source, sortOrder: 1))
        context.insert(FavoriteRecord(channelID: Self.bbcEarlier, sourceID: source, sortOrder: 2))
        let other = UUID()
        context.insert(FavoriteRecord(channelID: Self.bbcEarlier, sourceID: source, sortOrder: 3, profileID: other))
        try context.save()

        ChannelIDMigration.apply(playlist.formerIDs, source: source, in: context)

        let stored = try favorites()
        #expect(stored.map(\.sortOrder) == [0, 3])
        #expect(stored.allSatisfy { $0.channelID == channels[0].id })
    }

    @Test("favorites/favorites-saved-before-the-id-change-carry-over favorites of another source or a missing channel stay as they are")
    func leavesOthers() throws {
        let missing = "gone.uk#http://panel:8080/live/alice/s3cr3t/99.ts"
        context.insert(FavoriteRecord(channelID: Self.bbcEarlier, sourceID: UUID(), sortOrder: 0))
        context.insert(FavoriteRecord(channelID: missing, sourceID: source, sortOrder: 1))
        context.insert(FavoriteRecord(channelID: "xtream#panel#42", sourceID: source, sortOrder: 2))
        try context.save()

        ChannelIDMigration.apply(playlist.formerIDs, source: source, in: context)

        #expect(try favorites().map(\.channelID) == [Self.bbcEarlier, missing, "xtream#panel#42"])
        #expect(!context.hasChanges)
    }

    @Test("favorites/favorites-saved-before-the-id-change-carry-over own-group channels keep their group and place")
    func rewritesMembers() throws {
        let group = UUID()
        context.insert(GroupMemberRecord(groupID: group, channelID: Self.kidsEarlier, sourceID: source, sortOrder: 0))
        context.insert(GroupMemberRecord(groupID: group, channelID: Self.bbcEarlier, sourceID: source, sortOrder: 1))
        context.insert(GroupMemberRecord(groupID: group, channelID: channels[0].id, sourceID: source, sortOrder: 2))
        try context.save()

        ChannelIDMigration.apply(playlist.formerIDs, source: source, in: context)

        let stored = try members()
        #expect(stored.map(\.channelID) == [channels[1].id, channels[0].id])
        #expect(stored.map(\.sortOrder) == [0, 2])
        #expect(stored.allSatisfy { $0.groupID == group })
    }

    @Test("favorites/favorites-saved-before-the-id-change-carry-over the shared loader rewrites after a load")
    func refresherRewrites() async throws {
        context.insert(FavoriteRecord(channelID: Self.bbcEarlier, sourceID: source, sortOrder: 0))
        try context.save()
        let text = Self.text
        var dependencies = SourceRefresher.Dependencies(load: { _ in M3UParser().parse(text) }, hasLogin: { _ in true })
        let context = context
        let source = source
        dependencies.migrateIDs = { ChannelIDMigration.apply($1, source: $0, in: context) }
        let refresher = SourceRefresher(dependencies)
        let link = try #require(URL(string: "http://panel:8080/get.php"))
        let descriptor = SourceDescriptor(id: source, name: "Panel", kind: .m3u, url: link)

        _ = try await refresher.load(descriptor)

        #expect(try favorites().map(\.channelID) == [channels[0].id])
    }

    @Test("favorites/favorites-reference-stable-channel-ids a new favorite of an M3U channel stores no link or login")
    func newFavoriteHoldsNoLogin() throws {
        let catalogue = Catalogue<PersistentIdentifier>.shell(channels: channels, favorites: [])
        #expect(FavoriteRecord.toggle(channels[0], in: catalogue, context: context))
        let stored = try #require(try favorites().first)
        #expect(!stored.channelID.contains("alice") && !stored.channelID.contains("s3cr3t") && !stored.channelID.contains("panel"))
    }

    @Test("group-management/build-your-own-group-from-any-playlist an M3U channel can join an own group")
    func m3uJoinsOwnGroup() throws {
        let id = try #require(GroupStore.create(named: "Mine", after: [], in: context))
        GroupStore.setMembers(of: id, to: channels, in: context)
        #expect(try members().map(\.channelID) == channels.map(\.id))
    }
}
