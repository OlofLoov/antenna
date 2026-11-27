import Foundation
import Testing

@testable import AntennaCore

@Suite struct XtreamHLSOfferTests {
    private static func userInfo(_ json: String) throws -> XtreamAccountInfo.UserInfo {
        try JSONDecoder().decode(XtreamAccountInfo.self, from: Data(#"{"user_info":\#(json)}"#.utf8)).userInfo
    }

    @Test("xtream-live-source/the-account-says-whether-hls-is-offered: the account's allowed formats decode loosely")
    func decodesAllowedFormats() throws {
        #expect(try Self.userInfo(#"{"allowed_output_formats":["m3u8","ts","rtmp"]}"#).allowedOutputFormats == ["m3u8", "ts", "rtmp"])
        #expect(try Self.userInfo(#"{"allowed_output_formats":"ts, m3u8"}"#).allowedOutputFormats == ["ts", " m3u8"])
        #expect(try Self.userInfo(#"{"allowed_output_formats":[1]}"#).allowedOutputFormats == ["1"])
        #expect(try Self.userInfo(#"{"allowed_output_formats":{"a":1}}"#).allowedOutputFormats == nil)
        #expect(try Self.userInfo(#"{"allowed_output_formats":null}"#).allowedOutputFormats == nil)
        #expect(try Self.userInfo(#"{"auth":1}"#).allowedOutputFormats == nil)
    }

    @Test(
        "xtream-live-source/the-account-says-whether-hls-is-offered: HLS when listed or not said, not when left out",
        arguments: [
            (["m3u8", "ts"], true), (["ts", " M3U8 "], true), (["ts"], false), (["ts", "rtmp"], false), ([], true), (["", " "], true),
        ])
    func offersHLS(formats: [String], expected: Bool) {
        #expect(XtreamLiveFormat.offersHLS(allowedOutputFormats: formats) == expected)
        #expect(XtreamLiveFormat.offersHLS(allowedOutputFormats: nil))
    }

    @Test("xtream-live-source/the-account-says-whether-hls-is-offered: a live load keeps MPEG-TS links and says whether HLS is offered")
    func liveLoadSaysWhetherHLSIsOffered() async throws {
        let hls = "offers-hls.panel"
        XtreamTimeZoneTests.serveLive(host: hls)
        XtreamActionStub.register(host: hls, action: nil, body: #"{"user_info":{"auth":1,"allowed_output_formats":["m3u8","ts"]}}"#)
        let hlsLoad = try await XtreamTimeZoneTests.client(host: hls).liveLoad()
        #expect(hlsLoad.channels.map(\.streamURL.absoluteString) == ["http://\(hls):8080/live/u/p/42.ts"])
        #expect(hlsLoad.offersHLS)

        let ts = "offers-ts.panel"
        XtreamTimeZoneTests.serveLive(host: ts)
        XtreamActionStub.register(host: ts, action: nil, body: #"{"user_info":{"auth":1,"allowed_output_formats":["ts"]}}"#)
        let tsLoad = try await XtreamTimeZoneTests.client(host: ts).liveLoad()
        #expect(tsLoad.channels.map(\.streamURL.absoluteString) == ["http://\(ts):8080/live/u/p/42.ts"])
        #expect(!tsLoad.offersHLS)

        let none = "offers-noaccount.panel"
        XtreamTimeZoneTests.serveLive(host: none)
        XtreamActionStub.register(host: none, action: nil, status: 500, body: "")
        #expect(try await XtreamTimeZoneTests.client(host: none).liveLoad().offersHLS)
    }

    @Test("xtream-live-source/the-account-says-whether-hls-is-offered: the offer is kept per loaded source")
    func offersArePerSource() {
        let offers = XtreamHLSOffers()
        let source = UUID()
        #expect(!offers.offersHLS(source))
        offers.loaded(source, offersHLS: true)
        #expect(offers.offersHLS(source))
        #expect(!offers.offersHLS(UUID()))
    }
}

@Suite struct AirPlayHLSTests {
    static let source = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1") ?? UUID()
    static let other = UUID(uuidString: "00000000-0000-0000-0000-0000000000A2") ?? UUID()
    static let start = Date(timeIntervalSince1970: 1_800_000_000)
    static let ts = URL.test("http://panel:8080/live/u/p/42.ts")

    static func channel(source: UUID? = AirPlayHLSTests.source) -> Channel {
        Channel(id: "xtream#panel#42", name: "A", streamURL: ts, sourceID: source)
    }

    @Test("playback-engine/a-channel-goes-to-airplay-as-hls: the HLS link keeps the login as encoded")
    func hlsAddress() throws {
        let client = XtreamClient(
            credentials: XtreamCredentials(server: try #require(URL(string: "http://h:8080")), username: "u", password: "a&b/c+d"))
        let stream = try JSONDecoder().decode(XtreamLiveStream.self, from: Data(#"{"stream_id":42,"name":"A"}"#.utf8))
        let channel = client.channel(from: stream, categoryName: nil)
        #expect(channel.streamURL.absoluteString == "http://h:8080/live/u/a%26b%2Fc%2Bd/42.ts")
        let address = try #require(XtreamLiveFormat.hlsAddress(for: channel))
        #expect(address == client.streamURL(for: stream, container: .m3u8))
        var playlist = channel
        playlist.id = "home/42"
        #expect(XtreamLiveFormat.hlsAddress(for: playlist) == nil)
        var movie = channel
        movie.id = XtreamTitleID(host: "h", kind: .vod, rawID: 42).description
        #expect(XtreamLiveFormat.hlsAddress(for: movie) == nil)
    }

    @Test("playback-engine/a-channel-goes-to-airplay-as-hls: MPEG-TS on the device, HLS with MPEG-TS behind it for AirPlay")
    func addresses() {
        let channel = Self.channel()
        let memory = HLSFailureMemory()
        let device = AirPlayHLS.address(
            for: channel, resolved: Self.ts, toAirPlay: false, offersHLS: true, memory: memory, now: Self.start)
        #expect(device == LiveAddress(url: Self.ts, fallback: nil))
        let airPlay = AirPlayHLS.address(
            for: channel, resolved: Self.ts, toAirPlay: true, offersHLS: true, memory: memory, now: Self.start)
        #expect(airPlay.url.absoluteString == "http://panel:8080/live/u/p/42.m3u8")
        #expect(airPlay.fallback == StreamFallback(url: Self.ts, source: Self.source))
        let notOffered = AirPlayHLS.address(
            for: channel, resolved: Self.ts, toAirPlay: true, offersHLS: false, memory: memory, now: Self.start)
        #expect(notOffered == LiveAddress(url: Self.ts, fallback: nil))
    }

    @Test("playback-engine/a-source-whose-hls-failed-cannot-airplay: a failed source has no HLS link for a week")
    func failedSourceHasNoLink() {
        var memory = HLSFailureMemory()
        memory.record(Self.source, at: Self.start)
        let channel = Self.channel()
        let soon = Self.start.addingTimeInterval(6 * 86_400)
        #expect(AirPlayHLS.hlsAddress(for: channel, offersHLS: true, memory: memory, now: soon) == nil)
        #expect(
            AirPlayHLS.address(for: channel, resolved: Self.ts, toAirPlay: true, offersHLS: true, memory: memory, now: soon).url == Self.ts)
        let later = Self.start.addingTimeInterval(7 * 86_400)
        #expect(AirPlayHLS.hlsAddress(for: channel, offersHLS: true, memory: memory, now: later) != nil)
        #expect(AirPlayHLS.hlsAddress(for: Self.channel(source: Self.other), offersHLS: true, memory: memory, now: Self.start) != nil)
    }

    @Test("playback-engine/a-source-whose-hls-failed-cannot-airplay: old entries go and the memory keeps no address")
    func prunesAndStoresNoAddress() throws {
        var memory = HLSFailureMemory()
        memory.record(Self.other, at: Self.start)
        memory.record(Self.source, at: Self.start.addingTimeInterval(8 * 86_400))
        #expect(!memory.failedLately(Self.other, now: Self.start))
        let data = try JSONEncoder().encode(memory)
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains(Self.other.uuidString))
        #expect(!text.contains("http") && !text.contains("panel"))
        #expect(try JSONDecoder().decode(HLSFailureMemory.self, from: data) == memory)
    }
}

@Suite struct AirPlayHandoffTests {
    @Test("playback-engine/a-channel-goes-to-airplay-as-hls: picking an AirPlay device moves the channel to HLS, ending it moves it back")
    func routeComesAndGoes() {
        var handoff = AirPlayHandoff()
        #expect(handoff.handle(.pickerOpened(preparesPlayer: false), canSendHLS: true).isEmpty)
        #expect(!handoff.wantsHLS)
        #expect(handoff.handle(.pickerClosed, canSendHLS: true).isEmpty)
        #expect(handoff.handle(.route(airPlay: true), canSendHLS: true) == [.playHLS, .wait])
        #expect(handoff.wantsHLS)
        #expect(handoff.handle(.externalPlayback(true), canSendHLS: true).isEmpty)
        #expect(handoff.handle(.waitEnded, canSendHLS: true).isEmpty)
        #expect(handoff.handle(.route(airPlay: false), canSendHLS: true) == [.playTransportStream])
        #expect(!handoff.wantsHLS)
    }

    @Test("playback-engine/a-channel-goes-to-airplay-as-hls: AirPlay that ends on the receiver moves the channel back")
    func externalPlaybackEnds() {
        var handoff = AirPlayHandoff()
        _ = handoff.handle(.route(airPlay: true), canSendHLS: true)
        _ = handoff.handle(.externalPlayback(true), canSendHLS: true)
        #expect(handoff.handle(.externalPlayback(false), canSendHLS: true) == [.playTransportStream])
    }

    @Test("playback-engine/a-channel-goes-to-airplay-as-hls: a speaker with no screen gets MPEG-TS back and keeps it")
    func speakerWithNoScreen() {
        var handoff = AirPlayHandoff()
        _ = handoff.handle(.route(airPlay: true), canSendHLS: true)
        #expect(handoff.handle(.waitEnded, canSendHLS: true) == [.playTransportStream])
        #expect(handoff.tuned(canSendHLS: true).isEmpty)
        #expect(!handoff.wantsHLS)
    }

    @Test("playback-engine/a-channel-goes-to-airplay-as-hls: a channel without HLS stays on MPEG-TS")
    func noHLSLink() {
        var handoff = AirPlayHandoff()
        #expect(handoff.handle(.route(airPlay: true), canSendHLS: false).isEmpty)
        #expect(!handoff.wantsHLS)
        #expect(handoff.tuned(canSendHLS: true) == [.wait])
        #expect(handoff.wantsHLS)
        #expect(handoff.tuned(canSendHLS: false).isEmpty)
        #expect(!handoff.wantsHLS)
    }

    @Test("playback-engine/a-channel-goes-to-airplay-as-hls: on a Mac the list routes a prepared HLS link until a device is picked")
    func macPreparesTheLink() {
        var handoff = AirPlayHandoff()
        #expect(handoff.handle(.pickerOpened(preparesPlayer: true), canSendHLS: true) == [.prepareHLS])
        #expect(!handoff.wantsHLS)
        #expect(handoff.handle(.externalPlayback(true), canSendHLS: true) == [.playHLS])
        #expect(handoff.wantsHLS)
        #expect(handoff.handle(.pickerClosed, canSendHLS: true).isEmpty)

        var cancelled = AirPlayHandoff()
        _ = cancelled.handle(.pickerOpened(preparesPlayer: true), canSendHLS: true)
        #expect(cancelled.handle(.pickerClosed, canSendHLS: true) == [.wait])
        #expect(cancelled.handle(.waitEnded, canSendHLS: true) == [.dropPreparedHLS])
        #expect(!cancelled.wantsHLS && !cancelled.prepared)
    }

    @Test("playback-engine/a-source-whose-hls-failed-cannot-airplay: HLS that does not start says AirPlay is not available")
    func hlsFails() {
        var handoff = AirPlayHandoff()
        _ = handoff.handle(.route(airPlay: true), canSendHLS: true)
        #expect(handoff.handle(.hlsFailed, canSendHLS: false) == [.sayUnavailable])
        #expect(!handoff.wantsHLS)
        #expect(handoff.handle(.waitEnded, canSendHLS: false).isEmpty)
        #expect(handoff.handle(.route(airPlay: false), canSendHLS: false).isEmpty)
    }
}
