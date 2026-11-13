import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import AntennaTV

/// The overlay's favorite button against an in-memory store.
@MainActor
@Suite struct FavoriteToggleTests {
    let source = UUID()
    let container: ModelContainer

    init() throws {
        let schema = Schema(AntennaSchema.models)
        container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    private var channels: [Channel] {
        Channel.tagged(
            ["a", "b", "c"].map { Channel(id: $0, name: "Channel \($0)", streamURL: URL(fileURLWithPath: "/\($0).ts")) }, sourceID: source)
    }

    private func catalogue() throws -> Catalogue<PersistentIdentifier> {
        let records = try container.mainContext.fetch(FetchDescriptor<FavoriteRecord>(sortBy: [SortDescriptor(\.sortOrder)]))
        return .shell(channels: channels, favorites: records)
    }

    @Test("tv-channel-overlay/add-or-remove-a-favorite toggling adds, then removes, and the count moves by one")
    func toggles() throws {
        let context = container.mainContext
        let channel = channels[1]
        #expect(try catalogue().count(of: .favorites) == 0)
        #expect(FavoriteRecord.toggle(channel, in: try catalogue(), context: context), "the channel is a favorite now")
        let added = try catalogue()
        #expect(added.count(of: .favorites) == 1)
        #expect(added.isFavorite(channel))
        #expect(FavoriteRecord.toggle(channels[2], in: added, context: context))
        let records = try context.fetch(FetchDescriptor<FavoriteRecord>(sortBy: [SortDescriptor(\.sortOrder)]))
        #expect(records.map(\.channelID) == ["b", "c"], "a new favorite goes after the others")
        #expect(records.allSatisfy { $0.sourceID == source })
        #expect(!FavoriteRecord.toggle(channel, in: try catalogue(), context: context), "a second press removes it")
        #expect(try catalogue().count(of: .favorites) == 1)
        #expect(try !catalogue().isFavorite(channel))
    }

    @Test("tv-channel-overlay/add-or-remove-a-favorite removing while Favorites shows moves to a neighbor")
    func neighbor() throws {
        let context = container.mainContext
        for channel in channels { FavoriteRecord.toggle(channel, in: try catalogue(), context: context) }
        let before = try catalogue()
        let rows = before.rows(in: .favorites)
        let model = ChannelOverlayModel()
        model.show(.favorites)
        #expect(model.removedFromFavorites(rows[1], before: before) == .channel(rows[2]), "the next row")
        #expect(model.removedFromFavorites(rows[2], before: before) == .channel(rows[1]), "else the one before")
        model.show(.all)
        #expect(model.removedFromFavorites(rows[0], before: before) == nil, "outside Favorites focus stays")
    }

    @Test("tv-channel-overlay/add-or-remove-a-favorite the last favorite leaves focus on the Favorites group")
    func lastOne() throws {
        let context = container.mainContext
        FavoriteRecord.toggle(channels[0], in: try catalogue(), context: context)
        let before = try catalogue()
        let model = ChannelOverlayModel()
        model.show(.favorites)
        #expect(model.removedFromFavorites(try #require(before.rows(in: .favorites).first), before: before) == .group(.favorites))
    }

    /// XCUITest cannot pick a named VoiceOver action, so this runs the
    /// action an overlay row offers, built as the row builds it.
    @Test("favorites/hold-select-to-favorite-on-apple-tv the VoiceOver action names the channel's state and adds or removes it")
    func voiceOverAction() throws {
        let context = container.mainContext
        let channel = channels[0]
        func action() throws -> NamedAction {
            let catalogue = try catalogue()
            return Browse.FavoriteMenuButton.action(isFavorite: catalogue.isFavorite(channel)) {
                _ = FavoriteRecord.toggle(channel, in: catalogue, context: context)
            }
        }

        #expect(try action().name == "Add to Favorites")
        try action().run()
        #expect(try catalogue().isFavorite(channel))
        #expect(try action().name == "Remove from Favorites")
        try action().run()
        #expect(try !catalogue().isFavorite(channel))
    }
}
