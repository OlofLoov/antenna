import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// The seed data behind `-ui-screenshots`. Tooling for the screenshot
/// walk-throughs, so these tests cite no requirement.
@MainActor
@Suite struct UITestingScreenshotsTests {
    @Test func fullHasTwoSourcesAndFourFavorites() throws {
        let container = try #require(UITestingScreenshots.container(arguments: ["app", "-ui-screenshots", "full"]))
        let context = container.mainContext
        #expect(try context.fetchCount(FetchDescriptor<SourceRecord>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<FavoriteRecord>()) == 4)
    }

    @Test func homeLoadsTwelveChannelsInThreeGroups() async throws {
        let home = try #require(try UITestingScreenshots.sources().first)
        let playlist = try await SourceLoader().load(home)
        #expect(playlist.channels.count == 12)
        #expect(Set(playlist.channels.compactMap(\.group)) == ["News", "Sport", "Movies"])
    }

    @Test func favoritesNameChannelsInHome() {
        let ids = Set(UITestingScreenshots.channels.map(\.id))
        #expect(UITestingScreenshots.favoriteIDs.allSatisfy(ids.contains))
    }

    @Test func emptyHasNoSources() throws {
        let container = try #require(UITestingScreenshots.container(arguments: ["app", "-ui-screenshots", "empty"]))
        #expect(try container.mainContext.fetchCount(FetchDescriptor<SourceRecord>()) == 0)
    }

    @Test func noArgumentMeansNoSeed() {
        #expect(UITestingScreenshots.container(arguments: ["app"]) == nil)
    }
}
