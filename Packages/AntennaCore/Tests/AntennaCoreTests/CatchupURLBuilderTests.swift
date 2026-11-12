import Foundation
import Testing

@testable import AntennaCore

/// The worked examples and refusal rows under "Catch-up addresses" in the change's design.md.
@Suite struct CatchupURLBuilderTests {
    static let start = Date(timeIntervalSince1970: 1_793_822_400)  // 2026-11-04T20:00:00Z
    static let request = CatchupRequest(start: start, duration: 3600, now: start.addingTimeInterval(2400))
    static let utc = TimeZone.gmt
    static let stockholm = TimeZone(identifier: "Europe/Stockholm")

    static func url(_ text: String) throws -> URL {
        try #require(URL(string: text))
    }

    static func channel(
        _ mode: CatchupMode?, stream: String = "http://a/live/7.ts", source: String? = nil, correction: Double? = nil,
        id: String = "m3u#x#1", days: Int? = nil, hasCatchup: Bool = true
    ) throws -> Channel {
        Channel(
            id: id, name: "Seven", streamURL: try url(stream), hasCatchup: hasCatchup, catchupDays: days, catchupMode: mode,
            catchupSource: source, catchupCorrectionHours: correction)
    }

    static func build(_ channel: Channel, request: CatchupRequest = request, xtream: XtreamCatchupContext? = nil) -> String? {
        CatchupURLBuilder.url(for: channel, request: request, xtream: xtream, deviceTimeZone: .gmt)?.absoluteString
    }

    static func build(_ channel: Channel, request: CatchupRequest = request, zone: TimeZone) -> String? {
        CatchupURLBuilder.url(for: channel, request: request, xtream: nil, deviceTimeZone: zone)?.absoluteString
    }

    static func xtreamContext(zone: String?) throws -> XtreamCatchupContext {
        XtreamCatchupContext(
            credentials: XtreamCredentials(server: try url("http://panel:8080"), username: "u", password: "p"), timeZoneName: zone)
    }

    // timeshift-catch-up-and-start-over/catch-up-asks-the-provider-the-way-it-expects

