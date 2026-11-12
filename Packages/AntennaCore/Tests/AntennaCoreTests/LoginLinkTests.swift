import Foundation
import Testing

@testable import AntennaCore

@Suite struct LoginLinkTests {
    let token = PairingToken("AAAAAAAAAAAAAAAAAAAAAA") ?? PairingToken()
    let key: SetupKey
    let ids = (0..<9).map { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0 + 1)) ?? UUID() }

    init() throws {
        key = try #require(SetupKey(bytes: Data((0..<32).map { UInt8($0) })))
    }

    @Test("apple-tv-login-from-iphone/the-code-holds-no-secret: a sign-in link holds a version, a code, a key and source ids")
    func signInLinkHoldsNoSecret() throws {
        let link = SetupLink(token: token, key: key, sources: Array(ids.prefix(2)))
        let components = try #require(URLComponents(url: link.url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.map(\.name) == ["v", "t", "k", "s"])
        #expect(components.queryItems?.first?.value == "2")
        #expect(key.text.count == 43)
        let sources = try #require(components.queryItems?.last?.value)
        #expect(sources.split(separator: ",").map(\.count) == [22, 22])
        #expect(link.userInfo == ["link": link.url.absoluteString])
        #expect(link.asksForLogins)
        #expect(try SetupLink(url: link.url) == link)
        #expect(SetupLink(userInfo: link.userInfo) == link)
        #expect(link.url.absoluteString.count < 320)
        #expect("\(key)" == "SetupKey")
    }

    @Test("iphone-as-setup-device/the-code-carries-nothing-but-a-random-one-time-code: the setup card's link adds the key only")
    func setupCardLink() throws {
        let link = SetupLink(token: token, key: key)
        #expect(link.url.absoluteString == "https://antenna.codecrave.se/setup?v=2&t=\(token.text)&k=\(key.text)")
        #expect(!link.asksForLogins)
        #expect(try SetupLink(url: link.url) == link)
    }

    @Test("apple-tv-login-from-iphone/a-code-works-once-and-for-ten-minutes: eight sources at most")
    func eightAtMost() throws {
        let link = SetupLink(token: token, key: key, sources: ids)
        #expect(link.sources == Array(ids.prefix(8)))
        let nine = ids.map { SetupLink(token: token, key: key, sources: [$0]).url }
            .compactMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems?.last?.value }
            .joined(separator: ",")
        let url = try #require(URL(string: "https://antenna.codecrave.se/setup?v=2&t=\(token.text)&k=\(key.text)&s=\(nine)"))
        #expect(throws: SetupLink.Error.malformedSources) { try SetupLink(url: url) }
    }

    @Test("apple-tv-login-from-iphone/the-iphone-asks-before-it-sends: a damaged sign-in link says why")
    func damagedSignInLinks() throws {
        let base = "https://antenna.codecrave.se/setup?v=2&t=\(token.text)"
        let one = try #require(
            URLComponents(url: SetupLink(token: token, key: key, sources: [ids[0]]).url, resolvingAgainstBaseURL: false)?
                .queryItems?.last?.value)
        let cases: [(String, SetupLink.Error)] = [
            (base, .missingKey),
            ("\(base)&k=short", .malformedKey),
            ("\(base)&k=\(key.text.dropLast())B", .malformedKey),
            ("\(base)&k=\(key.text)&k=\(key.text)", .notASetupLink),
            ("\(base)&k=\(key.text)&s=", .malformedSources),
            ("\(base)&k=\(key.text)&s=\(one),", .malformedSources),
            ("\(base)&k=\(key.text)&s=\(one),\(one)", .malformedSources),
            ("\(base)&k=\(key.text)&s=abc", .malformedSources),
            ("\(base)&k=\(key.text)&s=\(one)&s=\(one)", .notASetupLink),
            ("https://antenna.codecrave.se/setup?v=2&t=abc&k=short", .malformedToken),
            ("https://antenna.codecrave.se/setup?v=3&t=\(token.text)&k=\(key.text)", .unsupportedVersion("3")),
        ]
        for (text, expected) in cases {
            let url = try #require(URL(string: text))
            #expect(throws: expected) { try SetupLink(url: url) }
        }
    }

    @Test("iphone-as-setup-device/scanning-opens-the-setup-form-on-the-iphone: a version 1 link still reads")
    func versionOneStillReads() throws {
        let url = try #require(URL(string: "https://antenna.codecrave.se/setup?v=1&t=\(token.text)&k=ignored&s=ignored"))
        let link = try SetupLink(url: url)
        #expect(link == SetupLink(token: token))
        #expect(link.key == nil && link.sources.isEmpty)
        #expect(link.userInfo == ["token": token.text])
        #expect(SetupLink(token: token, sources: ids).sources.isEmpty)
    }

    @Test("apple-tv-login-from-iphone/the-code-holds-no-secret: keys read only in canonical form")
    func keys() {
        #expect(SetupKey(key.text) == key)
        #expect(SetupKey(bytes: Data(count: 31)) == nil)
        #expect(SetupKey(String(repeating: "A", count: 43)) != nil)
        #expect(SetupKey(String(repeating: "A", count: 42) + "B") == nil)
        #expect(SetupKey(String(repeating: "A", count: 42) + "E") != nil)
    }
}

