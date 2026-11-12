import Foundation
import Synchronization
import Testing

@testable import AntennaCore

@Suite struct JellyfinGuideTests {
    private static let now = Date(timeIntervalSince1970: 1_794_484_800)  // 2026-11-12 12:00 UTC

    @Test("jellyfin-live-tv-source/the-guide-covers-the-coming-week fetches 120 channels in batches over the window")
    func batches() async throws {
        let host = "jf-guide.local"
        let server = FakeJellyfin()
        let client = try server.client(host: host)
        let ids = (0..<120).map { "ch-\($0)" }
        let window = DateInterval(start: Self.now, duration: 7 * 86_400)
        let steps = Mutex<[String]>([])
        let list = try await client.programmes(channelIDs: ids, in: window) { done, total in
            steps.withLock { $0.append("\(done)/\(total)") }
        }
        #expect(list.items.map(\.channelID) == ids)
        #expect(list.skipped == 0)
        #expect(steps.withLock { $0 } == ["1/3", "2/3", "3/3"])

        let requests = JellyfinStubProtocol.requests(host: host).filter { $0.path.hasSuffix("/LiveTv/Programs") }
        #expect(requests.map { ($0.json?["ChannelIds"] as? [String])?.count } == [50, 50, 20])
        let body = try #require(requests.first?.json)
        #expect(requests.first?.request.httpMethod == "POST")
        #expect(body["MinEndDate"] as? String == "2026-11-12T12:00:00Z")
        #expect(body["MaxStartDate"] as? String == "2026-11-19T12:00:00Z")
        #expect(body["UserId"] as? String == server.userID)
        #expect(body["Limit"] as? Int == 10_000)
        #expect(body["StartIndex"] as? Int == 0)
        // The programme on air at noon started at 11:00, before the window.
        #expect(list.items.first?.start == Self.now.addingTimeInterval(-3600))
    }

