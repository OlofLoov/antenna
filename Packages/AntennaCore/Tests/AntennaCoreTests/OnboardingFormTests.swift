import Foundation
import Testing

@testable import AntennaCore

@Suite struct OnboardingFormTests {
    @Test("first-run-onboarding/mistakes-in-the-form-are-caught-before-connecting: the first empty field in form order")
    func firstEmptyField() {
        #expect(SourceFields(kind: .xtream).check() == .missingField(.server))
        #expect(SourceFields(kind: .xtream, url: "http://a.test").check() == .missingField(.username))
        #expect(SourceFields(kind: .xtream, url: "http://a.test", username: "u").check() == .missingField(.password))
        #expect(SourceFields(kind: .m3u, url: "  ").check() == .missingField(.playlist))
        #expect(SourceFields(kind: .m3u).check()?.message == "Enter the playlist URL.")
        #expect(SourceFields(kind: .xtream).check()?.message == "Enter the server address.")
    }

    @Test("source-management/an-xtream-source-needs-a-username-and-password: blank fields stop Xtream, M3U needs neither")
    func xtreamNeedsALogin() {
        #expect(SourceFields(kind: .xtream, url: "http://a.test", username: " ", password: "p").check() == .missingField(.username))
        #expect(SourceFields(kind: .xtream, url: "http://a.test", username: "u", password: "\t").check() == .missingField(.password))
        #expect(SourceFields(kind: .m3u, url: "http://a.test/list.m3u").check() == nil)
    }

    @Test("first-run-onboarding/mistakes-in-the-form-are-caught-before-connecting: a link without a scheme")
    func invalidLink() {
        let fields = SourceFields(kind: .m3u, url: "example.com/list.m3u")
        #expect(fields.check() == .invalidURL)
        #expect(fields.check()?.message == "Enter a valid URL.")
        #expect(SourceFields(kind: .m3u, url: " http://a.test/list.m3u\t").check() == nil)
        #expect(SourceFields(kind: .xtream, url: "http://a.test:8080", username: "u", password: "p").check() == nil)
    }

