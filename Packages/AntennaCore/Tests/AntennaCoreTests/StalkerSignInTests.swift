import Foundation
import Testing

@testable import AntennaCore

@Suite struct StalkerSignInTests {
    @Test(
        "stalker-portal-source/connect-with-the-portal-address-you-were-given finds the portal from each address form",
        arguments: [
            ("http://h/c/", "/stalker_portal/server/load.php", ["/stalker_portal/server/load.php"]),
            ("http://h", "/server/load.php", ["/stalker_portal/server/load.php", "/server/load.php"]),
            ("http://h/c", "/portal.php", ["/stalker_portal/server/load.php", "/server/load.php", "/portal.php"]),
            ("http://h:8080/stalker_portal/c/", "/stalker_portal/server/load.php", ["/stalker_portal/server/load.php"]),
        ])
    func discovery(address: String, apiPath: String, tried: [String]) async throws {
        let host = "si-discovery-\(abs(address.hashValue)).portal"
        let portal = FakePortal(apiPath: apiPath)
        let client = try portal.client(host: host, portal: address.replacingOccurrences(of: "//h", with: "//\(host)"))
        try await client.signIn()
        let requests = StalkerStubProtocol.requests(host: host)
        #expect(requests.prefix(tried.count).map { $0.url?.path() } == tried)
        #expect(requests.dropFirst(tried.count).map(\.action) == ["get_profile"])
        #expect(await client.endpoint?.path() == apiPath)

        _ = try await client.accountInfo()
        #expect(StalkerStubProtocol.requests(host: host).last?.url?.path() == apiPath)
        #expect(portal.count("handshake") == 1)
    }

