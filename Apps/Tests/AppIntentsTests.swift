import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

#if os(iOS) || os(macOS)
    /// The Siri and Shortcuts actions, run by calling `perform()` against an
    /// in-memory store with the app started in the background. Siri itself
    /// cannot be driven from a test. Serialized, since the actions find their
    /// provider in one shared place.
    @MainActor
    @Suite(.serialized) struct AppIntentsTests {
        let cabin = IntentFixtures.source("Cabin")
        let attic = IntentFixtures.source("Attic", kind: .xtream)

        private func harness(unlocked: Bool = true, sources: [SourceDescriptor]? = nil, data: Bool = true) throws -> IntentHarness {
            let harness = try IntentHarness(unlocked: unlocked, sources: sources ?? [cabin, attic], protectedData: data)
            harness.playlists[cabin.id] = [
                IntentFixtures.channel("news", "News", number: 1, group: "Info"),
                IntentFixtures.channel("sport", "Sport One", number: 2, group: "Sport"),
                IntentFixtures.channel("kids", "Cartoons", number: 3, group: "Kids"),
            ]
            harness.playlists[attic.id] = [IntentFixtures.channel("sport", "Sport One", number: 2, group: "Games")]
            harness.titles[attic.id] = [
                ShelfTitle(id: "xtream#attic.example#vod#1", kind: .movie, sourceID: attic.id, name: "Harbor"),
                ShelfTitle(id: "xtream#attic.example#series#2", kind: .series, sourceID: attic.id, name: "Northern Lights"),
            ]
            return harness
        }

        // MARK: Tune Channel

        @Test("app-intents/tune-a-channel-by-voice-or-shortcut a saved channel comes forward and tunes")
        func tune() async throws {
            let harness = try harness()
            let entity = try #require(await harness.channel(cabin.id, "sport"))
            #expect(entity.name == "Sport One")
            #expect(entity.subtitle == "2 · Sport · Cabin")
            _ = try await TuneChannelIntent(channel: entity).perform()
            #expect(harness.forwardRequests == 1)
            #expect(harness.host.inbox.pending == .tune(LastChannelKey(sourceID: cabin.id, channelID: "sport")))
        }

        @Test("app-intents/tune-a-channel-by-voice-or-shortcut nothing is tuned when the system will not bring Antenna forward")
        func refused() async throws {
            let harness = try harness()
            harness.refuseForeground = true
            let entity = try #require(await harness.channel(cabin.id, "news"))
            await #expect(throws: (any Error).self) { try await TuneChannelIntent(channel: entity).perform() }
            #expect(harness.host.inbox.pending == nil)
        }

        @Test("app-intents/tune-a-channel-by-voice-or-shortcut before the first unlock the channel resolves once forward")
        func beforeFirstUnlock() async throws {
            let harness = try harness(data: false)
            let entity = try #require(await harness.channel(cabin.id, "news"))
            #expect(entity.failure == nil)
            #expect(harness.loads.isEmpty)
            _ = try await TuneChannelIntent(channel: entity).perform()
            #expect(harness.host.inbox.pending == .tune(LastChannelKey(sourceID: cabin.id, channelID: "news")))
        }

        // MARK: Lookup and failures

        @Test("app-intents/a-clear-reply-when-a-channel-or-title-cannot-play a saved reference loads only its own source")
        func onlyItsSource() async throws {
            let harness = try harness()
            _ = await harness.channel(cabin.id, "news")
            #expect(harness.loads == [cabin.id])
        }

        @Test("app-intents/a-clear-reply-when-a-channel-or-title-cannot-play each failure is said and nothing opens")
        func failures() async throws {
            let failed = IntentFixtures.source("Basement", kind: .stalker)
            let unsynced = IntentFixtures.source("Garage", kind: .jellyfin)
            let harness = try harness(sources: [cabin, attic, failed, unsynced])
            harness.logins.remove(unsynced.id)
            let cases: [(LastChannelKey, IntentFailure)] = [
                (LastChannelKey(sourceID: cabin.id, channelID: "missing"), .channelGone(channel: nil, source: "Cabin")),
                (LastChannelKey(sourceID: UUID(), channelID: "news"), .channelSourceGone),
                (LastChannelKey(sourceID: unsynced.id, channelID: "a"), .loginMissing(source: "Garage")),
                (LastChannelKey(sourceID: failed.id, channelID: "a"), .offline),
            ]
            for (key, failure) in cases {
                let entity = try #require(await harness.channel(key.sourceID, key.channelID))
                #expect(entity.failure == failure)
                await #expect(throws: failure) { try await TuneChannelIntent(channel: entity).perform() }
            }
            #expect(harness.forwardRequests == 0)
            #expect(harness.host.inbox.pending == nil)
        }

        @Test("app-intents/a-clear-reply-when-a-channel-or-title-cannot-play an unparseable id is left out")
        func unparseable() async throws {
            let harness = try harness()
            defer { withExtendedLifetime(harness) {} }
            #expect(await IntentQueries.channels(["nonsense", "http://a:b@c/1.ts"]).isEmpty)
        }

        @Test("app-intents/a-clear-reply-when-a-channel-or-title-cannot-play a large source replies still loading, then plays")
        func largeSource() async throws {
            let harness = try harness()
            harness.holdLoads = true
            let first = try #require(await harness.channel(cabin.id, "news"))
            #expect(first.failure == .stillLoading)
            harness.release()
            await Task.yield()
            let second = try #require(await harness.channel(cabin.id, "news"))
            #expect(second.failure == nil)
            #expect(harness.loads == [cabin.id])
        }

        @Test("app-intents/a-clear-reply-when-a-channel-or-title-cannot-play two requests at once share one load")
        func sharedLoad() async throws {
            let harness = try harness()
            harness.holdLoads = true
            async let first = harness.channel(cabin.id, "news")
            async let second = harness.channel(cabin.id, "sport")
            let results = await [first, second]
            harness.release()
            #expect(results.count == 2)
            #expect(harness.loads == [cabin.id])
        }

        @Test("app-intents/a-clear-reply-when-a-channel-or-title-cannot-play a locked channel says so and opens nothing")
        func locked() async throws {
            let harness = try harness()
            let lock = GroupRecord(group: .named(cabin.id, "Kids"))
            lock.locked = true
            harness.context.insert(lock)
            try harness.context.save()
            let entity = try #require(await harness.channel(cabin.id, "kids"))
            await #expect(throws: IntentFailure.locked(channel: "Cartoons")) { try await TuneChannelIntent(channel: entity).perform() }
            #expect(harness.host.inbox.pending == nil)
        }

        // MARK: Matching and suggestions

        @Test("app-intents/siri-asks-which-when-two-channels-match two Sport Ones are both offered, told apart")
        func twoSportOnes() async throws {
            let harness = try harness()
            defer { withExtendedLifetime(harness) {} }
            let found = await IntentQueries.channels(matching: "sport one")
            #expect(found.map(\.subtitle) == ["2 · Sport · Cabin", "2 · Games · Attic"])
        }

        @Test("app-intents/ask-for-a-channel-by-name-or-number a typed name or number finds channels beyond the suggestions")
        func matching() async throws {
            let harness = try harness()
            defer { withExtendedLifetime(harness) {} }
            #expect(await IntentQueries.channels(matching: "NEWS").map(\.name) == ["News"])
            #expect(await IntentQueries.channels(matching: "3").map(\.name) == ["Cartoons"])
            #expect(await IntentQueries.channels(matching: "zebra").isEmpty)
        }

        @Test("app-intents/shortcuts-suggests-what-you-watch favorites first, titles in progress then My list")
        func suggestions() async throws {
            let harness = try harness()
            harness.context.insert(FavoriteRecord(channelID: "kids", sourceID: cabin.id, sortOrder: 0))
            harness.context.insert(FavoriteRecord(channelID: "sport", sourceID: attic.id, sortOrder: 1))
            let store = ActivityStore(context: harness.context)
            store.addToMyList("xtream#attic.example#vod#1", source: attic.id)
            store.saveProgress(titleID: "xtream#attic.example#series#2", source: attic.id, position: 30, duration: 100)
            try harness.context.save()
            let channels = await IntentQueries.suggestedChannels()
            #expect(channels.map(\.subtitle).prefix(2) == ["3 · Kids · Cabin", "2 · Games · Attic"])
            #expect(channels.count == 4)
            let titles = await IntentQueries.suggestedTitles()
            #expect(titles.map(\.name) == ["Northern Lights", "Harbor"])
            #expect(titles.map(\.subtitle) == ["Series · Attic", "Movie · Attic"])
        }

        // MARK: Play Title and Open Search

        @Test("app-intents/play-a-movie-or-series a movie or series by name comes forward")
        func play() async throws {
            let harness = try harness()
            let found = await IntentQueries.titles(matching: "harbor")
            let movie = try #require(found.first)
            _ = try await PlayTitleIntent(title: movie).perform()
            let reference = TitleReference(sourceID: attic.id, titleID: "xtream#attic.example#vod#1")
            #expect(harness.host.inbox.pending == .play(reference))
            let gone = try #require(await IntentQueries.titles(["\(attic.id.uuidString)/xtream#attic.example#vod#9"]).first)
            await #expect(throws: IntentFailure.titleGone(title: nil, source: "Attic")) { try await PlayTitleIntent(title: gone).perform() }
        }

        @Test("m3u-playlists/playlist-titles-show-on-every-platform: Siri finds a playlist movie with the app not running")
        func playlistTitle() async throws {
            let harness = try harness(sources: [cabin])
            harness.titles[cabin.id] = [ShelfTitle(id: "m3u.0123456789abcdef", kind: .movie, sourceID: cabin.id, name: "Film A")]
            let movie = try #require(await IntentQueries.titles(matching: "film").first)
            _ = try await PlayTitleIntent(title: movie).perform()
            #expect(harness.host.inbox.pending == .play(TitleReference(sourceID: cabin.id, titleID: "m3u.0123456789abcdef")))
        }

        @Test("app-intents/open-search with a query, without one, and with only spaces")
        func search() async throws {
            let harness = try harness()
            _ = try await OpenSearchIntent(query: "  news ").perform()
            #expect(harness.host.inbox.pending == .search("news"))
            _ = try await OpenSearchIntent(query: nil).perform()
            #expect(harness.host.inbox.pending == .search(nil))
            _ = try await OpenSearchIntent(query: "   ").perform()
            #expect(harness.host.inbox.pending == .search(nil))
        }

        // MARK: Toggle Favorite

        @Test("app-intents/change-a-favorite-without-opening-the-app add, remove and toggle say what they did")
        func favorites() async throws {
            let harness = try harness()
            harness.context.insert(FavoriteRecord(channelID: "news", sourceID: cabin.id, sortOrder: 4))
            try harness.context.save()
            let sport = try #require(await harness.channel(cabin.id, "sport"))
            let added = try await IntentActions.favorite(sport, mode: .add)
            #expect(added == .init(isFavorite: true, reply: "Added Sport One to favorites."))
            #expect(try harness.favorites().last?.sortOrder == 5)
            let again = try await IntentActions.favorite(sport, mode: .add)
            #expect(again.reply == "Sport One is already a favorite.")
            let removed = try await IntentActions.favorite(sport, mode: .remove)
            #expect(removed == .init(isFavorite: false, reply: "Removed Sport One from favorites."))
            let notOne = try await IntentActions.favorite(sport, mode: .remove)
            #expect(notOne.reply == "Sport One isn't a favorite.")
            let toggled = try await ToggleFavoriteIntent(channel: sport, mode: .toggle).perform()
            #expect(toggled.value == true)
            #expect(harness.forwardRequests == 0)
        }

        @Test("app-intents/change-a-favorite-without-opening-the-app remove takes every duplicate")
        func duplicates() async throws {
            let harness = try harness()
            harness.context.insert(FavoriteRecord(channelID: "news", sourceID: cabin.id, sortOrder: 0))
            harness.context.insert(FavoriteRecord(channelID: "news", sourceID: cabin.id, sortOrder: 1))
            try harness.context.save()
            let news = try #require(await harness.channel(cabin.id, "news"))
            _ = try await IntentActions.favorite(news, mode: .remove)
            #expect(try harness.favorites().isEmpty)
        }

        @Test("app-intents/change-a-favorite-without-opening-the-app nothing playing and before the first unlock")
        func favoriteRefusals() async throws {
            let harness = try harness()
            defer { withExtendedLifetime(harness) {} }
            await #expect(throws: IntentFailure.nothingPlaying) { try await IntentActions.favorite(nil, mode: .toggle) }
            let locked = try self.harness(data: false)
            await #expect(throws: IntentFailure.needsUnlock(.iPhone)) { try await IntentActions.favorite(nil, mode: .add) }
            withExtendedLifetime(locked) {}
        }

        @Test("app-intents/shortcuts-on-the-mac with Antenna closed three actions come forward and Toggle Favorite says nothing plays")
        func closedApp() async throws {
            let harness = try harness()
            let news = try #require(await harness.channel(cabin.id, "news"))
            let movie = try #require(await IntentQueries.titles(matching: "harbor").first)
            _ = try await TuneChannelIntent(channel: news).perform()
            _ = try await PlayTitleIntent(title: movie).perform()
            _ = try await OpenSearchIntent(query: nil).perform()
            #expect(harness.forwardRequests == 3)
            await #expect(throws: IntentFailure.nothingPlaying) { try await ToggleFavoriteIntent(channel: nil, mode: .toggle).perform() }
            #expect(harness.forwardRequests == 3)
        }

        @Test("app-intents/apple-tv-ships-no-actions the iPhone, iPad and Mac app carries the actions the Apple TV app leaves out")
        func metadataHere() {
            let metadata = Bundle(for: AppIntentHost.self).bundleURL.appending(path: "Metadata.appintents")
            #expect(FileManager.default.fileExists(atPath: metadata.path))
        }

        // MARK: Gate

        @Test("app-intents/nothing-works-until-antenna-is-unlocked-and-set-up every action refuses before the unlock or without sources")
        func gate() async throws {
            for (unlocked, failure) in [(false, IntentFailure.notUnlocked), (true, .noSources)] {
                let harness = try unlocked ? self.harness(sources: []) : self.harness(unlocked: false)
                let entity = ChannelEntity(id: LastChannelKey(sourceID: cabin.id, channelID: "news").string, failure: nil)
                let title = TitleEntity(id: "\(attic.id.uuidString)/xtream#attic.example#vod#1", failure: nil)
                await #expect(throws: failure) { try await TuneChannelIntent(channel: entity).perform() }
                await #expect(throws: failure) { try await PlayTitleIntent(title: title).perform() }
                await #expect(throws: failure) { try await OpenSearchIntent(query: "news").perform() }
                await #expect(throws: failure) { try await ToggleFavoriteIntent(channel: entity, mode: .toggle).perform() }
                #expect(await IntentQueries.suggestedChannels().isEmpty)
                #expect(harness.forwardRequests == 0)
                #expect(harness.host.inbox.pending == nil)
                #expect(harness.loads.isEmpty)
                #expect(try harness.favorites().isEmpty)
            }
        }

        // MARK: Privacy

        @Test("app-intents/shortcuts-never-hold-a-password references and descriptions hold no login or link")
        func privacy() async throws {
            let linked = IntentFixtures.source("http://alice:hunter2@iptv.example/get.php")
            let harness = try harness(sources: [linked])
            harness.playlists[linked.id] = [
                Channel(
                    id: "m3u:1", name: "News", streamURL: Self.link("http://alice:hunter2@iptv.example/live/alice/hunter2/1.ts"),
                    group: "Info", logoURL: Self.link("http://alice:hunter2@iptv.example/logo.png"), number: 1)
            ]
            let found = await IntentQueries.channels(matching: "news")
            let entity = try #require(found.first)
            #expect(entity.subtitle == "1 · Info · your source")
            #expect(entity.logo == nil)
            for text in [entity.id, entity.name, entity.subtitle] {
                #expect(!text.contains("alice") && !text.contains("hunter2") && !text.contains("iptv.example"))
            }
        }

        private static func link(_ text: String) -> URL {
            URL(string: text) ?? URL(filePath: "/")
        }
    }
#endif
