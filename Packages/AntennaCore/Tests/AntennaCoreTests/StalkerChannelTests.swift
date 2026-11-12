import Foundation
import Testing

@testable import AntennaCore

/// The contents of `Fixtures/Stalker/<name>` as text.
func stalkerFixture(_ name: String) throws -> String {
    guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures/Stalker") else {
        throw CocoaError(.fileNoSuchFile)
    }
    return try String(contentsOf: url, encoding: .utf8)
}

@Suite struct StalkerChannelTests {
    private func loadedPortal(host: String) throws -> (FakePortal, StalkerClient) {
        let portal = FakePortal()
        let genres = try stalkerFixture("genres.json")
        let channels = try stalkerFixture("all_channels.json")
        portal.on("get_genres") { _, _ in .http(200, genres) }
        portal.on("get_all_channels") { _, _ in .http(200, channels) }
        return (portal, try portal.client(host: host))
    }

    @Test("stalker-portal-source/channels-show-up-grouped-by-genre load a portal")
    func loadPortal() async throws {
        let host = "ch-load.portal"
        let (_, client) = try loadedPortal(host: host)
        let load = try await client.liveLoad(guide: .xmltv)
        #expect(load.channels.map(\.name) == ["News One", "Sport Two", "Unknown Genre", "All Genre"])
        #expect(load.skippedChannels == 4)
        #expect(load.skippedGenres == 2)

        let news = try #require(load.channels.first)
        #expect(news.id == "stalker#\(host)#101")
        #expect(news.number == 1)
        #expect(news.group == "News")
        #expect(news.logoURL?.absoluteString == "http://\(host)/stalker_portal/misc/logos/320/101.png")
        #expect(news.epgID == "newsone.se")
        #expect(news.hasCatchup)
        #expect(news.catchupDays == 3)
        #expect(news.streamURL.absoluteString == "stalker://\(host)/101?cmd=ffrt%20http%3A%2F%2Flocalhost%2Fch%2F101_")

        let sport = load.channels[1]
        #expect(sport.group == "Sport")
        #expect(sport.logoURL?.absoluteString == "http://img.example/sport2.png")
        #expect(sport.epgID == nil)
        #expect(!sport.hasCatchup)
        #expect(sport.catchupDays == nil)

        #expect(load.channels[2].group == nil)
        #expect(load.channels[2].catchupDays == 1)
        #expect(load.channels[2].logoURL?.absoluteString == "http://\(host)/stalker_portal/misc/logos/240/103.png")
        #expect(load.channels[3].group == nil)
        #expect(load.channels[3].logoURL == nil)

        let again = try await client.liveLoad(guide: .xmltv)
        #expect(again.channels.map(\.id) == load.channels.map(\.id))
    }

    @Test("stalker-portal-source/channels-show-up-grouped-by-genre the channel list waits five minutes")
    func longTimeout() async throws {
        let host = "ch-timeout.portal"
        let (_, client) = try loadedPortal(host: host)
        _ = try await client.liveLoad(guide: .portal)
        let request = try #require(StalkerStubProtocol.requests(host: host).first { $0.action == "get_all_channels" })
        #expect(request.timeoutInterval == 300)
    }

    @Test("stalker-portal-source/channels-show-up-grouped-by-genre offline fails as no connection")
    func offline() async throws {
        let host = "ch-offline.portal"
        let (portal, client) = try loadedPortal(host: host)
        _ = try await client.liveLoad(guide: .portal)
        portal.on("get_genres") { _, _ in .failure(.notConnectedToInternet) }
        let error = await #expect(throws: StalkerError.self) { try await client.liveLoad(guide: .portal) }
        #expect(error?.isOffline == true)
    }

    @Test(
        "stalker-portal-source/channels-show-up-grouped-by-genre logos under each endpoint",
        arguments: [
            ("/stalker_portal/server/load.php", "/stalker_portal/misc/logos/320/7.png"),
            ("/server/load.php", "/misc/logos/320/7.png"),
            ("/portal.php", "/misc/logos/320/7.png"),
        ])
    func logoDirectories(apiPath: String, expected: String) async throws {
        let host = "ch-logo-\(apiPath.count).portal"
        let portal = FakePortal(apiPath: apiPath)
        portal.on("get_all_channels") { _, _ in
            .http(200, #"{"js":{"data":[{"id":"7","name":"Seven","cmd":"x http://a/b","logo":"7.png"}]}}"#)
        }
        let client = try portal.client(host: host)
        let load = try await client.liveLoad(guide: .portal)
        #expect(load.channels.first?.logoURL?.path() == expected)
        #expect(load.channels.first?.epgID == "7")
    }

    @Test("stalker-portal-source/channels-show-up-grouped-by-genre the portal's guide matches by channel id")
    func portalGuideIDs() async throws {
        let (_, client) = try loadedPortal(host: "ch-guide-ids.portal")
        let load = try await client.liveLoad(guide: .portal)
        #expect(load.channels.map(\.epgID) == ["101", "102", "103", "104"])
    }

    @Test("stalker-portal-source/a-broken-answer-is-an-error-not-a-crash unreadable answers quote nothing")
    func unreadable() async throws {
        for (index, body) in ["<!DOCTYPE html><html><body>Login</body></html>", "<?xml version=\"1.0\"?><js/>", "", "   \n"].enumerated() {
            let host = "ch-unreadable-\(index).portal"
            let portal = FakePortal()
            portal.on("get_genres") { _, _ in .http(200, body) }
            let client = try portal.client(host: host)
            await #expect(throws: StalkerError.unreadable) { try await client.liveLoad(guide: .portal) }
        }
    }

    @Test("stalker-portal-source/a-broken-answer-is-an-error-not-a-crash empty shapes give no channels")
    func emptyShapes() async throws {
        for (index, body) in [#"{"js":false}"#, #"{"js":[]}"#, #"{"js":{}}"#, #"{"js":{"data":"x"}}"#].enumerated() {
            let host = "ch-empty-\(index).portal"
            let portal = FakePortal()
            portal.on("get_all_channels") { _, _ in .http(200, body) }
            let client = try portal.client(host: host)
            #expect(try await client.liveLoad(guide: .portal).channels.isEmpty)
        }
    }

    @Test("stalker-portal-source/secrets-never-show-up-in-messages-or-logs a channel prints without its stream address")
    func channelPrinting() async throws {
        let (_, client) = try loadedPortal(host: "ch-print.portal")
        let channel = try #require(try await client.liveLoad(guide: .portal).channels.first)
        var dumped = ""
        dump(channel, to: &dumped)
        for printed in ["\(channel)", String(reflecting: channel), dumped] {
            #expect(!printed.contains("localhost"))
            #expect(!printed.contains("stalker://"))
            #expect(!printed.contains("ch-print.portal"))
        }
    }
}