    @Test("first-run-onboarding/a-failed-connection-says-why-and-saves-nothing: each failure has its sentence")
    func failureMessages() {
        let host = "tv.example.test"
        #expect(
            ConnectFailure(XtreamClient.XtreamError.unauthorized, host: host).message
                == "Could not sign in. Check the username and password.")
        #expect(ConnectFailure.accountStatus("Expired")?.message == "This account is expired.")
        #expect(ConnectFailure.accountStatus(nil) == nil)
        #expect(ConnectFailure.accountStatus("") == nil)
        #expect(ConnectFailure.accountStatus("active") == nil)
        #expect(
            ConnectFailure(XtreamClient.XtreamError.transport(.notConnectedToInternet), host: host).message
                == "You're offline. Connect to the internet and try again.")
        #expect(ConnectFailure(URLError(.dataNotAllowed), host: host) == .offline)
        #expect(ConnectFailure(URLError(.networkConnectionLost), host: host) == .offline)
        #expect(
            ConnectFailure(URLError(.cannotFindHost), host: host).message
                == "Could not reach tv.example.test. Check the address and try again.")
        #expect(
            ConnectFailure(XtreamClient.XtreamError.badStatus(500), host: host).message
                == "The server answered with an error (500). Check the address and try again.")
        #expect(
            ConnectFailure(XtreamClient.XtreamError.decoding(path: ""), host: host).message
                == "The server replied with something Antenna could not read.")
    }

    @Test("first-run-onboarding/fill-the-form-from-a-copied-link: a link with a login picks Xtream")
    func xtreamLink() throws {
        let link = try #require(CopiedLink("http://Tv.Example.test:8080/get.php?username=anna&password=s3cret&type=m3u_plus"))
        #expect(link == .xtream(server: "http://Tv.Example.test:8080", username: "anna", password: "s3cret"))
        var fields = SourceFields(kind: .m3u, name: "Home")
        fields.fill(from: link)
        #expect(fields.kind == .xtream)
        #expect(fields.url == "http://Tv.Example.test:8080")
        #expect(fields.username == "anna")
        #expect(fields.password == "s3cret")
        #expect(fields.name == "Home")
    }

    @Test("first-run-onboarding/fill-the-form-from-a-copied-link: any other link fills the playlist")
    func playlistLink() throws {
        let link = try #require(CopiedLink(" https://lists.example.test/tv.m3u8 "))
        #expect(link == .playlist("https://lists.example.test/tv.m3u8"))
        var fields = SourceFields(kind: .xtream)
        fields.fill(from: link)
        #expect(fields.kind == .m3u)
        #expect(fields.url == "https://lists.example.test/tv.m3u8")
    }

    @Test("first-run-onboarding/fill-the-form-from-a-copied-link: text that is not one web link fills nothing")
    func notALink() {
        #expect(CopiedLink("hello") == nil)
        #expect(CopiedLink("ftp://files.example.test/a.m3u") == nil)
        #expect(CopiedLink("Your link: http://a.test/x.m3u") == nil)
    }

    @Test("first-run-onboarding/a-working-provider-is-saved-once: links compare without case, spaces or a trailing slash")
    func linkKeys() throws {
        let upper = try #require(URL(string: "HTTP://TV.Example.test:8080/"))
        let lower = try #require(URL(string: "http://tv.example.test:8080"))
        #expect(SourceLink.key(upper) == SourceLink.key(lower))
        let path = try #require(URL(string: "http://tv.example.test/List.m3u"))
        let other = try #require(URL(string: "http://tv.example.test/list.m3u"))
        #expect(SourceLink.key(path) != SourceLink.key(other))
    }

    @Test("first-run-onboarding/add-a-stalker-portal: a portal needs only its address and MAC")
    func portalNeedsOnlyAddressAndMAC() {
        let portal = SourceFields(kind: .stalker, url: "http://portal.example.test/c/", mac: "00-1a-79-12-34-56")
        #expect(portal.check() == nil)
        var withLogin = portal
        withLogin.username = "anna"
        withLogin.password = "s3cret"
        #expect(withLogin.check() == nil)
    }

    @Test("first-run-onboarding/mistakes-in-the-form-are-caught-before-connecting: a portal with a mistyped MAC address")
    func portalMistakes() {
        #expect(SourceFields(kind: .stalker, mac: "00:1A:79:12:34:56").check() == .missingField(.portal))
        #expect(SourceFields(kind: .stalker, url: "http://portal.example.test").check() == .missingField(.mac))
        #expect(SourceFields(kind: .stalker).check()?.message == "Enter the portal address.")
        #expect(SourceFields(kind: .stalker, url: "http://portal.example.test", mac: " ").check()?.message == "Enter the MAC address.")
        #expect(SourceFields(kind: .stalker, url: "portal.example.test/c/", mac: "00:1A:79:12:34:56").check() == .invalidURL)
        #expect(SourceFields(kind: .stalker, url: "ftp://portal.example.test/c/", mac: "00:1A:79:12:34:56").check() == .invalidURL)
        let short = SourceFields(kind: .stalker, url: "http://portal.example.test", mac: "00:1A:79")
        #expect(short.check() == .invalidMAC)
        #expect(short.check()?.message == "Enter a valid MAC address, like 00:1A:79:12:34:56.")
        #expect(SourceFields(kind: .stalker, url: "http://portal.example.test", mac: "00:1A:79:12:34:5G").check() == .invalidMAC)
    }

    @Test("first-run-onboarding/a-failed-connection-says-why-and-saves-nothing: each portal failure has its sentence")
    func portalFailureMessages() {
        let host = "portal.example.test"
        #expect(
            ConnectFailure(StalkerError.notAuthorized, host: host).message
                == "Could not sign in. Check the MAC address, and the login if you have one.")
        #expect(
            ConnectFailure(StalkerError.noPortal, host: host).message
                == "No Stalker portal answered at portal.example.test. Check the address and try again.")
        #expect(
            ConnectFailure(StalkerError.deviceRefused(message: "MAC … is not registered"), host: host).message
                == "The portal refused this device with the message “MAC … is not registered”.")
        #expect(ConnectFailure(StalkerError.transport(.notConnectedToInternet), host: host) == .offline)
        #expect(ConnectFailure(StalkerError.serverError(status: 503), host: host) == .serverError(status: 503))
    }

    @Test("first-run-onboarding/add-a-jellyfin-server: a server needs an http address, username and password")
    func jellyfinFields() {
        let server = SourceFields(kind: .jellyfin, url: "http://jellyfin.local:8096", username: "anna", password: "s3cret")
        #expect(server.check() == nil)
        #expect(SourceFields(kind: .jellyfin, username: "anna", password: "p").check() == .missingField(.server))
        #expect(SourceFields(kind: .jellyfin, url: "http://jf.local", password: "p").check() == .missingField(.username))
        #expect(SourceFields(kind: .jellyfin, url: "http://jf.local", username: "anna").check() == .missingField(.password))
        #expect(SourceFields(kind: .jellyfin, url: "jf.local:8096", username: "a", password: "p").check() == .invalidURL)
        #expect(SourceFields(kind: .jellyfin, url: "ftp://jf.local", username: "a", password: "p").check() == .invalidURL)
        #expect(SourceFields(kind: .jellyfin, url: "https://jf.example.test/jellyfin/", username: "a", password: "p").check() == nil)
    }

    @Test("first-run-onboarding/add-a-jellyfin-server: each Jellyfin failure has its sentence")
    func jellyfinFailureMessages() {
        let host = "jf.local"
        #expect(ConnectFailure(JellyfinClient.JellyfinError.unauthorized, host: host) == .rejected)
        #expect(
            ConnectFailure(JellyfinClient.JellyfinError.forbidden, host: host).message
                == "This account is not allowed to sign in from this device.")
        #expect(
            ConnectFailure(JellyfinClient.JellyfinError.untrustedCertificate, host: host).message
                == "Antenna can't verify this server's certificate. Use http on your network or a trusted certificate.")
        #expect(
            ConnectFailure.noJellyfin(host: host).message == "No Jellyfin server answered at jf.local. Check the address and try again.")
        #expect(ConnectFailure(JellyfinClient.JellyfinError.transport(.notConnectedToInternet), host: host) == .offline)
        #expect(ConnectFailure(JellyfinClient.JellyfinError.transport(.timedOut), host: host) == .unreachable(host: host))
        #expect(ConnectFailure(JellyfinClient.JellyfinError.badStatus(500), host: host) == .serverError(status: 500))
        #expect(ConnectFailure(JellyfinClient.JellyfinError.decoding(path: "Items"), host: host) == .unreadable)
    }
}