    @Test("stalker-portal-source/connect-with-the-portal-address-you-were-given signs in with the login when there is one")
    func login() async throws {
        let host = "si-login.portal"
        let portal = FakePortal()
        let client = try portal.client(host: host, password: "a&b/c+d", login: "alice")
        try await client.signIn()
        let requests = StalkerStubProtocol.requests(host: host)
        #expect(requests.map(\.action) == ["handshake", "do_auth", "get_profile"])
        let auth = try #require(requests.dropFirst().first)
        let device = "667094E7E8FF0347F6EC27A8E8115BE76E2AA9CD5C8F13C6FA00BCEDFAC02B41"
        #expect(
            auth.queryPairs == [
                "type=stb", "action=do_auth", "login=alice", "password=a&b/c+d", "device_id=\(device)", "device_id2=\(device)",
                "JsHttpRequest=1-xml",
            ])
        #expect(auth.url?.query(percentEncoded: true)?.contains("password=a%26b%2Fc%2Bd") == true)
        #expect(auth.bearer == "Bearer T1")
    }

    @Test("stalker-portal-source/connect-with-the-portal-address-you-were-given handshake and profile have the MAG250 shape")
    func requestShape() async throws {
        let host = "si-shape.portal"
        let portal = FakePortal()
        let client = try portal.client(host: host)
        try await client.signIn()
        let requests = StalkerStubProtocol.requests(host: host)
        let handshake = try #require(requests.first)
        #expect(handshake.queryPairs == ["type=stb", "action=handshake", "token=", "JsHttpRequest=1-xml"])
        #expect(handshake.bearer == nil)
        #expect(handshake.value(forHTTPHeaderField: "Cookie") == "mac=00%3A1A%3A79%3A12%3A34%3A56; stb_lang=en; timezone=Europe/Stockholm")
        #expect(handshake.value(forHTTPHeaderField: "User-Agent") == StalkerDevice.mag250.userAgent)
        #expect(handshake.value(forHTTPHeaderField: "X-User-Agent") == "Model: MAG250; Link: Ethernet")
        #expect(handshake.value(forHTTPHeaderField: "Referer") == "http://\(host)/c/")

        let profile = try #require(requests.last)
        let sn = "2213785DC6113"
        let device = "667094E7E8FF0347F6EC27A8E8115BE76E2AA9CD5C8F13C6FA00BCEDFAC02B41"
        let metrics = #"{"mac":"00:1A:79:12:34:56","sn":"2213785DC6113","type":"STB","model":"MAG250","uid":"","random":"r-42"}"#
        #expect(
            profile.queryPairs == [
                "type=stb", "action=get_profile", "hd=1", "ver=\(StalkerDevice.mag250.version)", "num_banks=2", "sn=\(sn)",
                "stb_type=MAG250", "client_type=STB", "image_version=218", "video_out=hdmi", "device_id=\(device)",
                "device_id2=\(device)", "signature=922F69DECA50A1E4883CDB6AF9A57D86B2C82BE460AE9AFCAF2B421C715A0D1B",
                "auth_second_step=1", "hw_version=1.7-BD-00", "not_valid_token=0", "metrics=\(metrics)", "hw_version_2=\(sn)",
                "timestamp=1700000000", "api_signature=262", "prehash=", "JsHttpRequest=1-xml",
            ])
        let encoded = try #require(profile.url?.query(percentEncoded: true))
        #expect(!encoded.contains(" ") && !encoded.contains("\"") && !encoded.contains("{") && !encoded.contains(";"))
        #expect(profile.bearer == "Bearer T1")
    }

    @Test("stalker-portal-source/connect-with-the-portal-address-you-were-given a refused cross-host redirect moves to the next address")
    func crossHostRedirect() async throws {
        let host = "si-redirect.portal"
        let portal = FakePortal(apiPath: "/server/load.php")
        let client = try portal.client(host: host)
        StalkerStubProtocol.register(host: host) { request in
            request.url?.path() == "/stalker_portal/server/load.php"
                ? .redirect("http://elsewhere.example/load.php") : portal.handle(request)
        }
        try await client.signIn()
        #expect(StalkerStubProtocol.requests(host: "elsewhere.example").isEmpty)
        #expect(await client.endpoint?.path() == "/server/load.php")
    }

    @Test("stalker-portal-source/connect-with-the-portal-address-you-were-given plain http portal works")
    func plainHTTP() async throws {
        let host = "si-plain.portal"
        let client = try FakePortal().client(host: host, portal: "http://\(host)")
        try await client.signIn()
        #expect(StalkerStubProtocol.requests(host: host).allSatisfy { $0.url?.scheme == "http" })
    }

    // MARK: Failures

    private func failure(_ name: String, _ handler: @escaping StalkerStubProtocol.Handler) async throws -> StalkerError? {
        let host = "si-fail-\(name).portal"
        let client = try FakePortal().client(host: host)
        StalkerStubProtocol.register(host: host, handler: handler)
        do {
            try await client.signIn()
            return nil
        } catch let error as StalkerError {
            return error
        }
    }

    @Test("stalker-portal-source/connect-says-why-it-failed each failure has its own error")
    func eachFailure() async throws {
        let offline = try await failure("offline") { _ in .failure(.notConnectedToInternet) }
        #expect(offline == .transport(.notConnectedToInternet))
        #expect(offline?.isOffline == true)

        #expect(try await failure("server") { _ in .http(503, "busy") } == .serverError(status: 503))
        #expect(try await failure("unauthorized") { _ in .http(403, "Forbidden") } == .notAuthorized)
        #expect(try await failure("empty-token") { _ in .http(200, #"{"js":{"token":""}}"#) } == .notAuthorized)
        #expect(try await failure("html") { _ in .http(200, "<!DOCTYPE html><html>login</html>") } == .noPortal)
        #expect(try await failure("html403") { _ in .http(403, "<html>nginx</html>") } == .noPortal)

        let portal = FakePortal()
        portal.on("get_profile") { _, _ in
            .http(200, #"{"js":{"status":1,"msg":"Device 00:1A:79:12:34:56 (001a79123456) is blocked"}}"#)
        }
        let refused = try await failure("refused") { portal.handle($0) }
        #expect(refused == .deviceRefused(message: "Device … (…) is blocked"))

        let needsLogin = FakePortal()
        needsLogin.on("get_profile") { _, _ in .http(200, #"{"js":{"status":2}}"#) }
        #expect(try await failure("needs-login") { needsLogin.handle($0) } == .notAuthorized)

        let badLogin = FakePortal()
        badLogin.on("do_auth") { _, _ in .http(200, #"{"js":false}"#) }
        let host = "si-fail-bad-login.portal"
        let client = try badLogin.client(host: host, login: "alice")
        await #expect(throws: StalkerError.notAuthorized) { try await client.signIn() }
    }

    @Test("stalker-portal-source/connect-says-why-it-failed an outage is never a wrong address")
    func outageIsNotWrongAddress() async throws {
        let mixed = try await failure("mixed") { request in
            request.url?.path() == "/server/load.php" ? .http(502, "bad gateway") : .http(404, "<html>no</html>")
        }
        #expect(mixed == .serverError(status: 502))
        let lastSeen = try await failure("last5xx") { request in
            request.url?.path() == "/portal.php" ? .http(504, "") : .http(500, "")
        }
        #expect(lastSeen == .serverError(status: 504))
    }

    @Test("stalker-portal-source/connect-says-why-it-failed a transport failure stops discovery")
    func transportStopsDiscovery() async throws {
        let host = "si-fail-transport-stop.portal"
        let client = try FakePortal().client(host: host)
        StalkerStubProtocol.register(host: host) { _ in .failure(.timedOut) }
        await #expect(throws: StalkerError.transport(.timedOut)) { try await client.signIn() }
        #expect(StalkerStubProtocol.requests(host: host).count == 1)
    }

    // MARK: Session

    @Test("stalker-portal-source/channels-guide-and-playback-share-one-sign-in two requests at once sign in once")
    func concurrentSignIn() async throws {
        let host = "si-concurrent.portal"
        let portal = FakePortal()
        let client = try portal.client(host: host)
        async let first = client.accountInfo()
        async let second = client.accountInfo()
        _ = try await (first, second)
        _ = try await client.accountInfo()
        #expect(portal.count("handshake") == 1)
        #expect(portal.count("get_profile") == 1)
        #expect(portal.count("get_main_info") == 3)
    }

    @Test("stalker-portal-source/an-expired-session-renews-itself-once the session key expired")
    func renewOnce() async throws {
        let host = "si-renew.portal"
        let portal = FakePortal()
        portal.on("get_main_info") { _, request in
            request.bearer == "Bearer T1" ? .http(200, "Authorization failed.") : .http(200, #"{"js":{"end_date":"2030-01-02"}}"#)
        }
        let client = try portal.client(host: host)
        try await client.signIn()
        let info = try await client.accountInfo()
        #expect(info.expiresAt == Date(timeIntervalSince1970: 1_893_542_400))
        #expect(portal.count("handshake") == 2)
        #expect(portal.count("get_main_info") == 2)
    }

    @Test("stalker-portal-source/an-expired-session-renews-itself-once several requests turned down at once renew once")
    func concurrentRenew() async throws {
        let host = "si-renew-many.portal"
        let portal = FakePortal()
        portal.on("get_main_info") { _, request in
            request.bearer == "Bearer T1" ? .http(401, "") : .http(200, #"{"js":{"end_date":"2030-01-02 10:00:00"}}"#)
        }
        let client = try portal.client(host: host)
        try await client.signIn()
        async let first = client.accountInfo()
        async let second = client.accountInfo()
        async let third = client.accountInfo()
        let infos = try await [first, second, third]
        #expect(infos.allSatisfy { $0.expiresAt == Date(timeIntervalSince1970: 1_893_578_400) })
        #expect(portal.count("handshake") == 2)
    }

    @Test("stalker-portal-source/an-expired-session-renews-itself-once the repeat is turned down")
    func repeatTurnedDown() async throws {
        let host = "si-renew-fail.portal"
        let portal = FakePortal()
        portal.on("get_main_info") { _, _ in .http(200, #"{"js":null}"#) }
        let client = try portal.client(host: host)
        await #expect(throws: StalkerError.notAuthorized) { _ = try await client.accountInfo() }
        #expect(portal.count("get_main_info") == 2)
        #expect(portal.count("handshake") == 2)
    }

    @Test("an empty answer is not a rejection")
    func falseIsEmpty() async throws {
        let host = "si-false.portal"
        let portal = FakePortal()
        portal.on("get_main_info") { _, _ in .http(200, #"{"js":false}"#) }
        let client = try portal.client(host: host)
        #expect(try await client.accountInfo().expiresAt == nil)
        #expect(portal.count("handshake") == 1)
    }
}
