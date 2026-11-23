import Foundation
import Testing

@testable import AntennaCore

@Suite struct SavedChannelTests {
    let source = UUID()
    let alice = SavedChannel.Login(username: "alice", password: "s3cr3t-pass")

    private func channel(_ link: String, id: String = "xtream:1", logo: String? = nil) throws -> Channel {
        Channel(
            id: id, name: "News", streamURL: try #require(URL(string: link)), group: "UK", logoURL: logo.flatMap(URL.init(string:)),
            epgID: "news.uk", number: 7, sourceID: source)
    }

    /// The encoded record as text, to look for logins in.
    private func stored(_ saved: SavedChannel) throws -> String {
        String(decoding: try #require(saved.data), as: UTF8.self)
    }

    // MARK: session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login

    @Test(
        "session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login every link shape round-trips with the login put back",
        arguments: [
            "http://panel.example:8080/live/alice/s3cr3t-pass/1.ts",
            "http://panel.example:8080/alice/s3cr3t-pass/1",
            "http://panel.example/play.php?username=alice&password=s3cr3t-pass&id=1",
            "https://cdn.example/hls/news/index.m3u8",
            "file:///fixture/news-one.ts",
        ])
    func roundTrip(link: String) throws {
        let original = try channel(link)
        let saved = try #require(SavedChannel(original, logins: [alice]))
        let restored = try #require(saved.channel(logins: [alice]))
        #expect(restored.streamURL == original.streamURL)
        #expect(restored.id == original.id && restored.sourceID == source)
        #expect(restored.name == "News" && restored.number == 7 && restored.group == "UK" && restored.epgID == "news.uk")
        #expect(saved.key == LastChannelKey(sourceID: source, channelID: "xtream:1"))
    }

    @Test("session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login the encoded record never holds the login")
    func pinning() throws {
        let links = [
            "http://panel.example:8080/live/alice/s3cr3t-pass/1.ts",
            "http://panel.example:8080/alice/s3cr3t-pass/1.m3u8",
            "http://panel.example/play.php?username=alice&password=s3cr3t-pass&id=1",
            "http://panel.example/live/alice/s3cr3t%2Dpass/1.ts",
        ]
        for link in links {
            let saved = try #require(
                SavedChannel(try channel(link, logo: "http://panel.example/logo/alice/s3cr3t-pass/1.png"), logins: [alice]))
            let text = try stored(saved)
            #expect(!text.contains("alice"), "\(link)")
            #expect(!text.contains("s3cr3t"), "\(link)")
            #expect(!String(describing: saved).contains("s3cr3t"))
        }
        #expect(String(describing: alice) == "Login(redacted)")
        var dumped = ""
        dump(alice, to: &dumped)
        #expect(!dumped.contains("alice") && !dumped.contains("s3cr3t"))
    }

    @Test(
        "session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login a link the app cannot clean is not saved",
        arguments: [
            "http://bob:hunter2@panel.example/live/1.ts",
            "http://cdn.example/news.m3u8?token=abc123",
            "http://cdn.example/news.m3u8?wmsAuthSign=abc",
            "http://cdn.example/news.m3u8?api_key=abc",
            "http://cdn.example/news.m3u8#frag",
            "stalker://portal/ch/1",
            "http://cdn.example/stream/alice-s3cr3t-pass-1.ts",
            "http:///no-host.ts",
        ])
    func refused(link: String) throws {
        #expect(SavedChannel(try channel(link), logins: [alice]) == nil)
    }

    @Test("session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login a short password only matches a whole part")
    func shortPassword() throws {
        let short = SavedChannel.Login(username: "bob", password: "1234")
        let saved = try #require(SavedChannel(try channel("http://panel.example/live/bob/1234/12345.ts"), logins: [short]))
        #expect(saved.link.path == [.text(""), .text("live"), .username(0), .password(0), .text("12345.ts")])
    }

    @Test(
        "session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login headers of its own and ids with links are not saved")
    func notSaved() throws {
        var withHeaders = try channel("http://cdn.example/a.ts")
        withHeaders.headers = StreamHeaders(["Referer": "http://site.example/?t=1"])
        #expect(SavedChannel(withHeaders, logins: []) == nil)
        #expect(SavedChannel(try channel("http://cdn.example/a.ts", id: "x#http://cdn.example/a.ts"), logins: []) == nil)
        var untagged = try channel("http://cdn.example/a.ts")
        untagged.sourceID = nil
        #expect(SavedChannel(untagged, logins: []) == nil)
    }

    @Test("session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login a logo that cannot be cleaned is left out")
    func logoLeftOut() throws {
        let saved = try #require(
            SavedChannel(try channel("http://cdn.example/a.ts", logo: "http://img.example/a.png?token=1"), logins: []))
        #expect(saved.logo == nil)
        #expect(saved.channel(logins: [])?.logoURL == nil)
    }

    @Test("session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login a changed password comes back new")
    func changedPassword() throws {
        let saved = try #require(SavedChannel(try channel("http://panel.example/live/alice/s3cr3t-pass/1.ts"), logins: [alice]))
        let changed = SavedChannel.Login(username: "alice", password: "n3w pass/&")
        let restored = try #require(saved.channel(logins: [changed]))
        #expect(restored.streamURL.absoluteString == "http://panel.example/live/alice/n3w%20pass%2F%26/1.ts")
    }

    @Test("session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login a missing login rebuilds nothing")
    func missingLogin() throws {
        let saved = try #require(SavedChannel(try channel("http://panel.example/live/alice/s3cr3t-pass/1.ts"), logins: [alice]))
        #expect(saved.channel(logins: []) == nil)
    }

    @Test("session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login the playlist link's login")
    func playlistLogin() throws {
        let link = try #require(URL(string: "http://panel.example/get.php?username=alice&password=s3cr3t-pass&type=m3u_plus"))
        #expect(SavedChannel.Login(playlistLink: link) == alice)
        #expect(SavedChannel.Login(playlistLink: try #require(URL(string: "http://panel.example/list.m3u"))) == nil)
        #expect(SavedChannel.Login(playlistLink: try #require(URL(string: "http://panel.example/get.php?username=alice&password="))) == nil)
    }

    @Test("session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login unreadable data reads as nothing")
    func unreadable() {
        #expect(SavedChannel(data: Data("not json".utf8)) == nil)
        #expect(SavedChannel(data: nil) == nil)
    }

    // MARK: session-restore-and-recently-watched/the-fresh-list-decides

    @Test("session-restore-and-recently-watched/the-fresh-list-decides the same stream with the login encoded another way")
    func sameStream() throws {
        let fresh = try channel("http://panel.example/live/alice/s3cr3t-pass/1.ts")
        let other = try channel("http://panel.example/live/alice/s3cr3t%2Dpass/1.ts")
        #expect(SavedChannel.sameStream(fresh, other, logins: [alice]))
        #expect(!SavedChannel.sameStream(fresh, try channel("http://panel.example/live/alice/s3cr3t-pass/2.ts"), logins: [alice]))
        #expect(!SavedChannel.sameStream(fresh, try channel("http://other.example/live/alice/s3cr3t-pass/1.ts"), logins: [alice]))
    }
}
