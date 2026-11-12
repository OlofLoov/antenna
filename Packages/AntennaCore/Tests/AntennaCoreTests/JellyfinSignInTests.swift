import Foundation
import Testing

@testable import AntennaCore

@Suite struct JellyfinSignInTests {
    @Test(
        "jellyfin-live-tv-source/connect-checks-it-is-really-a-jellyfin-server checks the server with or without a path",
        arguments: [
            ("http://H:8096", "/System/Info/Public"), ("http://H:8096/", "/System/Info/Public"),
            ("https://H/jellyfin", "/jellyfin/System/Info/Public"), ("https://H/jellyfin/", "/jellyfin/System/Info/Public"),
        ])
    func serverCheck(address: String, path: String) async throws {
        let host = "jf-info-\(abs(address.hashValue)).local"
        let server = FakeJellyfin()
        let client = try server.client(host: host, server: address.replacingOccurrences(of: "H", with: host))
        let info = try await client.serverInfo()
        #expect(info == JellyfinServerInfo(id: "f2a1c0de5b7e4d0f9a3b2c1d0e9f8a7b", name: "Living Room", version: "10.10.3"))
        let sent = try #require(JellyfinStubProtocol.requests(host: host).first)
        #expect(sent.path == path)
        #expect(sent.request.httpMethod == "GET")
        #expect(sent.body.isEmpty)
        #expect(sent.authorization?.contains("Token=") == false)
        #expect(sent.authorization?.contains(server.password) == false)
        #expect(server.count("Users/AuthenticateByName") == 0)
    }