@Suite struct LoginPayloadTests {
    let source = UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF") ?? UUID()

    @Test("apple-tv-login-from-iphone/every-kind-of-source-with-a-login: the payload round-trips each kind")
    func roundTrip() throws {
        let payload = LoginPayload(logins: [
            .init(source: source, username: "anna", password: "secret"),
            .init(source: UUID(), username: "00:1A:79:00:00:01", password: "pin", login: "hallway"),
        ])
        let data = payload.encoded()
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.hasPrefix(#"{"logins":[{"password":"secret","source":"6F9619FF-8B86-D011-B42D-00C04FC964FF","username":"anna"}"#))
        #expect(text.hasSuffix(#""v":1}"#))
        #expect(try LoginPayload(decoding: data) == payload)
    }

    @Test("apple-tv-login-from-iphone/nothing-about-a-login-is-logged-or-kept: printing shows counts only")
    func redacted() {
        let payload = LoginPayload(logins: [.init(source: source, username: "anna", password: "secret")])
        let printed = [
            "\(payload)", String(reflecting: payload), "\(payload.logins[0])", String(reflecting: payload.logins[0]),
        ]
        #expect(printed[0] == "LoginPayload(1 login)")
        #expect(printed.allSatisfy { !$0.contains("anna") && !$0.contains("secret") && !$0.contains(source.uuidString) })
        #expect("\(LoginPayload(logins: []))" == "LoginPayload(0 logins)")
    }

    @Test("apple-tv-login-from-iphone/the-apple-tv-checks-a-login-before-keeping-it: an unknown version or damage is rejected")
    func rejects() {
        #expect(throws: LoginPayload.Error.unknownVersion(2)) { try LoginPayload(decoding: Data(#"{"v":2,"logins":[]}"#.utf8)) }
        #expect(throws: LoginPayload.Error.damaged) { try LoginPayload(decoding: Data("nope".utf8)) }
        #expect(throws: LoginPayload.Error.damaged) { try LoginPayload(decoding: Data(#"{"v":1}"#.utf8)) }
    }
}

@Suite struct LoginRequestPlanTests {
    func candidate(
        _ kind: SourceKind, order: Int, key: Bool = true, login: Bool = false, id: UUID = UUID()
    ) -> LoginRequestPlan.Candidate {
        .init(id: id, kind: kind, hasCredentialKey: key, hasLogin: login, sortOrder: order)
    }

    @Test("apple-tv-login-from-iphone/every-kind-of-source-with-a-login: each kind with a login, in sort order")
    func perKind() {
        let xtream = candidate(.xtream, order: 3)
        let stalker = candidate(.stalker, order: 1)
        let jellyfin = candidate(.jellyfin, order: 2, key: false)
        let channels = candidate(.channelsDVR, order: 0)
        let playlist = candidate(.m3u, order: -1, key: false)
        let file = candidate(.m3uFile, order: -2)
        let signedIn = candidate(.xtream, order: -3, login: true)
        let plan = LoginRequestPlan.sources([xtream, stalker, jellyfin, channels, playlist, file, signedIn])
        #expect(plan == [channels.id, stalker.id, jellyfin.id, xtream.id])
    }

    @Test("apple-tv-login-from-iphone/every-kind-of-source-with-a-login: a Channels DVR server without a password is never asked for")
    func channelsWithoutPassword() {
        #expect(LoginRequestPlan.sources([candidate(.channelsDVR, order: 0, key: false)]).isEmpty)
        #expect(!LoginRequestPlan.carriesLogin(.channelsDVR, hasCredentialKey: false))
        #expect(LoginRequestPlan.carriesLogin(.channelsDVR, hasCredentialKey: true))
    }

    @Test("apple-tv-login-from-iphone/the-apple-tv-sign-in-offers-a-qr-code: the first eight")
    func firstEight() {
        let all = (0..<10).map { candidate(.xtream, order: 9 - $0) }
        let plan = LoginRequestPlan.sources(all)
        #expect(plan.count == 8)
        #expect(plan == all.reversed().prefix(8).map(\.id))
    }
}

@Suite struct SetupArrivalsLoginTests {
    @Test("iphone-as-setup-device/a-login-source-sent-from-the-iphone-needs-only-its-login-on-the-tv: Channels DVR with a login")
    func channelsWithLogin() {
        let shown = Date(timeIntervalSince1970: 1_800_000_000)
        var arrivals = SetupArrivals(present: [], shownAt: shown)
        let id = UUID()
        let candidate = SetupArrivals.Candidate(
            id: id, kind: "channelsdvr", hasAddress: true, createdAt: shown.addingTimeInterval(5), hasCredentialKey: true)
        #expect(arrivals.check([candidate]) == .login(id, .channelsDVR))
    }
}
