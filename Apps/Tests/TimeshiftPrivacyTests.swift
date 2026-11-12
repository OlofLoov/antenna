import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

#if os(iOS) || os(macOS)
    /// What the store keeps after catch-up channels played and were starred
    /// (timeshift-catch-up-and-start-over/logins-stay-private).
    @MainActor
    @Suite struct TimeshiftPrivacyTests {
        @Test("timeshift-catch-up-and-start-over/logins-stay-private: saved records hold no template, login, time zone or correction")
        func savedRecords() async throws {
            let container = try ModelContainer(
                for: Schema(AntennaSchema.models),
                configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
            let source = UUID()
            let template = Channel(
                id: "m3u#tpl#0", name: "Template", streamURL: URL(fileURLWithPath: "/template.ts"), hasCatchup: true, catchupMode: .default,
                catchupSource: "http://a/arc?user=secret-user&pass=secret-pass&s={utc}", catchupCorrectionHours: 7.25)
            let xtream = Channel(
                id: "xtream#panel#42", name: "Archive", streamURL: URL(fileURLWithPath: "/archive.ts"), hasCatchup: true, catchupMode: .xc)
            let live = LiveModel(
                .init(
                    engine: UITestingLive.Engine(log: nil),
                    load: { _ in Playlist(channels: [template, xtream], serverTimeZone: "Pacific/Chatham") },
                    hasLogin: { _ in true }, guide: nil, programmes: UITestingLive.guide))
            live.sourcesChanged([SourceDescriptor(id: source, name: "Home", kind: .m3u, url: URL(fileURLWithPath: "/home.m3u"))])
            await live.settled()
            let context = container.mainContext
            for channel in live.channels {
                live.tune(channel)
                FavoriteRecord.toggle(channel, in: live.catalogue, context: context)
            }
            try context.save()

            let favorites = try context.fetch(FetchDescriptor<FavoriteRecord>())
            #expect(favorites.count == 2)
            let saved =
                favorites.map { "\($0.channelID) \($0.sourceID?.uuidString ?? "")" }
                + (try context.fetch(FetchDescriptor<SourceRecord>())).map { "\($0.name) \($0.url?.absoluteString ?? "")" }
                + (try context.fetch(FetchDescriptor<ProgressRecord>())).map { String(describing: $0.persistentModelID) }
                + (try context.fetch(FetchDescriptor<ListEntryRecord>())).map { String(describing: $0.persistentModelID) }
            for text in saved {
                #expect(!text.contains("secret"))
                #expect(!text.contains("Chatham"))
                #expect(!text.contains("7.25"))
                #expect(!text.contains("{utc}"))
            }
            // The recents this device keeps hold no catch-up detail either.
            let recents = String(describing: live.session.store.recents)
            #expect(!recents.contains("secret") && !recents.contains("Chatham"))
        }
    }
#endif
