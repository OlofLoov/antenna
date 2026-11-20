import Foundation
import Testing

@testable import AntennaCore

/// The contents of `Fixtures/Adult/<name>`.
func adultFixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures/Adult"))
    return try Data(contentsOf: url)
}

/// One name from `Fixtures/Adult/names.json` and the rule it checks.
struct AdultName: Decodable, CustomTestStringConvertible, Sendable {
    let name: String
    let rule: String

    var testDescription: String { "\(name.isEmpty ? "(empty)" : name): \(rule)" }

    static func load() throws -> (adult: [AdultName], notAdult: [AdultName]) {
        struct File: Decodable {
            let adult: [AdultName]
            let notAdult: [AdultName]
        }
        let file = try JSONDecoder().decode(File.self, from: try adultFixture("names.json"))
        return (file.adult, file.notAdult)
    }
}

@Suite struct AdultContentTests {
    @Test(
        "adult-content/adult-groups-are-found-by-name every adult spelling in the fixture is found", arguments: try AdultName.load().adult)
    func adultNames(_ entry: AdultName) {
        #expect(AdultContent.isAdultName(entry.name))
    }

    @Test(
        "adult-content/adult-groups-are-found-by-name harmless names in the fixture are not adult", arguments: try AdultName.load().notAdult
    )
    func harmlessNames(_ entry: AdultName) {
        #expect(!AdultContent.isAdultName(entry.name))
    }

    @Test("adult-content/the-provider-s-adult-flag-counts only XXX and AO ratings are adult")
    func ratings() {
        #expect(AdultContent.isAdultRating("XXX"))
        #expect(AdultContent.isAdultRating(" ao "))
        #expect(AdultContent.isAdultRating("US-AO"))
        for rating in ["NC-17", "R", "TV-MA", "FSK 18", "R18", "", nil] as [String?] {
            #expect(!AdultContent.isAdultRating(rating))
        }
    }

    @Test("adult-content/the-provider-s-adult-flag-counts Xtream live streams and categories carry is_adult")
    func xtreamLive() async throws {
        let host = "adult-live.panel"
        XtreamActionStub.register(
            host: host, action: "get_live_categories",
            body: String(decoding: try adultFixture("xtream_live_categories.json"), as: UTF8.self))
        XtreamActionStub.register(
            host: host, action: "get_live_streams", body: String(decoding: try adultFixture("xtream_live_streams.json"), as: UTF8.self))
        XtreamActionStub.register(host: host, action: nil, body: #"{"user_info":{"auth":1}}"#)
        let load = try await XtreamTimeZoneTests.client(host: host).liveLoad()
        let adult = Dictionary(uniqueKeysWithValues: load.channels.map { ($0.name, $0.isAdult) })
        #expect(adult["News One"] == false)
        #expect(adult["Late Channel"] == true)
        #expect(adult["Night One"] == true, "its category carries the flag")
        #expect(adult["Sport One"] == false)
        #expect(adult["Sport Two"] == true, "1 as a number")
        #expect(adult["Sport Three"] == true, "true as a JSON boolean")
        #expect(adult["Sport Four"] == false, "any other value is not the flag")
    }

    @Test("adult-content/the-provider-s-adult-flag-counts Xtream movies and series carry is_adult on the row or the category")
    func xtreamTitles() throws {
        let source = UUID()
        let categories = try JSONDecoder().decode([XtreamCategory].self, from: try adultFixture("xtream_vod_categories.json"))
        let movies = try XtreamClient.decodeVODList(try adultFixture("xtream_vod_streams.json"), host: "adult-vod.panel").items
        let catalogue = ShelfCatalogue(movies: movies, categories: categories, sourceID: source)
        let flagged = Dictionary(uniqueKeysWithValues: catalogue.titles.map { ($0.name, $0.isAdult) })
        #expect(flagged == ["Long Winter": false, "Flagged Film": true, "Night Film": true, "Named Film": false])
        let content = Dictionary(uniqueKeysWithValues: catalogue.titles.map { ($0.name, $0.isAdultContent) })
        #expect(content["Named Film"] == true, "its category's name is adult")

        let series = try XtreamClient.decodeSeriesList(try adultFixture("xtream_series.json"), host: "adult-vod.panel").items
        #expect(series.map(\.isAdult) == [false, true])
    }

    @Test("adult-content/the-provider-s-adult-flag-counts Stalker channels and genres marked censored")
    func stalker() async throws {
        let portal = FakePortal()
        let genres = String(decoding: try adultFixture("stalker_genres.json"), as: UTF8.self)
        let channels = String(decoding: try adultFixture("stalker_channels.json"), as: UTF8.self)
        portal.on("get_genres") { _, _ in .http(200, genres) }
        portal.on("get_all_channels") { _, _ in .http(200, channels) }
        let load = try await portal.client(host: "adult.portal").liveLoad(guide: .xmltv)
        let adult = Dictionary(uniqueKeysWithValues: load.channels.map { ($0.name, $0.isAdult) })
        #expect(adult == ["News One": false, "Late One": true, "Night One": true, "Sport One": false])
    }

    @Test("adult-content/the-provider-s-adult-flag-counts Jellyfin channels rated XXX or AO")
    func jellyfin() throws {
        let (list, _) = try JellyfinClient.decodeChannels(try adultFixture("jellyfin_channels.json"))
        #expect(list.items.map(\.isAdult) == [false, true, true, false, false])
    }
}
