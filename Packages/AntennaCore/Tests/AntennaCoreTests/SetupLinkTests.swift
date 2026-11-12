import Foundation
import Testing

@testable import AntennaCore

@Suite struct SetupLinkTests {
    /// A repeatable generator, so a test can name the code it expects.
    struct Counter: RandomNumberGenerator {
        var value: UInt64 = 0
        mutating func next() -> UInt64 {
            value &+= 0x9E37_79B9_7F4A_7C15
            return value
        }
    }

    @Test("iphone-as-setup-device/the-code-carries-nothing-but-a-random-one-time-code: a new code each time")
    func newCodeEachTime() {
        let codes = Set((0..<200).map { _ in PairingToken().text })
        #expect(codes.count == 200)
        #expect(codes.allSatisfy { $0.count == 22 && PairingToken($0) != nil })
        var first = Counter()
        var second = Counter()
        #expect(PairingToken(using: &first) == PairingToken(using: &second))
    }

    @Test("iphone-as-setup-device/the-code-carries-nothing-but-a-random-one-time-code: the link holds a version and the code only")
    func linkHoldsOnlyVersionAndCode() throws {
        let link = SetupLink(token: PairingToken())
        let components = try #require(URLComponents(url: link.url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "https")
        #expect(components.host == SetupLink.host)
        #expect(components.path == "/setup")
        #expect(components.queryItems == [URLQueryItem(name: "v", value: "1"), URLQueryItem(name: "t", value: link.token.text)])
        #expect(components.user == nil && components.password == nil && components.fragment == nil)
        #expect(link.userInfo == ["token": link.token.text])
        #expect(link.token.description == "PairingToken")
    }

    @Test("iphone-as-setup-device/scanning-opens-the-setup-form-on-the-iphone: a link reads back")
    func roundTrip() throws {
        let link = SetupLink(token: PairingToken())
        #expect(try SetupLink(url: link.url) == link)
        let token = link.token.text
        let variants = [
            "https://ANTENNA.codecrave.se/setup?t=\(token)&v=1",
            "https://antenna.codecrave.se/setup/?v=1&t=\(token)",
            "https://antenna.codecrave.se/setup?v=1&utm=x&t=\(token)",
        ]
        for variant in variants {
            #expect(try SetupLink(url: #require(URL(string: variant))) == link)
        }
        #expect(SetupLink(userInfo: ["token": token]) == link)
        #expect(SetupLink(userInfo: ["token": "short"]) == nil)
        #expect(SetupLink(userInfo: nil) == nil)
    }

    @Test("iphone-as-setup-device/scanning-opens-the-setup-form-on-the-iphone: a damaged or newer link says why")
    func damagedLinks() throws {
        let token = PairingToken().text
        let cases: [(String, SetupLink.Error)] = [
            ("https://example.com/setup?v=1&t=\(token)", .notASetupLink),
            ("http://antenna.codecrave.se/setup?v=1&t=\(token)", .notASetupLink),
            ("https://antenna.codecrave.se/other?v=1&t=\(token)", .notASetupLink),
            ("https://antenna.codecrave.se/setup?v=1&v=1&t=\(token)", .notASetupLink),
            ("https://antenna.codecrave.se/setup?v=1&t=\(token)&t=\(token)", .notASetupLink),
            ("https://antenna.codecrave.se/setup?t=\(token)", .missingVersion),
            ("https://antenna.codecrave.se/setup?v=2&t=\(token)", .unsupportedVersion("2")),
            ("https://antenna.codecrave.se/setup?v=1", .missingToken),
            ("https://antenna.codecrave.se/setup?v=1&t=abc", .malformedToken),
            ("https://antenna.codecrave.se/setup?v=1&t=\(token.dropLast())B", .malformedToken),
            ("https://antenna.codecrave.se/setup?v=1&t=\(token.dropLast())+", .malformedToken),
            // A newer version wins over a damaged code: the user is asked to update.
            ("https://antenna.codecrave.se/setup?v=9&t=abc", .unsupportedVersion("9")),
        ]
        for (text, expected) in cases {
            let url = try #require(URL(string: text))
            #expect(throws: expected) { try SetupLink(url: url) }
        }
    }
}

@Suite struct SetupArrivalsTests {
    let shown = Date(timeIntervalSince1970: 1_800_000_000)

    func candidate(_ kind: String, after seconds: TimeInterval, address: Bool = true, id: UUID = UUID()) -> SetupArrivals.Candidate {
        .init(id: id, kind: kind, hasAddress: address, createdAt: shown.addingTimeInterval(seconds))
    }

    @Test("iphone-as-setup-device/a-playlist-source-sent-from-the-iphone-starts-loading-on-the-tv: old sources do not count")
    func oldSourcesIgnored() {
        let existing = candidate("m3u", after: 10)
        var arrivals = SetupArrivals(present: [existing.id], shownAt: shown)
        #expect(arrivals.check([existing]) == nil)
        // Downloaded from iCloud after the card appeared, but created long before.
        #expect(arrivals.check([candidate("m3u", after: -301)]) == nil)
        let drifted = candidate("m3u", after: -120)
        #expect(arrivals.check([drifted]) == .playlist(drifted.id))
        #expect(!arrivals.sawUnusable)
    }

    @Test("iphone-as-setup-device/a-playlist-source-sent-from-the-iphone-starts-loading-on-the-tv: the first of two senders wins")
    func firstOfTwo() {
        var arrivals = SetupArrivals(present: [], shownAt: shown)
        let first = candidate("xtream", after: 20)
        let second = candidate("m3u", after: 30)
        #expect(arrivals.check([second, first]) == .login(first.id, .xtream))
    }

    @Test("iphone-as-setup-device/a-login-source-sent-from-the-iphone-needs-only-its-login-on-the-tv: portals and Jellyfin")
    func stalkerPortal() {
        var arrivals = SetupArrivals(present: [], shownAt: shown)
        let portal = candidate("stalker", after: 5)
        #expect(arrivals.check([portal]) == .login(portal.id, .stalker))
        var later = SetupArrivals(present: [], shownAt: shown)
        let server = candidate("jellyfin", after: 5)
        #expect(later.check([server]) == .login(server.id, .jellyfin))
    }

    @Test("iphone-as-setup-device/nothing-arrives-and-the-tv-says-why-that-might-be: an unknown kind is noted, not used")
    func unknownKind() {
        var arrivals = SetupArrivals(present: [], shownAt: shown)
        #expect(arrivals.check([candidate("channelsDVR", after: 5), candidate("m3u", after: 6, address: false)]) == nil)
        #expect(arrivals.sawUnusable)
        let playlist = candidate("m3u", after: 7)
        #expect(arrivals.check([playlist]) == .playlist(playlist.id))
    }
}
