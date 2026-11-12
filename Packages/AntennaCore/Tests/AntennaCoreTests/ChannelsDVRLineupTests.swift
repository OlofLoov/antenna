import Foundation
import Testing

@testable import AntennaCore

@Suite struct ChannelsDVRLineupTests {
    private func lineup() throws -> [Channel] {
        try ChannelsDVRClient.channels(fromPlaylist: FakeChannelsDVR.fixture("channels.m3u"))
    }

    @Test("channels-dvr-source/channels-keep-the-names-and-numbers-you-set maps the lineup")
    func mapsLineup() throws {
        let channels = try lineup()
        #expect(channels.count == 5)
        let nbc = channels[0]
        #expect(nbc.id == "channelsdvr#id#nbc")
        #expect(nbc.name == "NBC")
        #expect(nbc.number == 6000 && nbc.minorNumber == nil)
        #expect(nbc.epgID == "nbc")
        #expect(nbc.group == "HD")
        #expect(nbc.logoURL?.absoluteString == "https://img.example/s28717.png?w=360&h=270")
        #expect(nbc.streamURL.absoluteString == "http://192.168.1.20:8089/devices/ANY/channels/6000/hls/master.m3u8?codec=copy")
        #expect(!nbc.hasCatchup && nbc.catchupDays == nil)

        let kgw = channels[1]
        #expect(kgw.id == "channelsdvr#id#6.1" && kgw.number == 6 && kgw.minorNumber == 1 && kgw.epgID == "6.1")
        #expect(kgw.name == "KGW 8")
        #expect(channels[2].name == "KGWDS", "the call sign stands in for an empty display name")
    }