    @Test("jellyfin-live-tv-source/the-guide-covers-the-coming-week follows a batch's pages")
    func pages() async throws {
        let host = "jf-guide-pages.local"
        let server = FakeJellyfin()
        server.on("LiveTv/Programs") { _, recorded in
            let start = recorded.json?["StartIndex"] as? Int ?? 0
            let count = start == 0 ? JellyfinClient.guidePageSize : 3
            let rows = (start..<start + count).map {
                #"{"Name":"P\#($0)","ChannelId":"ch-0","Id":"p\#($0)","StartDate":"2026-11-12T11:00:00Z","EndDate":"2026-11-12T13:00:00Z"}"#
            }
            let total = JellyfinClient.guidePageSize + 3
            return .http(200, Data(#"{"Items":[\#(rows.joined(separator: ","))],"TotalRecordCount":\#(total)}"#.utf8))
        }
        let client = try server.client(host: host)
        let list = try await client.programmes(channelIDs: ["ch-0"], in: DateInterval(start: Self.now, duration: 86_400))
        #expect(list.items.count == JellyfinClient.guidePageSize + 3)
        #expect(server.count("LiveTv/Programs") == 2)
    }

    @Test("jellyfin-live-tv-source/the-guide-covers-the-coming-week sends nothing for no channels")
    func noChannels() async throws {
        let host = "jf-guide-none.local"
        let server = FakeJellyfin()
        let store = CountingSessionStore()
        let client = try server.client(host: host, store: store)
        let list = try await client.programmes(channelIDs: [], in: DateInterval(start: Self.now, duration: 86_400))
        #expect(list.items.isEmpty)
        #expect(JellyfinStubProtocol.requests(host: host).isEmpty)
        #expect(await store.loads == 0)
    }

    @Test("jellyfin-live-tv-source/the-guide-covers-the-coming-week reads title, episode, description, genre, picture and times")
    func decode() throws {
        let server = try #require(URL(string: "https://jf.local/jellyfin"))
        let list = try JellyfinClient.decodeProgrammes(jellyfinFixture("programmes.json"), server: server)
        #expect(list.items.map(\.title) == ["Morning News", "Already On", "Late Show"])
        #expect(list.skipped == 5)
        let first = try #require(list.items.first)
        #expect(first.channelID == "c0ffee01")
        #expect(first.subtitle == "Tuesday")
        #expect(first.summary == "The day's headlines.")
        #expect(first.category == "News")
        #expect(first.iconURL?.absoluteString == "https://jf.local/jellyfin/Items/p1/Images/Primary?tag=ptag1")
        #expect(first.start == Date(timeIntervalSince1970: 1_794_463_200))
        #expect(first.stop == Date(timeIntervalSince1970: 1_794_466_800))
        #expect(list.items[1].stop == Date(timeIntervalSince1970: 1_794_472_200))
        #expect(list.items[2].start == Date(timeIntervalSince1970: 1_794_520_800.5))
        #expect(list.items[2].category == nil)
        #expect(list.items[2].iconURL == nil)
        #expect(try JellyfinClient.decodeProgrammes(Data(), server: server).items.isEmpty)
    }

    @Test("jellyfin-live-tv-source/a-broken-answer-is-an-error-not-a-crash a programme listed twice is skipped and counted")
    func repeatedProgramme() async throws {
        let host = "jf-guide-twice.local"
        let server = FakeJellyfin()
        server.on("LiveTv/Programs") { _, _ in
            let row = #"{"Name":"Same","ChannelId":"ch-0","Id":"p1","StartDate":"2026-11-12T11:00:00Z","EndDate":"2026-11-12T13:00:00Z"}"#
            return .http(200, Data(#"{"Items":[\#(row),\#(row)],"TotalRecordCount":2}"#.utf8))
        }
        let client = try server.client(host: host)
        let list = try await client.programmes(channelIDs: ["ch-0"], in: DateInterval(start: Self.now, duration: 86_400))
        #expect(list.items.count == 1)
        #expect(list.skipped == 1)
    }

    @Test(
        "jellyfin-live-tv-source/a-broken-answer-is-an-error-not-a-crash reads dates in each form the server writes",
        arguments: [
            ("2026-11-12T06:00:00.0000000Z", 1_794_463_200.0), ("2026-11-12T06:00:00Z", 1_794_463_200),
            ("2026-11-12T06:00:00", 1_794_463_200), ("2026-11-12T07:00:00+01:00", 1_794_463_200),
            ("2026-11-12T05:30:00-0030", 1_794_463_200), ("2024-02-29T00:00:00Z", 1_709_164_800),
            ("1969-12-31T23:59:59Z", -1),
        ])
    func dates(text: String, seconds: Double) {
        #expect(JellyfinWire.date(text) == Date(timeIntervalSince1970: seconds))
    }

    @Test(
        "jellyfin-live-tv-source/a-broken-answer-is-an-error-not-a-crash turns down unreadable dates",
        arguments: ["", "tomorrow", "2026-13-01T00:00:00Z", "2026-11-12T24:00:00Z", "2026-11-12T06:00:00.Z", "2026-11-12T06:00:00Zjunk"])
    func badDates(text: String) {
        #expect(JellyfinWire.date(text) == nil)
    }
}

/// Guide and channel decoding at the sizes the design names. Run with
/// `ANTENNA_BENCHMARKS=1 swift test`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"))
struct JellyfinBenchmarkTests {
    @Test("jellyfin-live-tv-source/every-channel-loads-however-many-there-are 20 000 channel rows decode in under 1 s")
    func channels() throws {
        let rows = (0..<20_000).map {
            #"{"Name":"Channel \#($0)","Id":"ch-\#($0)","ChannelNumber":"\#($0)","ChannelType":"TV","ImageTags":{"Primary":"t\#($0)"}}"#
        }
        let data = Data(#"{"Items":[\#(rows.joined(separator: ","))],"TotalRecordCount":20000}"#.utf8)
        let clock = ContinuousClock()
        let elapsed = try clock.measure { _ = try JellyfinClient.decodeChannels(data) }
        #expect(elapsed < .seconds(1))
    }

    @Test("jellyfin-live-tv-source/the-guide-covers-the-coming-week 100 000 programme rows decode in under 2 s")
    func programmes() throws {
        let rows = (0..<100_000).map {
            #"{"Name":"Show \#($0 % 500)","Overview":"About show \#($0 % 500).","Genres":["News"],"ChannelId":"ch-\#($0 % 600)","Id":"p\#($0)","StartDate":"2026-11-12T06:00:00.0000000Z","EndDate":"2026-11-12T07:00:00.0000000Z"}"#
        }
        let data = Data(#"{"Items":[\#(rows.joined(separator: ","))],"TotalRecordCount":100000}"#.utf8)
        let server = try #require(URL(string: "http://jf.local:8096"))
        let clock = ContinuousClock()
        let elapsed = try clock.measure { _ = try JellyfinClient.decodeProgrammes(data, server: server) }
        #expect(elapsed < .seconds(2))
    }
}
