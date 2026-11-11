import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

#if os(iOS) || os(macOS)
    /// The star on Live against a real store: what it writes, and what the
    /// Favorites group shows after a write here or from another device.
    @MainActor
    @Suite struct LiveFavoritesTests {
        let container: ModelContainer
        let live: LiveModel
        let source = UUID()

        init() async throws {
            container = try ModelContainer(
                for: Schema(AntennaSchema.models),
                configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
            let channels = ["One", "Two", "Three"].map { name in
                Channel(id: name.lowercased(), name: name, streamURL: URL(fileURLWithPath: "/\(name).ts"), group: "News")
            }
            live = LiveModel(
                .init(
                    engine: UITestingLive.Engine(log: nil), load: { _ in Playlist(channels: channels) }, hasLogin: { _ in true },
                    guide: nil, programmes: UITestingLive.guide))
            live.sourcesChanged([SourceDescriptor(id: source, name: "Home", kind: .m3u, url: URL(fileURLWithPath: "/home.m3u"))])
            await live.settled()
        }

        private var context: ModelContext { container.mainContext }

        /// Reads the store back into the model, as `LiveSync` does for the current profile.
        private func sync(profile: UUID = Profile.mainID) throws {
            let records = try context.fetch(FetchDescriptor<FavoriteRecord>(sortBy: [SortDescriptor(\.sortOrder)]))
            live.favoritesChanged(records.filter { ProfileList.owns(profile, recordProfile: $0.profileID) }.map(\.snapshot))
        }

        private func channel(_ name: String) throws -> Channel {
            try #require(live.channels.first { $0.name == name })
        }

        private var favoriteNames: [String] {
            live.catalogue.rows(in: .favorites).compactMap { live.catalogue.channel(for: $0)?.name }
        }

        @Test("live-tv-on-iphone-ipad-mac/star-a-channel starring adds the channel after the others and raises the count")
        func starring() throws {
            FavoriteRecord.toggle(try channel("Two"), in: live.catalogue, context: context)
            try sync()
            FavoriteRecord.toggle(try channel("One"), in: live.catalogue, context: context)
            try sync()

            #expect(favoriteNames == ["Two", "One"], "favorite order, newest last")
            #expect(live.catalogue.count(of: .favorites) == 2)
            #expect(live.catalogue.isFavorite(try channel("One")))
        }

        @Test("live-tv-on-iphone-ipad-mac/star-a-channel a second tap undoes the star, the group and the count")
        func unstarring() throws {
            FavoriteRecord.toggle(try channel("Three"), in: live.catalogue, context: context)
            try sync()
            #expect(live.catalogue.count(of: .favorites) == 1)

            FavoriteRecord.toggle(try channel("Three"), in: live.catalogue, context: context)
            try sync()

            #expect(live.catalogue.count(of: .favorites) == 0)
            #expect(!live.catalogue.isFavorite(try channel("Three")))
            #expect(try context.fetchCount(FetchDescriptor<FavoriteRecord>()) == 0)
        }

        // favorites/favorites-sync-between-devices: the record another device
        // saves arrives through the store and shows in Live's Favorites group.
        @Test("live-tv-on-iphone-ipad-mac/star-a-channel a favorite from another device shows without reopening Live")
        func fromAnotherDevice() throws {
            context.insert(FavoriteRecord(channelID: "two", sourceID: source, sortOrder: 0))
            try context.save()
            try sync()

            #expect(favoriteNames == ["Two"])
            #expect(live.catalogue.isFavorite(try channel("Two")))
        }

        @Test("live-tv-on-iphone-ipad-mac/star-a-channel stars belong to the current profile")
        func perProfile() throws {
            let kids = UUID()
            FavoriteRecord.toggle(try channel("One"), in: live.catalogue, profile: kids, context: context)
            try sync(profile: Profile.mainID)
            #expect(favoriteNames.isEmpty)

            try sync(profile: kids)
            #expect(favoriteNames == ["One"])
        }

        // profiles/what-each-profile-keeps: favorites apart.
        @Test("favorites/favorites-belong-to-a-profile Dad and Kids each list and change only their own favorites")
        func favoritesApart() throws {
            let kids = UUID()
            try sync(profile: Profile.mainID)
            FavoriteRecord.toggle(try channel("One"), in: live.catalogue, profile: Profile.mainID, context: context)
            try sync(profile: kids)
            FavoriteRecord.toggle(try channel("Three"), in: live.catalogue, profile: kids, context: context)
            try sync(profile: kids)
            #expect(favoriteNames == ["Three"], "Kids sees only Kids's favorite")
            #expect(!live.catalogue.isFavorite(try channel("One")))

            FavoriteRecord.toggle(try channel("Three"), in: live.catalogue, profile: kids, context: context)
            try sync(profile: Profile.mainID)
            #expect(favoriteNames == ["One"], "Kids removing a favorite leaves Dad's alone")
            let stored = try context.fetch(FetchDescriptor<FavoriteRecord>())
            #expect(stored.map(\.profileID) == [nil], "Main's favorites store no profile id")
        }
    }
#endif
