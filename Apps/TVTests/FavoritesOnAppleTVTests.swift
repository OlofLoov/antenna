import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import AntennaTV

/// What the Apple TV overlay's Favorites group lists, against an in-memory store.
@MainActor
@Suite struct FavoritesOnAppleTVTests {
    let source = UUID()
    let kids = UUID()
    let container: ModelContainer

    init() throws {
        let schema = Schema(AntennaSchema.models)
        container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    private var channels: [Channel] {
        Channel.tagged(
            [("a", "News"), ("b", "News"), ("c", "Sport"), ("d", "Adult")].map { id, group in
                Channel(id: id, name: "Channel \(id)", streamURL: URL(fileURLWithPath: "/\(id).ts"), group: group)
            },
            sourceID: source)
    }

    private func save(_ ids: [(String, Int)], profile: UUID? = nil) {
        for (id, order) in ids {
            container.mainContext.insert(FavoriteRecord(channelID: id, sourceID: source, sortOrder: order, profileID: profile))
        }
    }

    private func catalogue(profile: UUID = Profile.mainID, rules: GroupRules = GroupRules()) throws -> Catalogue<PersistentIdentifier> {
        let records = try container.mainContext.fetch(FetchDescriptor<FavoriteRecord>(sortBy: [SortDescriptor(\.sortOrder)]))
        return .shell(channels: channels, favorites: records, profile: profile, rules: rules)
    }

    private func names(_ catalogue: Catalogue<PersistentIdentifier>) -> [String] {
        catalogue.rows(in: .favorites).compactMap { catalogue.channel(for: $0)?.name }
    }

    @Test("favorites/favorites-on-apple-tv Favorites is the first group, in saved order")
    func order() throws {
        save([("c", 2), ("a", 0), ("b", 1)])
        let catalogue = try catalogue()
        #expect(catalogue.groups.first == .favorites)
        #expect(names(catalogue) == ["Channel a", "Channel b", "Channel c"])
        #expect(catalogue.count(of: .favorites) == 3)
    }

    @Test("favorites/favorites-on-apple-tv only the current profile's favorites are listed")
    func profiles() throws {
        save([("a", 0)], profile: Profile.mainID)
        save([("c", 0)], profile: kids)
        #expect(names(try catalogue()) == ["Channel a"])
        #expect(names(try catalogue(profile: kids)) == ["Channel c"])
    }

    @Test("favorites/favorites-on-apple-tv a favorite in a locked group is left out while locks are closed")
    func locked() throws {
        save([("a", 0), ("d", 1)])
        let adult = CatalogueGroup.named(source, "Adult")
        let closed = try catalogue(rules: GroupRules(locked: [adult]))
        #expect(names(closed) == ["Channel a"])
        #expect(closed.count(of: .favorites) == 1)
        let open = try catalogue(rules: GroupRules(locked: [adult], locksOpen: true))
        #expect(names(open) == ["Channel a", "Channel d"])
    }

    @Test("favorites/favorites-on-apple-tv tuning from Favorites makes channel up and down, and the Guide, follow it")
    func tunedFromFavorites() throws {
        save([("c", 0), ("a", 1)])
        let catalogue = try catalogue()
        let model = ChannelOverlayModel()
        model.tuned(from: .favorites)
        let c = try #require(channels.first { $0.id == "c" })
        #expect(model.currentList(catalogue, for: c) == .favorites)
        #expect(model.step(catalogue, from: c, by: 1)?.id == "a")
        #expect(model.lastTuned == .favorites, "the Guide shows the group last tuned from")
    }

    @Test("favorites/favorites-on-apple-tv no favorites keeps the group with a held-select hint")
    func empty() throws {
        let catalogue = try catalogue()
        #expect(catalogue.groups.contains(.favorites))
        #expect(catalogue.count(of: .favorites) == 0)
        let model = ChannelOverlayModel()
        model.show(.favorites)
        #expect(model.emptyText(catalogue) == "No favorites yet. Hold select on a channel to add it.")
    }
}
