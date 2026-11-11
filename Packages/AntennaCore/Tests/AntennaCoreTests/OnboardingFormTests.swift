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
}
