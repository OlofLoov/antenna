import Foundation
import Testing

@testable import AntennaCore

@Suite("Logins in imported links")
struct StreamLoginsTests {
    let token = "t0k3n"

    @Test("local-m3u-file-import/logins-in-stream-links-stay-private: the three forms are stripped and restored byte for byte")
    func forms() throws {
        let text = """
            #EXTM3U url-tvg="http://panel.example.com/xmltv.php?username=u1&password=p1"\r
            #EXTINF:-1,Query\r
            http://panel.example.com/get.php?username=u1&password=p1&type=m3u_plus\r
            #EXTINF:-1,Path\r
            http://panel.example.com/live/u2/p2/9.m3u8\r
            #EXTINF:-1,Before the host\r
            https://u3:p3@cdn.example.com:8443/hls/1.m3u8\r
            #EXTINF:-1,Too many segments\r
            http://panel.example.com/live/u/p/8/9.ts\r

            """
        let stripped = PlaylistImport.stripCredentials(text, token: token)
        for secret in ["u1", "p1", "u2", "p2", "u3", "p3"] {
            #expect(
                !stripped.text.contains("=\(secret)") && !stripped.text.contains("/\(secret)/") && !stripped.text.contains("\(secret)@"))
        }
        #expect(stripped.text.contains("http://panel.example.com/live/u/p/8/9.ts"))
        #expect(
            stripped.credentials == [
                StreamCredential(host: "panel.example.com", username: "u1", password: "p1"),
                StreamCredential(host: "panel.example.com", username: "u2", password: "p2"),
                StreamCredential(host: "cdn.example.com:8443", username: "u3", password: "p3"),
            ])
        #expect(stripped.text.contains("username={antenna.t0k3n.user.0}&password={antenna.t0k3n.pass.0}&type=m3u_plus"))
        #expect(stripped.text.contains("/live/{antenna.t0k3n.user.1}/{antenna.t0k3n.pass.1}/9.m3u8"))
        #expect(stripped.text.contains("https://{antenna.t0k3n.user.2}:{antenna.t0k3n.pass.2}@cdn.example.com:8443/"))
        let restored = try PlaylistImport.restoreCredentials(stripped.text, credentials: stripped.credentials, token: token)
        #expect(restored == text)
    }

    @Test("local-m3u-file-import/logins-in-stream-links-stay-private: one entry per host and login")
    func distinct() {
        let text = "http://a.example.com/live/u/p/1.ts\nhttp://a.example.com/live/u/p/2.ts\nhttp://b.example.com/live/u/p/3.ts\n"
        let stripped = PlaylistImport.stripCredentials(text, token: token)
        #expect(stripped.credentials.map(\.host) == ["a.example.com", "b.example.com"])
    }

    @Test("local-m3u-file-import/logins-in-stream-links-stay-private: text that looks like a placeholder is left alone")
    func lookalike() throws {
        let text = "#EXTINF:-1,{antenna.user.0} {antenna.t0k3n.user.x}\nhttp://example.com/live/u/p/1.ts\n"
        let token = PlaylistImport.token(for: text, preferred: nil)
        let stripped = PlaylistImport.stripCredentials(text, token: token)
        #expect(stripped.text.hasPrefix("#EXTINF:-1,{antenna.user.0} {antenna.t0k3n.user.x}\n"))
        #expect(try PlaylistImport.restoreCredentials(stripped.text, credentials: stripped.credentials, token: token) == text)
    }

    @Test("local-m3u-file-import/logins-in-stream-links-stay-private: a file without logins is stored as is")
    func noLogins() {
        let text = "#EXTM3U\n#EXTINF:-1,One\nhttp://example.com/1.ts\n"
        let stripped = PlaylistImport.stripCredentials(text, token: token)
        #expect(stripped.text == text)
        #expect(stripped.credentials.isEmpty)
    }

    @Test("local-m3u-file-import/logins-in-stream-links-stay-private: a missing login throws instead of leaking a placeholder")
    func missing() {
        let stripped = PlaylistImport.stripCredentials("http://example.com/live/u/p/1.ts", token: token)
        #expect(throws: PlaylistImport.LoginError.missingCredential(index: 0)) {
            try PlaylistImport.restoreCredentials(stripped.text, credentials: [], token: token)
        }
    }

    @Test("local-m3u-file-import/re-import-onto-the-same-source: a usable earlier token is kept")
    func tokenReuse() {
        #expect(PlaylistImport.token(for: "plain", preferred: "abc") == "abc")
        #expect(PlaylistImport.token(for: "{antenna.abc.user.0}", preferred: "abc") != "abc")
        #expect(PlaylistImport.token(for: "plain", preferred: nil).count == 8)
    }

    @Test("local-m3u-file-import/logins-in-stream-links-stay-private: channel ids hold placeholders, links hold the login")
    func channelIDs() throws {
        let data = try PlaylistImportTests.fixture()
        let text = PlaylistImport.decode(data)
        let stripped = PlaylistImport.stripCredentials(text, token: token)
        #expect(!stripped.text.contains("p1") && !stripped.text.contains("p2@"))
        let restored = try PlaylistImport.restoreCredentials(stripped.text, credentials: stripped.credentials, token: token)
        let playlist = PlaylistImport.playlist(stored: stripped.text, restored: restored)
        #expect(playlist.channels.count == 412)
        #expect(playlist.channels.allSatisfy { !$0.id.contains("p1") && !$0.id.contains("p2") })
        #expect(playlist.channels[0].streamURL.absoluteString == "http://stream.example.com/get.php?username=u1&password=p1&stream=1")
        #expect(playlist.channels[1].streamURL.absoluteString == "http://u2:p2@other.example.com:8080/play/2.m3u8")
        #expect(playlist.epgURLs.map(\.host) == ["guide.example.com"])
    }
}
