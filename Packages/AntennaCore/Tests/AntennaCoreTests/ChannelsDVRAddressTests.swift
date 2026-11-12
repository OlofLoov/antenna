import Foundation
import Testing

@testable import AntennaCore

@Suite struct ChannelsDVRAddressTests {
    static let tidy: [(String, String)] = [
        ("192.168.1.20", "http://192.168.1.20:8089"),
        (" 192.168.1.20:8089 ", "http://192.168.1.20:8089"),
        ("nas.local", "http://nas.local:8089"),
        ("nas.local:8090", "http://nas.local:8090"),
        ("NAS.Local:8089", "http://nas.local:8089"),
        ("nas.local/", "http://nas.local:8089"),
        ("nas.local/channels", "http://nas.local:8089/channels"),
        ("http://nas.local:8089/", "http://nas.local:8089"),
        ("http://nas.local", "http://nas.local"),
        ("HTTP://nas.local", "http://nas.local"),
        ("https://abc.u.channelsdvr.net:8089", "https://abc.u.channelsdvr.net:8089"),
        ("https://home.example.net/channels/?x=1#f", "https://home.example.net/channels"),
        ("[fe80::1]", "http://[fe80::1]:8089"),
        ("[fe80::1]:8090", "http://[fe80::1]:8090"),
    ]

    @Test("channels-dvr-source/type-the-address-the-way-channels-dvr-shows-it tidies a typed address", arguments: tidy)
    func tidiesAddress(typed: String, expected: String) {
        #expect(ChannelsDVRClient.serverURL(from: typed)?.absoluteString == expected)
    }

    @Test(
        "channels-dvr-source/type-the-address-the-way-channels-dvr-shows-it turns down a bad address",
        arguments: [
            "fe80::1", "http://alice:secret@nas.local", "http://alice@nas.local", "alice:secret@nas.local", "ftp://nas.local", "http://",
            "", "   ", "nas.local:", "nas.local:99999", "nas.local:80a", "nas local",
        ])
    func turnsDownBadAddress(typed: String) {
        #expect(ChannelsDVRClient.serverURL(from: typed) == nil)
    }

    @Test("channels-dvr-source/type-the-address-the-way-channels-dvr-shows-it endpoints follow the server and its path")
    func endpoints() throws {
        let home = ChannelsDVRClient(server: try #require(ChannelsDVRClient.serverURL(from: "nas.local")))
        #expect(home.playlistURL().absoluteString == "http://nas.local:8089/devices/ANY/channels.m3u?format=hls&codec=copy")
        #expect(home.guideURL().absoluteString == "http://nas.local:8089/devices/ANY/guide/xmltv.xml?duration=604800")
        #expect(home.statusURL().absoluteString == "http://nas.local:8089/status")
        let proxied = ChannelsDVRClient(server: try #require(ChannelsDVRClient.serverURL(from: "https://home.example.net/channels/")))
        #expect(
            proxied.playlistURL().absoluteString == "https://home.example.net/channels/devices/ANY/channels.m3u?format=hls&codec=copy")
        #expect(proxied.statusURL().absoluteString == "https://home.example.net/channels/status")
    }

    @Test("channels-dvr-source/connect-says-what-it-found versions compare as numbers")
    func versions() throws {
        let short = try #require(ChannelsDVRVersion(parsing: "2023.1.1"))
        #expect(short == ChannelsDVRVersion(parsing: "2023.01.01"))
        #expect(short == ChannelsDVRVersion(parsing: "2023.01.01.0000"))
        #expect(try #require(ChannelsDVRVersion(parsing: "2023.10.2")) > short)
        #expect(ChannelsDVRVersion(parsing: "2025.03.01.0012-dev") == ChannelsDVRVersion(year: 2025, month: 3, day: 1, build: 12))
        #expect(ChannelsDVRVersion(parsing: "custom") == nil)
        #expect(ChannelsDVRVersion(parsing: "2023.1") == nil)
    }

    @Test("channels-dvr-source/reach-a-remote-server-behind-a-password turns down a username Basic cannot carry")
    func usernames() throws {
        #expect(HTTPBasicCredential(username: "", password: "x") == nil)
        #expect(HTTPBasicCredential(username: "al:ice", password: "x") == nil)
        let credential = try #require(HTTPBasicCredential(username: "alice", password: "pa:ss"))
        #expect(credential.headerValue == "Basic " + Data("alice:pa:ss".utf8).base64EncodedString())
    }
}
