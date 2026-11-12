import Foundation
import Testing

@testable import AntennaCore

@Suite struct JellyfinChannelTests {
    @Test("jellyfin-live-tv-source/every-channel-loads-however-many-there-are 2 345 channels arrive in order")
    func largeServer() async throws {
        let host = "jf-large.local"
        let server = FakeJellyfin()
        server.channelCount = 2_345
        let client = try server.client(host: host)
        let list = try await client.liveChannels()
        #expect(list.items.count == 2_345)
        #expect(list.skipped == 0)
        #expect(list.items.map(\.name) == (0..<2_345).map { "Channel \($0)" })
        let pages = JellyfinStubProtocol.requests(host: host).filter { $0.path.hasSuffix("/LiveTv/Channels") }
        #expect(pages.map { $0.query["StartIndex"] } == ["0", "1000", "2000"])
        let first = try #require(pages.first)
        #expect(first.query["Limit"] == "1000")
        #expect(first.query["UserId"] == server.userID)
        #expect(first.query["api_key"] == nil)
    }

    @Test("jellyfin-live-tv-source/every-channel-loads-however-many-there-are stops at a short page when no total is given")
    func shortPage() async throws {
        let host = "jf-short.local"
        let server = FakeJellyfin()
        server.channelCount = 1_500
        server.reportedTotal = .some(nil)
        let client = try server.client(host: host)
        #expect(try await client.liveChannels().items.count == 1_500)
        #expect(server.count("LiveTv/Channels") == 2)
    }

    @Test("jellyfin-live-tv-source/every-channel-loads-however-many-there-are cuts the list off at 100 000")
    func ceiling() async throws {
        let host = "jf-ceiling.local"
        let server = FakeJellyfin()
        server.channelCount = 100_500
        let client = try server.client(host: host)
        let list = try await client.liveChannels()
        #expect(list.items.count == 100_000)
        #expect(server.count("LiveTv/Channels") == 100)
        #expect(list.items.last?.name == "Channel 99999")
    }

    @Test("jellyfin-live-tv-source/channels-show-their-name-number-and-logo maps rows onto catalogue channels")
    func mapping() async throws {
        let host = "jf.local"
        let server = FakeJellyfin()
        let page = try jellyfinFixture("channels.json")
        server.on("LiveTv/Channels") { _, _ in .http(200, page) }
        let client = try server.client(host: host, server: "https://jf.local:8920/jellyfin/")
        let list = try await client.liveChannels()
        #expect(list.items.map(\.name) == ["News One", "Sport Two", "Jazz Radio", "No Number"])
        #expect(list.skipped == 5)

        let news = try #require(list.items.first)
        #expect(news.id == "jellyfin#jf.local#c0ffee01")
        #expect(news.number == 101)
        #expect(news.group == nil)
        #expect(news.epgID == "c0ffee01")
        #expect(news.logoURL?.absoluteString == "https://jf.local:8920/jellyfin/Items/c0ffee01/Images/Primary?tag=tag01")
        #expect(!news.hasCatchup)
        #expect(news.catchupDays == nil)
        #expect(news.catchupMode == nil)
        #expect(list.items[1].number == nil)
        #expect(list.items[1].logoURL == nil)
        #expect(list.items[2].group == "Radio")
        #expect(list.items[3].number == nil)
    }