    @Test("timeshift-catch-up-and-start-over/catch-up-asks-the-provider-the-way-it-expects: default template fills every placeholder")
    func defaultTemplate() throws {
        let template = "http://a/arc?s={utc}&e={utcend}&d={duration}&m={duration:60}&o={offset}&n={lutc}&t={Y}-{m}-{d}_{H}-{M}-{S}"
        let channel = try Self.channel(.default, source: template, correction: 1)
        #expect(
            Self.build(channel)
                == "http://a/arc?s=1793822400&e=1793826000&d=3600&m=60&o=2400&n=1793824800&t=2026-11-04_21-00-00")
    }

    @Test("timeshift-catch-up-and-start-over/catch-up-asks-the-provider-the-way-it-expects: aliases and dollar placeholders")
    func defaultAliases() throws {
        let channel = try Self.channel(.default, source: "http://a/arc?s=${start}&e={end}&n={now}&t={timestamp}&o={offset:60}")
        #expect(Self.build(channel) == "http://a/arc?s=1793822400&e=1793826000&n=1793824800&t=1793824800&o=40")
    }

    @Test("timeshift-catch-up-and-start-over/catch-up-asks-the-provider-the-way-it-expects: minutes round up")
    func minutesRoundUp() throws {
        let channel = try Self.channel(.default, source: "http://a/arc?m={duration:60}&o={offset:60}")
        let request = CatchupRequest(start: Self.start, duration: 3601, now: Self.start.addingTimeInterval(61))
        #expect(Self.build(channel, request: request) == "http://a/arc?m=61&o=2")
    }

    @Test("timeshift-catch-up-and-start-over/catch-up-asks-the-provider-the-way-it-expects: append and shift")
    func appendAndShift() throws {
        let expected = "http://a/live/7.ts?utc=1793822400&lutc=1793824800"
        #expect(Self.build(try Self.channel(.append, source: "?utc={utc}&lutc={lutc}")) == expected)
        #expect(Self.build(try Self.channel(.shift)) == expected)
        let withQuery = try Self.channel(.shift, stream: "http://a/live/7.ts?token=x")
        #expect(Self.build(withQuery) == "http://a/live/7.ts?token=x&utc=1793822400&lutc=1793824800")
        #expect(Self.build(try Self.channel(.append)) == nil)
    }

    @Test(
        "timeshift-catch-up-and-start-over/catch-up-asks-the-provider-the-way-it-expects: flussonic",
        arguments: [
            ("http://a/ch/index.m3u8", "http://a/ch/index-1793822400-3600.m3u8"),
            ("http://a/ch/video.m3u8", "http://a/ch/video-1793822400-3600.m3u8"),
            ("http://a/ch/mono.m3u8", "http://a/ch/mono-1793822400-3600.m3u8"),
            ("http://a/ch/mpegts", "http://a/ch/archive-1793822400-3600.ts"),
            ("http://a/ch/index.m3u8?token=x", "http://a/ch/index-1793822400-3600.m3u8?token=x"),
            ("http://a/ch/stream.ts", nil),
        ] as [(String, String?)])
    func flussonic(stream: String, expected: String?) throws {
        #expect(Self.build(try Self.channel(.flussonic, stream: stream)) == expected)
        #expect(Self.build(try Self.channel(CatchupMode(attribute: "fs"), stream: stream)) == expected)
    }

    @Test("timeshift-catch-up-and-start-over/catch-up-asks-the-provider-the-way-it-expects: Xtream archive")
    func xtreamArchive() throws {
        let request = CatchupRequest(start: Self.start, duration: 2700, now: Self.start.addingTimeInterval(600))
        let context = try Self.xtreamContext(zone: "Europe/Stockholm")
        let expected = "http://panel:8080/timeshift/u/p/45/2026-11-04:21-00/42.ts"
        let client = XtreamClient(credentials: context.credentials)
        #expect(
            client.timeshiftURL(streamID: 42, start: Self.start, durationMinutes: 45, timeZone: Self.stockholm).absoluteString == expected)
        #expect(
            client.timeshiftURL(streamID: 42, start: Self.start, durationMinutes: 45, timeZone: nil).absoluteString
                == "http://panel:8080/timeshift/u/p/45/2026-11-04:20-00/42.ts")
        let channel = try Self.channel(.xc, stream: "http://panel:8080/live/u/p/42.ts", id: "xtream#panel#42")
        #expect(Self.build(channel, request: request, xtream: context) == expected)
    }

    @Test("timeshift-catch-up-and-start-over/catch-up-asks-the-provider-the-way-it-expects: Xtream login is percent-encoded")
    func xtreamEncoding() throws {
        let context = XtreamCatchupContext(
            credentials: XtreamCredentials(server: try Self.url("http://panel:8080"), username: "a b", password: "p/w"), timeZone: Self.utc)
        let channel = try Self.channel(.xc, id: "xtream#panel#42")
        #expect(Self.build(channel, xtream: context) == "http://panel:8080/timeshift/a%20b/p%2Fw/60/2026-11-04:20-00/42.ts")
    }

    @Test("timeshift-catch-up-and-start-over/catch-up-asks-the-provider-the-way-it-expects: a provider in another time zone")
    func playlistXC() throws {
        let request = CatchupRequest(start: Self.start, duration: 2700, now: Self.start.addingTimeInterval(600))
        let zone = try #require(Self.stockholm)
        let channel = try Self.channel(.xc, stream: "http://a/live/u/p/42.ts", correction: 0)
        #expect(Self.build(channel, request: request, zone: zone) == "http://a/timeshift/u/p/45/2026-11-04:21-00/42.ts")
        // The wrong hour without a correction, put right by one.
        #expect(Self.build(channel, request: request, zone: Self.utc) == "http://a/timeshift/u/p/45/2026-11-04:20-00/42.ts")
        let corrected = try Self.channel(.xc, stream: "http://a/live/u/p/42.ts", correction: 1)
        #expect(Self.build(corrected, request: request, zone: Self.utc) == "http://a/timeshift/u/p/45/2026-11-04:21-00/42.ts")
        #expect(Self.build(try Self.channel(.xc, stream: "http://a/play/u/p/42.ts"), request: request, zone: zone) == nil)
    }

    @Test("timeshift-catch-up-and-start-over/catch-up-asks-the-provider-the-way-it-expects: daylight saving")
    func daylightSaving() throws {
        // Clocks in Stockholm go from 02:00 to 03:00 at 2027-03-28T01:00:00Z.
        let before = Date(timeIntervalSince1970: 1_806_193_800)  // 2027-03-28T00:30:00Z, 01:30 CET
        let after = before.addingTimeInterval(3600)  // 01:30Z, 03:30 CEST
        let context = try Self.xtreamContext(zone: "Europe/Stockholm")
        let channel = try Self.channel(.xc, id: "xtream#panel#42")
        let now = after.addingTimeInterval(1800)
        #expect(
            Self.build(channel, request: CatchupRequest(start: before, duration: 7200, now: now), xtream: context)
                == "http://panel:8080/timeshift/u/p/120/2027-03-28:01-30/42.ts")
        #expect(
            Self.build(channel, request: CatchupRequest(start: after, duration: 1800, now: now), xtream: context)
                == "http://panel:8080/timeshift/u/p/30/2027-03-28:03-30/42.ts")
        let template = try Self.channel(.default, source: "http://a/arc?s={utc}&h={H}-{M}")
        let zone = try #require(Self.stockholm)
        #expect(
            Self.build(template, request: CatchupRequest(start: after, duration: 1800, now: now), zone: zone)
                == "http://a/arc?s=1806197400&h=03-30")
    }

    @Test("timeshift-catch-up-and-start-over/catch-up-asks-the-provider-the-way-it-expects: refusals request nothing")
    func refusals() throws {
        let later = CatchupRequest(start: Self.start.addingTimeInterval(60), duration: 3600, now: Self.start)
        let empty = CatchupRequest(start: Self.start, duration: 0, now: Self.start)
        let old = CatchupRequest(start: Self.start, duration: 3600, now: Self.start.addingTimeInterval(8 * 86400))
        let template = "http://a/arc?s={utc}"
        let rows: [String?] = [
            Self.build(try Self.channel(.default, source: template, hasCatchup: false)),
            Self.build(try Self.channel(.unsupported("vod"), source: template)),
            Self.build(try Self.channel(CatchupMode(attribute: "weird"), source: template)),
            Self.build(try Self.channel(.default, source: "http://a/arc?s={bogus}")),
            Self.build(try Self.channel(.default, source: "http://a/arc?s={utc")),
            Self.build(try Self.channel(.default)),
            Self.build(try Self.channel(.xc, id: "xtream#panel#42")),
            Self.build(try Self.channel(.xc, id: "xtream#panel#42"), xtream: try Self.xtreamContext(zone: nil)),
            Self.build(try Self.channel(.xc, id: "xtream#panel#42"), xtream: try Self.xtreamContext(zone: "Mars/Olympus")),
            Self.build(try Self.channel(.default, source: template), request: later),
            Self.build(try Self.channel(.default, source: template), request: empty),
            Self.build(try Self.channel(.default, source: template, days: 7), request: old),
            Self.build(try Self.channel(.default, source: "ftp://a/arc?s={utc}")),
            Self.build(try Self.channel(.shift, stream: "rtmp://a/live/7")),
        ]
        #expect(rows.allSatisfy { $0 == nil })
        // Within the kept days, and with no limit, an address is built.
        #expect(Self.build(try Self.channel(.default, source: template, days: 9), request: old) != nil)
        #expect(Self.build(try Self.channel(.default, source: template), request: old) != nil)
    }

    @Test("timeshift-catch-up-and-start-over/logins-stay-private: the Xtream context prints the host only")
    func contextDescription() throws {
        let login = XtreamCredentials(server: try Self.url("http://panel:8080"), username: "secret-user", password: "secret-pass")
        let context = XtreamCatchupContext(credentials: login, timeZone: Self.utc)
        #expect("\(context)" == "panel")
        var dumped = ""
        dump(context, to: &dumped)
        #expect(!dumped.contains("secret"))
    }
}
