import Foundation
import Testing

@testable import AntennaCore

/// Reading catch-up details from playlists and Xtream panels.
@Suite struct CatchupDetailsTests {
    static func parse(_ text: String) throws -> Channel {
        try #require(M3UParser().parse(text).channels.first)
    }

    @Test("m3u-playlists/catch-up-style-source-and-correction: full catch-up details")
    func fullDetails() throws {
        let channel = try Self.parse(
            """
            #EXTM3U
            #EXTINF:-1 catchup="shift" catchup-source="?utc={utc}" catchup-correction="-1",Name
            http://s/n.ts
            """)
        #expect(channel.catchupMode == .shift)
        #expect(channel.catchupSource == "?utc={utc}")
        #expect(channel.catchupCorrectionHours == -1)
    }

    @Test("m3u-playlists/catch-up-style-source-and-correction: the design's default entry")
    func defaultEntry() throws {
        let channel = try Self.parse(
            """
            #EXTM3U
            #EXTINF:-1 catchup="default" catchup-source="http://a/arc?utc={utc}&d={duration}" catchup-correction="-1.5" catchup-days="7",Name
            http://s/n.ts
            """)
        #expect(channel.catchupMode == .default)
        #expect(channel.catchupSource == "http://a/arc?utc={utc}&d={duration}")
        #expect(channel.catchupCorrectionHours == -1.5)
        #expect(channel.hasCatchup)
        #expect(channel.catchupDays == 7)
    }

    @Test("m3u-playlists/catch-up-style-source-and-correction: a correction that is not a number")
    func badCorrection() throws {
        let channel = try Self.parse(
            """
            #EXTM3U
            #EXTINF:-1 catchup="shift" catchup-correction="abc",Name
            http://s/n.ts
            """)
        #expect(channel.name == "Name")
        #expect(channel.catchupCorrectionHours == nil)
        #expect(channel.catchupMode == .shift)
    }

    @Test("m3u-playlists/catch-up-style-source-and-correction: no details give nil for all three")
    func noDetails() throws {
        let channel = try Self.parse(
            """
            #EXTM3U
            #EXTINF:-1 tvg-id="a",Name
            http://s/n.ts
            """)
        #expect(channel.catchupMode == nil)
        #expect(channel.catchupSource == nil)
        #expect(channel.catchupCorrectionHours == nil)
    }

    @Test(
        "m3u-playlists/catch-up-style-source-and-correction: style names",
        arguments: [
            ("default", CatchupMode.default), ("append", .append), ("shift", .shift), ("flussonic", .flussonic), ("fs", .flussonic),
            ("xc", .xc), ("vod", .unsupported("vod")), ("SHIFT", .shift),
        ] as [(String, CatchupMode)])
    func styleNames(attribute: String, mode: CatchupMode) {
        #expect(CatchupMode(attribute: attribute) == mode)
    }

    @Test("xtream-live-source/archive-channels-use-xtream-catch-up: archive flag set and off")
    func archiveFlag() throws {
        let client = XtreamClient(
            credentials: XtreamCredentials(server: try #require(URL(string: "http://panel:8080")), username: "u", password: "p"))
        func channel(_ json: String) throws -> Channel {
            client.channel(from: try JSONDecoder().decode(XtreamLiveStream.self, from: Data(json.utf8)), categoryName: nil)
        }
        let on = try channel(#"{"stream_id":42,"name":"A","tv_archive":1}"#)
        #expect(on.catchupMode == .xc)
        #expect(on.catchupSource == nil)
        #expect(on.catchupCorrectionHours == nil)
        #expect(try channel(#"{"stream_id":42,"name":"A","tv_archive":0}"#).catchupMode == nil)
        #expect(try channel(#"{"stream_id":42,"name":"A"}"#).catchupMode == nil)
    }

    @Test("timeshift-catch-up-and-start-over/logins-stay-private: encoding a channel leaves the catch-up details out")
    func encodingDropsDetails() throws {
        let channel = Channel(
            id: "a", name: "A", streamURL: try #require(URL(string: "http://s/live/u/p/1.ts")), hasCatchup: true, catchupMode: .xc,
            catchupSource: "http://s/arc?user=secret", catchupCorrectionHours: 2)
        let data = try JSONEncoder().encode(channel)
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("secret"))
        #expect(!text.contains("catchupMode"))
        #expect(!text.contains("catchupCorrection"))
        let decoded = try JSONDecoder().decode(Channel.self, from: data)
        #expect(decoded.catchupMode == nil)
        #expect(decoded.catchupSource == nil)
        #expect(decoded.catchupCorrectionHours == nil)
        #expect(decoded.hasCatchup)
    }
}