    @Test("channels-dvr-source/channels-keep-the-names-and-numbers-you-set ids without a tvg-id, and names")
    func fallbackIDs() throws {
        let text = """
            #EXTM3U
            #EXTINF:-1 tvg-chno="4",Four
            http://h/4
            #EXTINF:-1 tvg-chno="6.1",Six One
            http://h/61
            #EXTINF:-1,
            http://h/x
            #EXTINF:-1 tvg-id="dup",First
            http://h/a
            #EXTINF:-1 tvg-id="dup" catchup="default" catchup-days="3",Second
            http://h/b
            """
        let channels = try ChannelsDVRClient.channels(fromPlaylist: Data(text.utf8))
        #expect(
            channels.map(\.id) == [
                "channelsdvr#no#4", "channelsdvr#no#6.1", "channelsdvr#pos#3", "channelsdvr#id#dup", "channelsdvr#id#dup",
            ])
        #expect(channels[2].name.isEmpty)
        #expect(channels.allSatisfy { !$0.hasCatchup && $0.catchupMode == nil })
    }

    @Test("channels-dvr-source/favorites-survive-an-address-change home and remote addresses give the same ids")
    func sameIDsAtEveryAddress() async throws {
        let home = String(decoding: try FakeChannelsDVR.fixture("channels.m3u"), as: UTF8.self)
        let remote = home.replacingOccurrences(of: "http://192.168.1.20:8089", with: "https://abc.u.channelsdvr.net:8089")
        let atHome = try FakeChannelsDVR(host: "192.168.1.20") { _, _ in .http(200, home) }
        let away = try FakeChannelsDVR(host: "remote-ids.dvr.test") { _, _ in .http(200, remote) }
        let homeIDs = try await atHome.client.channels().map(\.id)
        let awayIDs = try await away.client.channels().map(\.id)
        #expect(homeIDs == awayIDs)
        #expect(homeIDs.allSatisfy { !$0.contains("192.168") && !$0.contains("channelsdvr.net") })
    }

    @Test("channels-dvr-source/favorites-survive-an-address-change flipping the channel id option changes every id")
    func idOptionFlips() throws {
        let withIDs = try lineup()
        let text = String(decoding: try FakeChannelsDVR.fixture("channels.m3u"), as: UTF8.self)
        var flipped = text
        for channel in withIDs {
            guard let epgID = channel.epgID, let number = channel.number else { continue }
            let chno = channel.minorNumber.map { "\(number).\($0)" } ?? "\(number)"
            flipped = flipped.replacingOccurrences(of: #"tvg-id="\#(epgID)""#, with: #"tvg-id="\#(chno)-station""#)
        }
        let after = try ChannelsDVRClient.channels(fromPlaylist: Data(flipped.utf8))
        #expect(Set(after.map(\.id)).isDisjoint(with: withIDs.map(\.id)))
    }

    struct Answer: Sendable {
        var name: String
        var reply: StalkerStubProtocol.Reply
        var expected: Result<Int, ChannelsDVRError>

        init(_ name: String, _ reply: StalkerStubProtocol.Reply, _ expected: Result<Int, ChannelsDVRError>) {
            self.name = name
            self.reply = reply
            self.expected = expected
        }
    }

    static let answers: [Answer] = [
        Answer("empty lineup", .http(200, "#EXTM3U\n"), .success(0)),
        Answer("with a byte-order mark", .http(200, "\u{FEFF}  #EXTM3U\n#EXTINF:-1,One\nhttp://h/1\n"), .success(1)),
        Answer("web page", .http(200, "<!doctype html><html></html>"), .failure(.malformed)),
        Answer("nothing at all", .http(200, ""), .failure(.malformed)),
        Answer("401", .http(401, ""), .failure(.unauthorized)),
        Answer("404", .http(404, ""), .failure(.httpStatus(404))),
        Answer("502", .http(502, ""), .failure(.httpStatus(502))),
        Answer("offline", .failure(.dataNotAllowed), .failure(.offline)),
        Answer("unreachable", .failure(.dnsLookupFailed), .failure(.unreachable(.dnsLookupFailed))),
        Answer("bad server response", .failure(.badServerResponse), .failure(.transport(.badServerResponse))),
    ]

    @Test("channels-dvr-source/an-empty-or-wrong-lineup-is-handled each kind of lineup answer", arguments: answers.indices)
    func lineupAnswer(index: Int) async throws {
        let answer = Self.answers[index]
        let (name, reply, expected) = (answer.name, answer.reply, answer.expected)
        let server = try FakeChannelsDVR(host: "lineup-\(index).dvr.test") { _, _ in reply }
        switch expected {
        case .success(let count):
            #expect(try await server.client.channels().count == count, "\(name)")
        case .failure(let error):
            await #expect(throws: error, "\(name)") { try await server.client.channels() }
        }
        #expect(server.requests.map { $0.url?.path() } == ["/devices/ANY/channels.m3u"], "no status request")
        #expect(server.requests.first?.timeoutInterval == 30)
    }

    @Test("channels-dvr-source/an-empty-or-wrong-lineup-is-handled a full lineup gives all its channels")
    func fullLineup() async throws {
        let body = String(decoding: try FakeChannelsDVR.fixture("channels.m3u"), as: UTF8.self)
        let server = try FakeChannelsDVR(host: "full.dvr.test") { _, _ in .http(200, body) }
        #expect(try await server.client.channels().count == 5)
    }

    @Test("channels-dvr-source/an-empty-or-wrong-lineup-is-handled an older Antenna reads the server page as an empty playlist")
    func olderAntenna() {
        #expect(M3UParser().parse("<!doctype html><html><body>Channels DVR</body></html>").channels.isEmpty)
    }

    @Test(
        "channels-dvr-source/channels-keep-the-names-and-numbers-you-set maps 50 000 entries quickly",
        .enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"))
    func benchmark() throws {
        var text = "#EXTM3U\n"
        for index in 0..<50_000 {
            text += "#EXTINF:-1 tvg-id=\"c\(index)\" tvg-chno=\"\(index / 10).\(index % 10)\" tvg-name=\"C\(index)\",Channel \(index)\n"
            text += "http://h/\(index)\n"
        }
        let playlist = M3UParser(nameSource: .title).parse(text)
        let clock = ContinuousClock()
        let elapsed = clock.measure { _ = ChannelsDVRClient.channels(mapping: playlist) }
        #expect(elapsed < .milliseconds(200))
    }
}

@Suite struct ChannelsDVRGuideMatchTests {
    @Test("channels-dvr-source/the-guide-lines-up-without-manual-matching every guide channel matches exactly one channel")
    func guideLinesUp() throws {
        let channels = try ChannelsDVRClient.channels(fromPlaylist: FakeChannelsDVR.fixture("channels.m3u"))
        let guide = try XMLTVParser().parse(FakeChannelsDVR.fixture("xmltv.xml"))
        #expect(!guide.channelNames.isEmpty)
        for id in guide.channelNames.keys {
            #expect(channels.filter { $0.epgID == id }.count == 1, "\(id)")
        }
        let epgIDs = Set(channels.compactMap(\.epgID))
        #expect(guide.programmes.allSatisfy { epgIDs.contains($0.channelID) })
    }
}

@Suite struct ChannelsDVRPrintingTests {
    @Test("channels-dvr-source/passwords-never-show-up-in-messages-or-logs nothing prints the login or the port")
    func printsNoSecrets() throws {
        let credential = try #require(HTTPBasicCredential(username: "alice7", password: "s3cr3t:x"))
        let server = try #require(ChannelsDVRClient.serverURL(from: "https://home.example.net:8443/channels"))
        let client = ChannelsDVRClient(server: server, credential: credential)
        let encoded = Data("alice7:s3cr3t:x".utf8).base64EncodedString()
        let errors: [ChannelsDVRError] = [
            .offline, .unreachable(.timedOut), .transport(.secureConnectionFailed), .notAChannelsServer, .starting, .unauthorized,
            .httpStatus(502), .malformed, .credentialUnreadable,
        ]
        var printed: [String] = [
            "\(client)", String(reflecting: client), "\(credential)", String(reflecting: credential), "\(Optional(credential) as Any)",
        ]
        var dumped = ""
        dump(client, to: &dumped)
        dump(credential, to: &dumped)
        printed.append(dumped)
        for error in errors {
            printed += ["\(error)", String(reflecting: error), error.localizedDescription]
        }
        for text in printed {
            for secret in ["alice7", "s3cr3t", encoded, "8443"] {
                #expect(!text.contains(secret), "\(text)")
            }
        }
        #expect("\(client)" == "home.example.net")
        #expect("\(credential)" == "HTTPBasicCredential")
    }
}
