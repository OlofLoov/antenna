import Foundation
import Testing

@testable import AntennaCore

@Suite struct StalkerTuneTests {
    private func channel(host: String, id: String = "101", cmd: String = "ffrt http://localhost/ch/101_") throws -> Channel {
        let portal = try #require(StalkerPortal("http://\(host)"))
        let reference = try #require(StalkerClient.reference(host: portal, id: id, cmd: cmd))
        return Channel(id: "stalker#\(host)#\(id)", name: "News", streamURL: reference)
    }

    @Test(
        "stalker-portal-source/tuning-gets-a-fresh-stream-address tune a portal channel",
        arguments: [
            "ffmpeg http://s.example/live/1?token=k", "auto http://s.example/live/1?token=k", "http://s.example/live/1?token=k",
            "solutions http://s.example/live/1?token=k",
        ])
    func tune(cmd: String) async throws {
        let host = "tu-\(abs(cmd.hashValue)).portal"
        let portal = FakePortal()
        portal.on("create_link") { _, _ in .http(200, #"{"js":{"id":"101","cmd":"\#(cmd)"}}"#) }
        let client = try portal.client(host: host)
        let url = try await client.playableURL(for: try channel(host: host))
        #expect(url.absoluteString == "http://s.example/live/1?token=k")
        let request = try #require(StalkerStubProtocol.requests(host: host).last)
        #expect(
            request.queryPairs == [
                "type=itv", "action=create_link", "cmd=ffrt http://localhost/ch/101_", "series=", "forced_storage=", "disable_ad=0",
                "download=0", "force_ch_link_check=0", "JsHttpRequest=1-xml",
            ])
        #expect(request.url?.query(percentEncoded: true)?.contains("cmd=ffrt%20http%3A%2F%2Flocalhost%2Fch%2F101_") == true)

        _ = try await client.playableURL(for: try channel(host: host))
        #expect(portal.count("create_link") == 2)
    }

    @Test("stalker-portal-source/tuning-gets-a-fresh-stream-address a channel not from this portal fails without a request")
    func notPortal() async throws {
        let host = "tu-not-portal.portal"
        let client = try FakePortal().client(host: host)
        let plain = Channel(id: "m3u#1", name: "Plain", streamURL: try #require(URL(string: "http://s.example/1.ts")))
        await #expect(throws: StalkerError.notStalkerChannel) { try await client.playableURL(for: plain) }
        await #expect(throws: StalkerError.notStalkerChannel) { try await client.playableURL(for: try channel(host: "other.portal")) }
        #expect(StalkerStubProtocol.requests(host: host).isEmpty)
    }

    @Test(
        "stalker-portal-source/tuning-gets-a-fresh-stream-address an answer with no usable address",
        arguments: [#"{"js":[]}"#, #"{"js":{}}"#, #"{"js":"x"}"#, #"{"js":{"cmd":"ffrt rtmp://s.example/1"}}"#, #"{"js":{"cmd":""}}"#])
    func noLink(body: String) async throws {
        let host = "tu-nolink-\(abs(body.hashValue)).portal"
        let portal = FakePortal()
        portal.on("create_link") { _, _ in .http(200, body) }
        let client = try portal.client(host: host)
        await #expect(throws: StalkerError.self) { try await client.playableURL(for: try channel(host: host)) }
    }

    @Test("stalker-portal-source/an-expired-session-renews-itself-once a tune with an expired session costs five requests")
    func expiredTune() async throws {
        let host = "tu-expired.portal"
        let portal = FakePortal()
        portal.on("create_link") { _, request in
            request.bearer == "Bearer T1" ? .http(401, "") : .http(200, #"{"js":{"cmd":"ffmpeg http://s.example/1"}}"#)
        }
        let client = try portal.client(host: host, login: "alice")
        try await client.signIn()
        let before = StalkerStubProtocol.requests(host: host).count
        _ = try await client.playableURL(for: try channel(host: host))
        let after = StalkerStubProtocol.requests(host: host).dropFirst(before).map(\.action)
        #expect(after == ["create_link", "handshake", "do_auth", "get_profile", "create_link"])
    }

    @Test("stalker-portal-source/secrets-never-show-up-in-messages-or-logs errors print no secret")
    func errorPrinting() async throws {
        let host = "tu-errors.portal"
        let portal = FakePortal()
        portal.on("get_profile") { _, _ in
            .http(200, #"{"js":{"status":1,"msg":"MAC 00-1a-79-12-34-56 / 001A79123456 for alice-7f3e with pw-9b2a is blocked"}}"#)
        }
        let client = try portal.client(
            host: host, portal: "http://\(host):8080/stalker_portal/c/", password: "pw-9b2a", login: "alice-7f3e")
        let error = await #expect(throws: StalkerError.self) { try await client.signIn() }
        let refused = try #require(error)
        #expect(refused == .deviceRefused(message: "MAC … / … for … with … is blocked"))
        let errors: [StalkerError] = [
            refused, .transport(.timedOut), .serverError(status: 500), .notAuthorized, .noPortal, .unreadable, .notStalkerChannel, .noLink,
        ]
        var printed = ""
        for error in errors {
            printed += "\(error) \(String(reflecting: error)) \(error.localizedDescription)"
            dump(error, to: &printed)
        }
        for secret in ["00:1A", "00-1a", "001A79", "alice-7f3e", "pw-9b2a", "8080", "stalker_portal", "T1", "localhost"] {
            #expect(!printed.contains(secret), "printed \(secret)")
        }
    }

    // MARK: Guide

    @Test("stalker-portal-source/the-portal-s-guide-fills-the-programme-grid portal guide rows by channel id")
    func guideRows() throws {
        let answer = try StalkerClient.decodeGuide(status: 200, data: Data(try stalkerFixture("epg_info.json").utf8))
        guard case .guide(let programmes, let skipped) = answer else {
            Issue.record("expected a guide")
            return
        }
        #expect(skipped == 3)
        let byChannel = Dictionary(grouping: programmes, by: \.channelID)
        #expect(byChannel["101"]?.map(\.title).sorted() == ["Morning News", "Noon News"])
        let noon = try #require(byChannel["101"]?.first { $0.title == "Noon News" })
        #expect(noon.stop.timeIntervalSince(noon.start) == 1800)
        #expect(noon.summary == nil)
        #expect(byChannel["101"]?.first { $0.title == "Morning News" }?.summary == "Headlines")
        #expect(byChannel["102"]?.map(\.title) == ["Match"])
        #expect(byChannel["999"]?.count == 1)
    }

    @Test("stalker-portal-source/the-portal-s-guide-fills-the-programme-grid a list of rows with ch_id")
    func guideList() throws {
        let body = #"{"js":[{"ch_id":"5","name":"A","start_timestamp":100,"stop_timestamp":200},{"name":"B","start_timestamp":1}]}"#
        guard case .guide(let programmes, let skipped) = try StalkerClient.decodeGuide(status: 200, data: Data(body.utf8)) else {
            Issue.record("expected a guide")
            return
        }
        #expect(programmes.map(\.channelID) == ["5"])
        #expect(skipped == 1)
    }

    @Test("stalker-portal-source/the-portal-s-guide-fills-the-programme-grid a turned-down guide reads as rejected")
    func guideRejected() throws {
        for (status, body) in [(401, ""), (200, "Authorization failed."), (200, #"{"js":null}"#)] {
            guard case .rejected = try StalkerClient.decodeGuide(status: status, data: Data(body.utf8)) else {
                Issue.record("expected a rejection for \(status) \(body)")
                continue
            }
        }
        #expect(throws: StalkerError.unreadable) { try StalkerClient.decodeGuide(status: 200, data: Data("<tv></tv>".utf8)) }
    }

    @Test("stalker-portal-source/the-portal-s-guide-fills-the-programme-grid the guide request is signed in and clamps the period")
    func guideRequest() async throws {
        let host = "tu-epg.portal"
        let client = try FakePortal().client(host: host)
        let request = try await client.epgRequest(period: 500)
        #expect(request.queryPairs == ["type=itv", "action=get_epg_info", "period=168", "JsHttpRequest=1-xml"])
        #expect(request.bearer == "Bearer T1")
        #expect(request.value(forHTTPHeaderField: "Cookie")?.hasPrefix("mac=") == true)
        #expect(try await client.epgRequest(period: 0).queryPairs.contains("period=1"))
        await client.invalidateToken()
        #expect(try await client.epgRequest(period: 24).bearer == "Bearer T2")
    }

    @Test("decoding a large portal stays fast", .timeLimit(.minutes(1)))
    func largePortal() async throws {
        var channelRows: [String] = []
        for index in 0..<50_000 {
            channelRows.append(
                #"{"id":"\#(index)","name":"Channel \#(index)","number":"\#(index)","cmd":"ffrt http://localhost/ch/\#(index)_","tv_genre_id":"1","logo":"\#(index).png","xmltv_id":"c\#(index)","tv_archive":1,"tv_archive_duration":"168"}"#
            )
        }
        let channels = "{\"js\":{\"data\":[" + channelRows.joined(separator: ",") + "]}}"
        var guideRows: [String] = []
        for index in 0..<200_000 {
            let start = 1_794_477_600 + (index % 50) * 1800
            guideRows.append(
                #"{"ch_id":"\#(index / 50)","name":"Show \#(index)","descr":"About show \#(index)","start_timestamp":\#(start),"stop_timestamp":\#(start + 1800)}"#
            )
        }
        let guide = "{\"js\":[" + guideRows.joined(separator: ",") + "]}"

        let host = "tu-large.portal"
        let portal = FakePortal()
        portal.on("get_all_channels") { _, _ in .http(200, channels) }
        let client = try portal.client(host: host)
        let clock = ContinuousClock()
        let started = clock.now
        let load = try await client.liveLoad(guide: .portal)
        guard case .guide(let programmes, _) = try StalkerClient.decodeGuide(status: 200, data: Data(guide.utf8)) else {
            Issue.record("expected a guide")
            return
        }
        let elapsed = started.duration(to: clock.now)
        #expect(load.channels.count == 50_000)
        #expect(programmes.count == 200_000)
        #expect(elapsed < .seconds(10))
    }
}