    @Test("jellyfin-live-tv-source/connect-checks-it-is-really-a-jellyfin-server reads the server answer")
    func decodeServerInfo() throws {
        #expect(try JellyfinClient.decodeServerInfo(jellyfinFixture("server-info.json")).version == "10.10.3")
        #expect(throws: JellyfinClient.JellyfinError.decoding(path: "Id")) {
            try JellyfinClient.decodeServerInfo(Data(#"{"Version":"10.9.0"}"#.utf8))
        }
        #expect(throws: JellyfinClient.JellyfinError.decoding(path: "Version")) {
            try JellyfinClient.decodeServerInfo(Data(#"{"Id":"x"}"#.utf8))
        }
        #expect(throws: JellyfinClient.JellyfinError.decoding(path: "$")) {
            try JellyfinClient.decodeServerInfo(Data("<!doctype html><html>Sign in</html>".utf8))
        }
        let unnamed = try JellyfinClient.decodeServerInfo(Data(#"{"Id":"x","Version":"10.8.0","ServerName":""}"#.utf8))
        #expect(unnamed.name == nil)
    }

    @Test("jellyfin-live-tv-source/signing-in-remembers-this-device sends the password once and the key afterwards")
    func passwordOnce() async throws {
        let host = "jf-once.local"
        let server = FakeJellyfin()
        server.password = #"p"w\d&+ å"#
        let store = CountingSessionStore()
        let client = try server.client(host: host, store: store)

        _ = try await client.liveChannels()
        _ = try await client.liveChannels()
        _ = try await client.programmes(channelIDs: ["ch-0"], in: DateInterval(start: .now, duration: 3600))

        let requests = JellyfinStubProtocol.requests(host: host)
        let signIns = requests.filter { $0.path.hasSuffix("/Users/AuthenticateByName") }
        #expect(signIns.count == 1)
        let signIn = try #require(signIns.first)
        #expect(signIn.request.httpMethod == "POST")
        #expect(signIn.json?["Username"] as? String == "alice")
        #expect(signIn.json?["Pw"] as? String == server.password)
        #expect(String(decoding: signIn.body, as: UTF8.self).contains(#"p\"w\\d&+ å"#))
        #expect(signIn.request.url?.query() == nil)
        let header = try #require(signIn.authorization)
        #expect(header == #"MediaBrowser Client="Antenna", Device="iPhone", DeviceId="device-1", Version="1.0""#)

        for request in requests where request !== signIn {
            #expect(FakeJellyfin.token(request.authorization) == "K1")
            #expect(!String(decoding: request.body, as: UTF8.self).contains(server.password))
            #expect(request.request.url?.absoluteString.contains("alice") == false)
        }
        #expect(await store.session == JellyfinSession(token: "K1", userID: "user-1", serverID: "server-1"))
        #expect(await store.saves == 1)
        #expect(await store.loads == 3)
    }

    @Test("jellyfin-live-tv-source/signing-in-remembers-this-device uses a key saved earlier without signing in")
    func savedKey() async throws {
        let host = "jf-saved.local"
        let server = FakeJellyfin()
        let first = try server.client(host: host)
        let session = try await first.authenticate()
        let store = CountingSessionStore(session)
        let client = try server.client(host: host, store: store)
        _ = try await client.liveChannels()
        #expect(server.count("Users/AuthenticateByName") == 1)
        #expect(await store.saves == 0)
    }

    @Test("jellyfin-live-tv-source/signing-in-remembers-this-device cleans header values to one line")
    func headerCleaning() {
        let device = JellyfinDevice(id: "a\"b\\c\nd", name: " Apple TV\r\n", appVersion: "1.2")
        let header = JellyfinWire.authorization(device: device, token: "t\"k")
        #expect(header == #"MediaBrowser Client="Antenna", Device="Apple TV", DeviceId="abc d", Version="1.2", Token="tk""#)
    }

    @Test("jellyfin-live-tv-source/signing-in-remembers-this-device reads the sign-in answer")
    func decodeSession() throws {
        let session = try JellyfinClient.decodeSession(jellyfinFixture("authenticate.json"))
        #expect(
            session
                == JellyfinSession(token: "TOKEN", userID: "5d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a", serverID: "f2a1c0de5b7e4d0f9a3b2c1d0e9f8a7b")
        )
        #expect(throws: JellyfinClient.JellyfinError.decoding(path: "AccessToken")) {
            try JellyfinClient.decodeSession(Data(#"{"User":{"Id":"u"},"ServerId":"s"}"#.utf8))
        }
        #expect(throws: JellyfinClient.JellyfinError.decoding(path: "User.Id")) {
            try JellyfinClient.decodeSession(Data(#"{"AccessToken":"t","ServerId":"s"}"#.utf8))
        }
    }

    @Test(
        "jellyfin-live-tv-source/different-failures-get-different-errors maps each answer and keeps the saved key",
        arguments: [
            (JellyfinStubProtocol.Reply.http(403, Data()), JellyfinClient.JellyfinError.forbidden),
            (.http(500, Data("<html>oops</html>".utf8)), .badStatus(500)),
            (.http(502, Data()), .badStatus(502)),
            (.failure(.notConnectedToInternet), .transport(.notConnectedToInternet)),
            (.failure(.cannotConnectToHost), .transport(.cannotConnectToHost)),
            (.failure(.timedOut), .transport(.timedOut)),
            (.failure(.serverCertificateUntrusted), .untrustedCertificate),
            (.failure(.serverCertificateHasBadDate), .untrustedCertificate),
            (.failure(.serverCertificateNotYetValid), .untrustedCertificate),
            (.failure(.serverCertificateHasUnknownRoot), .untrustedCertificate),
        ])
    func failureKeepsKey(reply: JellyfinStubProtocol.Reply, expected: JellyfinClient.JellyfinError) async throws {
        let host = "jf-fail-\(abs("\(reply)".hashValue)).local"
        let server = FakeJellyfin()
        server.on("LiveTv/Channels") { _, _ in reply }
        let saved = JellyfinSession(token: "K-saved", userID: "user-1", serverID: "server-1")
        let store = CountingSessionStore(saved)
        let client = try server.client(host: host, store: store)
        await #expect(throws: expected) { try await client.liveChannels() }
        #expect(server.count("Users/AuthenticateByName") == 0)
        #expect(server.count("LiveTv/Channels") == 1)
        #expect(await store.session == saved)
        #expect(await store.clears == 0)
    }

    @Test("jellyfin-live-tv-source/different-failures-get-different-errors a turned-down password is not authorized")
    func wrongPassword() async throws {
        let host = "jf-wrong.local"
        let server = FakeJellyfin()
        let client = try server.client(host: host, password: "nope")
        await #expect(throws: JellyfinClient.JellyfinError.unauthorized) { try await client.authenticate() }
        await #expect(throws: JellyfinClient.JellyfinError.unauthorized) { try await client.liveChannels() }
        #expect(server.count("LiveTv/Channels") == 0)
    }

    @Test("jellyfin-live-tv-source/different-failures-get-different-errors offline fails once with no retry")
    func offline() async throws {
        let host = "jf-offline.local"
        let server = FakeJellyfin()
        server.on("System/Info/Public") { _, _ in .failure(.notConnectedToInternet) }
        let client = try server.client(host: host)
        do {
            _ = try await client.serverInfo()
            Issue.record("expected a failure")
        } catch let error as JellyfinClient.JellyfinError {
            #expect(error.isOffline)
        }
        #expect(JellyfinStubProtocol.requests(host: host).count == 1)
    }

    @Test("jellyfin-live-tv-source/different-failures-get-different-errors a server before 10.8 is not authorized")
    func oldServer() async throws {
        let host = "jf-old.local"
        let server = FakeJellyfin()
        server.on("LiveTv/Channels") { _, _ in .http(401, Data()) }
        let store = CountingSessionStore()
        let client = try server.client(host: host, store: store)
        await #expect(throws: JellyfinClient.JellyfinError.unauthorized) { try await client.liveChannels() }
        #expect(server.count("Users/AuthenticateByName") == 2)
        #expect(server.count("LiveTv/Channels") == 2)
        #expect(await store.session == nil)
    }

    @Test("jellyfin-live-tv-source/different-failures-get-different-errors the session store's errors pass through")
    func storeErrors() async throws {
        let host = "jf-store.local"
        let server = FakeJellyfin()
        let store = CountingSessionStore()
        await store.failLoading()
        let client = try server.client(host: host, store: store)
        await #expect(throws: CountingSessionStore.Failure.self) { try await client.liveChannels() }
        #expect(JellyfinStubProtocol.requests(host: host).isEmpty)
    }

    @Test("jellyfin-live-tv-source/a-revoked-sign-in-renews-itself-once key revoked mid-load finishes the list")
    func revokedMidLoad() async throws {
        let host = "jf-revoke.local"
        let server = FakeJellyfin()
        server.channelCount = 2_500
        server.on("LiveTv/Channels") { index, _ in
            if index == 1 { server.revokeAll() }
            return nil
        }
        let store = CountingSessionStore()
        let client = try server.client(host: host, store: store)
        let list = try await client.liveChannels()
        #expect(list.items.count == 2_500)
        #expect(list.items.map(\.id) == (0..<2_500).map { "jellyfin#\(host)#ch-\($0)" })
        let channels = JellyfinStubProtocol.requests(host: host).filter { $0.path.hasSuffix("/LiveTv/Channels") }
        #expect(channels.map { $0.query["StartIndex"] } == ["0", "1000", "1000", "2000"])
        #expect(channels.map { FakeJellyfin.token($0.authorization) } == ["K1", "K1", "K2", "K2"])
        #expect(server.count("Users/AuthenticateByName") == 2)
        #expect(await store.session?.token == "K2")
        #expect(list.items.last?.streamURL.absoluteString.contains("api_key=K2") == true)
    }

    @Test("jellyfin-live-tv-source/a-revoked-sign-in-renews-itself-once a second refusal discards the key")
    func secondRefusal() async throws {
        let host = "jf-twice.local"
        let server = FakeJellyfin()
        server.on("LiveTv/Channels") { _, _ in .http(401, Data()) }
        let store = CountingSessionStore(JellyfinSession(token: "K-old", userID: "user-1", serverID: "server-1"))
        let client = try server.client(host: host, store: store)
        await #expect(throws: JellyfinClient.JellyfinError.unauthorized) { try await client.liveChannels() }
        #expect(server.count("Users/AuthenticateByName") == 1)
        #expect(server.count("LiveTv/Channels") == 2)
        #expect(await store.session == nil)
        #expect(await store.clears == 1)
    }

    @Test("jellyfin-live-tv-source/a-revoked-sign-in-renews-itself-once a changed password discards the key")
    func passwordChanged() async throws {
        let host = "jf-changed.local"
        let server = FakeJellyfin()
        let store = CountingSessionStore(JellyfinSession(token: "K-old", userID: "user-1", serverID: "server-1"))
        let client = try server.client(host: host, password: "old password", store: store)
        await #expect(throws: JellyfinClient.JellyfinError.unauthorized) { try await client.liveChannels() }
        #expect(server.count("Users/AuthenticateByName") == 1)
        #expect(await store.session == nil)
    }

    @Test("jellyfin-live-tv-source/self-signed-certificates-are-turned-down sign-in is not retried on a certificate failure")
    func certificate() async throws {
        let host = "jf-cert.local"
        let server = FakeJellyfin()
        server.on("Users/AuthenticateByName") { _, _ in .failure(.serverCertificateUntrusted) }
        let store = CountingSessionStore()
        let client = try server.client(host: host, store: store)
        await #expect(throws: JellyfinClient.JellyfinError.untrustedCertificate) { try await client.liveChannels() }
        #expect(server.count("Users/AuthenticateByName") == 1)
        #expect(await store.saves == 0)
        #expect(await store.clears == 0)
    }

    @Test("jellyfin-live-tv-source/signing-in-remembers-this-device cancellation neither saves nor clears the key")
    func cancellation() async throws {
        let host = "jf-cancel.local"
        let server = FakeJellyfin()
        server.on("LiveTv/Channels") { _, _ in .failure(.cancelled) }
        let saved = JellyfinSession(token: "K-saved", userID: "user-1", serverID: "server-1")
        let store = CountingSessionStore(saved)
        let client = try server.client(host: host, store: store)
        await #expect(throws: CancellationError.self) { try await client.liveChannels() }
        #expect(await store.session == saved)
        #expect(await store.clears == 0)
    }
}

extension JellyfinStubProtocol.Recorded {
    static func !== (lhs: Self, rhs: Self) -> Bool {
        lhs.request != rhs.request || lhs.body != rhs.body
    }
}