    @Test(
        "jellyfin-live-tv-source/channels-show-their-name-number-and-logo the id depends on the host alone",
        arguments: ["http://JF.local:8096", "https://jf.local", "https://jf.local:8920/jellyfin/", "http://jf.local/"])
    func hostOnlyIdentity(address: String) throws {
        let client = JellyfinClient(
            credentials: JellyfinCredentials(server: try #require(URL(string: address)), username: "u", password: "p"),
            device: JellyfinDevice(id: "d", name: "iPhone", appVersion: "1"), sessionStore: JellyfinMemorySessionStore())
        let row = JellyfinChannel(id: "abc", name: "A", number: 1, isRadio: false, primaryImageTag: nil)
        #expect(client.channel(from: row, token: "k").id == "jellyfin#jf.local#abc")
    }

    @Test("jellyfin-live-tv-source/channels-show-their-name-number-and-logo two host names give two identities")
    func twoHosts() throws {
        let row = JellyfinChannel(id: "abc", name: "A", number: 1, isRadio: false, primaryImageTag: nil)
        let ids = try ["http://jf.local:8096", "http://192.168.1.20:8096"].map { address in
            JellyfinClient(
                credentials: JellyfinCredentials(server: try #require(URL(string: address)), username: "u", password: "p"),
                device: JellyfinDevice(id: "d", name: "iPhone", appVersion: "1"), sessionStore: JellyfinMemorySessionStore()
            ).channel(from: row, token: "k").id
        }
        #expect(ids == ["jellyfin#jf.local#abc", "jellyfin#192.168.1.20#abc"])
    }

    @Test("jellyfin-live-tv-source/a-broken-answer-is-an-error-not-a-crash skips and counts broken rows")
    func brokenRows() throws {
        let (list, total) = try JellyfinClient.decodeChannels(jellyfinFixture("channels.json"))
        #expect(list.items.map(\.id) == ["c0ffee01", "c0ffee02", "c0ffee03", "c0ffee04"])
        #expect(list.skipped == 5)
        #expect(total == 9)
        let (empty, _) = try JellyfinClient.decodeChannels(Data())
        #expect(empty == DecodedList(items: [], skipped: 0))
        let (none, _) = try JellyfinClient.decodeChannels(Data(#"{"Items":[],"TotalRecordCount":0}"#.utf8))
        #expect(none.items.isEmpty)
    }

    @Test(
        "jellyfin-live-tv-source/a-broken-answer-is-an-error-not-a-crash fails web pages and answers that are not lists",
        arguments: [
            ("<!DOCTYPE html><html><body>502 Bad Gateway secret-token</body></html>", "$"),
            (#"[{"Id":"x"}]"#, "$"),
            (#"{"Items":"secret-token"}"#, "Items"),
            (#"{"Error":"secret-token"}"#, "Items"),
            ("null", "$"),
        ])
    func brokenAnswers(body: String, path: String) async throws {
        #expect(throws: JellyfinClient.JellyfinError.decoding(path: path)) { try JellyfinClient.decodeChannels(Data(body.utf8)) }
        #expect(throws: JellyfinClient.JellyfinError.decoding(path: path)) {
            try JellyfinClient.decodeProgrammes(Data(body.utf8), server: URL(filePath: "/"))
        }
        let host = "jf-proxy-\(abs(body.hashValue)).local"
        let server = FakeJellyfin()
        server.on("LiveTv/Channels") { _, _ in .http(200, Data(body.utf8)) }
        let client = try server.client(host: host)
        do {
            _ = try await client.liveChannels()
            Issue.record("expected a reading error")
        } catch {
            #expect(error as? JellyfinClient.JellyfinError == .decoding(path: path))
            #expect(!"\(error)".contains("secret-token"))
            #expect(!String(reflecting: error).contains("secret-token"))
        }
    }

    @Test("jellyfin-live-tv-source/streams-play-and-logos-stay-key-free builds addresses with and without a server path")
    func addresses() throws {
        for (address, base) in [
            ("http://jf.local:8096", "http://jf.local:8096"), ("https://jf.local/jellyfin/", "https://jf.local/jellyfin"),
        ] {
            let client = JellyfinClient(
                credentials: JellyfinCredentials(server: try #require(URL(string: address)), username: "u", password: "p"),
                device: JellyfinDevice(id: "d", name: "iPhone", appVersion: "1"), sessionStore: JellyfinMemorySessionStore())
            let stream = client.streamURL(channelID: "c0ffee01", token: "K+1/2")
            #expect(stream.absoluteString == "\(base)/Videos/c0ffee01/stream?static=true&api_key=K%2B1%2F2")
            #expect(EngineRouter.route(for: stream) == .demuxer)
            let logo = client.logoURL(channelID: "c0ffee01", tag: "tag01")
            #expect(logo.absoluteString == "\(base)/Items/c0ffee01/Images/Primary?tag=tag01")
            let row = JellyfinChannel(id: "c0ffee01", name: "A", number: nil, isRadio: false, primaryImageTag: "tag01")
            let channel = client.channel(from: row, token: "K+1/2")
            #expect(channel.streamURL == stream)
            #expect(channel.logoURL?.absoluteString.contains("api_key") == false)
        }
    }
}
