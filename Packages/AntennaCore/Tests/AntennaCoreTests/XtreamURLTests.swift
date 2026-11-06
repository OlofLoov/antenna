import Foundation
import Testing

@testable import AntennaCore

@Suite struct XtreamURLTests {
    private func client(_ server: String, username: String = "u", password: String = "p") throws -> XtreamClient {
        XtreamClient(credentials: XtreamCredentials(server: try #require(URL(string: server)), username: username, password: password))
    }

    @Test("xtream-vod-client/playable-urls movie and episode URLs")
    func playableURLs() throws {
        let client = try client("http://h:8080")
        #expect(client.movieURL(streamID: 55, extension: "mkv").absoluteString == "http://h:8080/movie/u/p/55.mkv")
        #expect(client.episodeURL(episodeID: 901, extension: "mp4").absoluteString == "http://h:8080/series/u/p/901.mp4")
    }

    @Test(
        "xtream-vod-client/playable-urls extension is trimmed, one leading dot dropped, mp4 by default",
        arguments: [(" mkv ", "mkv"), (".mkv", "mkv"), (" .ts", "ts"), ("..mkv", ".mkv"), ("", "mp4"), ("  ", "mp4"), (nil, "mp4")]
            as [(String?, String)])
    func extensionRule(input: String?, expected: String) throws {
        let client = try client("http://h:8080")
        #expect(client.movieURL(streamID: 55, extension: input).lastPathComponent == "55.\(expected)")
        #expect(client.episodeURL(episodeID: 901, extension: input).lastPathComponent == "901.\(expected)")
    }

    @Test("xtream-vod-client/playable-urls a server path is kept", arguments: ["http://h/xtream", "http://h/xtream/"])
    func serverPath(server: String) throws {
        let client = try client(server)
        #expect(client.movieURL(streamID: 55, extension: "mkv").absoluteString == "http://h/xtream/movie/u/p/55.mkv")
        #expect(client.xmltvURL().absoluteString == "http://h/xtream/xmltv.php?username=u&password=p")
    }

    @Test("xtream-vod-client/playable-urls reserved characters in credentials are percent-encoded in every URL")
    func encodedCredentials() throws {
        let client = try client("http://h:8080", password: "a&b/c+d")
        let stream = try JSONDecoder().decode(XtreamLiveStream.self, from: Data(#"{"name":"A","stream_id":42}"#.utf8))
        #expect(client.movieURL(streamID: 55, extension: "mkv").absoluteString == "http://h:8080/movie/u/a%26b%2Fc%2Bd/55.mkv")
        #expect(client.episodeURL(episodeID: 901, extension: "mp4").absoluteString == "http://h:8080/series/u/a%26b%2Fc%2Bd/901.mp4")
        #expect(client.streamURL(for: stream).absoluteString == "http://h:8080/live/u/a%26b%2Fc%2Bd/42.ts")
        #expect(client.xmltvURL().absoluteString == "http://h:8080/xmltv.php?username=u&password=a%26b%2Fc%2Bd")

        let spaced = try self.client("http://h:8080", username: "a b#c?", password: "100%~")
        #expect(spaced.movieURL(streamID: 1, extension: nil).absoluteString == "http://h:8080/movie/a%20b%23c%3F/100%25~/1.mp4")
    }

    static let errors: [XtreamClient.XtreamError] = [
        .badStatus(500), .unauthorized, .transport(.notConnectedToInternet), .decoding(path: "[3].stream_id"),
    ]
    static let forbidden = ["alice-7f3e", "s3cr3t-9b2a", ":8080", "player_api.php", "/movie/", "/series/", "/live/"]

    @Test("xtream-vod-client/errors-and-client-values-never-carry-credentials errors carry no credentials or URLs", arguments: errors)
    func errorsCarryNoSecrets(error: XtreamClient.XtreamError) {
        let texts = [String(describing: error), String(reflecting: error), String(describing: (error as NSError).userInfo)]
        for text in texts {
            for word in Self.forbidden { #expect(!text.contains(word), "\(text) contains \(word)") }
        }
    }

    @Test("xtream-vod-client/errors-and-client-values-never-carry-credentials credentials and client describe themselves by host only")
    func valuesCarryNoSecrets() throws {
        let credentials = XtreamCredentials(
            server: try #require(URL(string: "http://panel.example:8080")), username: "alice-7f3e", password: "s3cr3t-9b2a")
        let client = XtreamClient(credentials: credentials)
        #expect(String(describing: credentials) == "panel.example")
        #expect(String(describing: client) == "panel.example")
        var dumped = ""
        dump(credentials, to: &dumped)
        dump(client, to: &dumped)
        for text in [String(reflecting: credentials), String(reflecting: client), dumped] {
            for word in Self.forbidden { #expect(!text.contains(word), "\(text) contains \(word)") }
        }
        let conformances: [Bool] = [
            (credentials as Any) is any CustomStringConvertible, (credentials as Any) is any CustomDebugStringConvertible,
            (client as Any) is any CustomStringConvertible, (client as Any) is any CustomDebugStringConvertible,
        ]
        #expect(conformances.allSatisfy { $0 })
    }
}
