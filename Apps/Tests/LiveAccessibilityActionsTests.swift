import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

#if os(iOS) || os(macOS)
    /// The actions VoiceOver offers on the Live picture and on a channel,
    /// run as VoiceOver would run them. XCUITest cannot pick a named
    /// VoiceOver action, so these run the same list the views offer.
    @MainActor
    @Suite struct LiveAccessibilityActionsTests {
        let container: ModelContainer
        let engine = TimeshiftTestEngine()
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
                    engine: engine, load: { _ in Playlist(channels: channels) }, hasLogin: { _ in true }, guide: nil,
                    programmes: UITestingLive.guide))
            live.sourcesChanged([SourceDescriptor(id: source, name: "Home", kind: .m3u, url: URL(fileURLWithPath: "/home.m3u"))])
            await live.settled()
        }

        private func channel(_ name: String) throws -> Channel {
            try #require(live.channels.first { $0.name == name })
        }

        private func run(_ name: String, in actions: [NamedAction]) throws {
            try #require(actions.first { $0.name == name }, "no \(name) action").run()
        }

        /// Lets the model's engine tasks run.
        private func settle() async {
            for _ in 0..<20 { await Task.yield() }
        }

        @Test("live-tv-on-iphone-ipad-mac/swipe-on-the-picture-to-change-channel Channel up and Channel down zap like a swipe")
        func zap() throws {
            live.pick(try channel("Two"))
            #expect(live.pictureActions.map(\.name) == ["Channel up", "Channel down"], "no skips while the channel cannot rewind")

            try run("Channel up", in: live.pictureActions)
            #expect(live.playing?.name == "Three")
            try run("Channel up", in: live.pictureActions)
            #expect(live.playing?.name == "One", "past the last channel comes the first")
            try run("Channel down", in: live.pictureActions)
            #expect(live.playing?.name == "Three")
        }

        @Test("live-tv-on-iphone-ipad-mac/double-tap-to-skip Back and Forward 15 seconds show and skip while the channel can rewind")
        func skips() async throws {
            live.pick(try channel("One"))
            await settle()
            live.player.timeshift.statusChanged(TimeshiftModelTests.status(behind: 600))
            #expect(live.pictureActions.map(\.name) == ["Channel up", "Channel down", "Back 15 seconds", "Forward 15 seconds"])

            try run("Back 15 seconds", in: live.pictureActions)
            await settle()
            #expect(engine.seeks.last == TimeshiftModelTests.end.addingTimeInterval(-615))
            live.player.timeshift.statusChanged(TimeshiftModelTests.status(behind: 600))
            try run("Forward 15 seconds", in: live.pictureActions)
            await settle()
            #expect(engine.seeks.last == TimeshiftModelTests.end.addingTimeInterval(-585))
        }

        @Test("favorites/favorite-from-a-channel-s-menu the VoiceOver action names the channel's state and adds or removes it")
        func favorite() throws {
            let context = container.mainContext
            let two = try channel("Two")
            func action() -> NamedAction {
                Browse.FavoriteMenuButton.action(isFavorite: live.catalogue.isFavorite(two)) {
                    _ = FavoriteRecord.toggle(two, in: live.catalogue, context: context)
                }
            }
            func sync() throws {
                let records = try context.fetch(FetchDescriptor<FavoriteRecord>(sortBy: [SortDescriptor(\.sortOrder)]))
                live.favoritesChanged(records.map(\.snapshot))
            }

            #expect(action().name == "Add to Favorites")
            action().run()
            try sync()
            #expect(live.catalogue.isFavorite(two))
            #expect(live.playing == nil, "adding a favorite plays nothing")
            #expect(action().name == "Remove from Favorites")
            action().run()
            try sync()
            #expect(!live.catalogue.isFavorite(two))
        }
    }
#endif
