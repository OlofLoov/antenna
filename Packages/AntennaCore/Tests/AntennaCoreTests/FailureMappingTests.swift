import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@Suite struct FailureMappingTests {
    @Test(
        "playback-engine/streams-that-cannot-play-fail-with-a-clear-reason each network cause maps to one reason",
        arguments: [
            (URLError.Code.notConnectedToInternet, PlaybackFailure.offline), (.dataNotAllowed, .offline),
            (.cannotFindHost, .unreachable), (.cannotConnectToHost, .unreachable), (.dnsLookupFailed, .unreachable),
            (.secureConnectionFailed, .secureConnectionFailed), (.serverCertificateUntrusted, .secureConnectionFailed),
            (.appTransportSecurityRequiresSecureConnection, .secureConnectionFailed), (.timedOut, .timedOut),
            (.networkConnectionLost, .stoppedSendingData), (.badServerResponse, .stoppedSendingData),
            (.userAuthenticationRequired, .notAllowed), (.unsupportedURL, .unreadable), (.badURL, .unreadable),
        ])
    func networkCauses(code: URLError.Code, reason: PlaybackFailure) {
        #expect(PlaybackFailure(URLError(code)) == reason)
        #expect(PlaybackFailure.fromPlayerError(URLError(code)) == reason)
    }

    @Test(
        "playback-engine/streams-that-cannot-play-fail-with-a-clear-reason a refused local network prompt fails like an unreachable server")
    func localNetworkRefused() {
        for host in ["192.168.1.20", "10.0.0.5", "172.20.1.1", "169.254.3.4", "tvheadend.local", "[fd00::1]", "fe80::1"] {
            #expect(PlaybackFailure(URLError(.notConnectedToInternet), host: host) == .unreachable, "\(host)")
        }
        for host in ["panel.example", "8.8.8.8", "172.32.0.1", "fcbarcelona.example"] {
            #expect(PlaybackFailure(URLError(.notConnectedToInternet), host: host) == .offline, "\(host)")
        }
    }

    @Test(
        "playback-engine/streams-that-cannot-play-fail-with-a-clear-reason errors from Apple's player map to the same reasons",
        arguments: [
            ("AVFoundationErrorDomain", -11839, PlaybackFailure.noDecoderFree),
            ("AVFoundationErrorDomain", -11828, .unreadable),
            ("AVFoundationErrorDomain", -11850, .unreadable),
            ("AVFoundationErrorDomain", -11835, .notAllowed),
            ("CoreMediaErrorDomain", -12938, .notFound),
            ("CoreMediaErrorDomain", -12660, .notAllowed),
            ("CoreMediaErrorDomain", -12889, .timedOut),
            ("SomeOtherDomain", 7, .unreadable),
        ])
    func playerErrors(domain: String, code: Int, reason: PlaybackFailure) {
        #expect(PlaybackFailure.fromPlayerError(NSError(domain: domain, code: code)) == reason)
    }

    @Test("playback-engine/streams-that-cannot-play-fail-with-a-clear-reason can't decode names the codec")
    func cannotDecodeNamesTheCodec() {
        let mpeg2 = NSNumber(value: UInt32(0x6D70_3276))
        let error = NSError(domain: "AVFoundationErrorDomain", code: -11833, userInfo: ["AVErrorMediaSubTypeKey": [mpeg2]])
        #expect(PlaybackFailure.fromPlayerError(error) == .cannotDecode(codec: "mpeg2video"))
        #expect(CodecName.name(0x6176_6331) == "h264")
        #expect(CodecName.name(0x6876_6331) == "hevc")
        #expect(CodecName.name(0x6163_2D33) == "ac3")
        #expect(CodecName.name(0x6563_2D33) == "eac3")
    }

    @Test("playback-engine/streams-that-cannot-play-fail-with-a-clear-reason the reason comes from the underlying error")
    func underlyingErrors() {
        let url = "http://panel.example/live/alice7/s3cr3t/42.ts"
        let inner = NSError(
            domain: NSURLErrorDomain, code: URLError.cannotConnectToHost.rawValue,
            userInfo: [NSURLErrorFailingURLErrorKey: URL(string: url) as Any])
        let outer = NSError(domain: "AVFoundationErrorDomain", code: -11800, userInfo: [NSUnderlyingErrorKey: inner])
        let reason = PlaybackFailure.fromPlayerError(outer)
        #expect(reason == .unreachable)
        #expect(!String(describing: reason).contains("s3cr3t"))
    }

    @Test(
        "playback-engine/streams-that-cannot-play-fail-with-a-clear-reason a broken address fails without contacting any server",
        arguments: [
            "rtsp://panel.example/live/1", "rtmp://panel.example/live/1", "udp://@239.0.0.1:1234", "mms://panel.example/1",
            "file:///tmp/a.ts", "http:///nohost.ts", "http://pa nel.example/a.ts", "panel.example/a.ts",
        ])
    func brokenAddresses(address: String) async throws {
        let url = try #require(URL(string: address) ?? URL(string: address.replacingOccurrences(of: " ", with: "%20")))
        #expect(throws: PlaybackFailure.unreadable) { try StreamAddress.check(url) }
        let session = PlaybackNetwork.makeSession()
        await #expect(throws: PlaybackFailure.unreadable) { try await StreamProbe.run(url, session: session) }
    }

    @Test func goodAddressesPass() throws {
        for address in [
            "http://panel.example:8080/live/u/p/42.ts", "https://cdn.example/a.m3u8?token=t", "http://192.168.1.2:9981/stream/channel/1",
        ] {
            #expect(throws: Never.self) { try StreamAddress.check(try #require(URL(string: address))) }
        }
    }

    @Test("playback-engine/streams-that-cannot-play-fail-with-a-clear-reason a server that goes quiet times out")
    func silentServerTimesOut() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        defer { Task { await server.stop() } }
        await server.always("/channel.ts", .stall(afterBytes: 0))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 1
        await #expect(throws: PlaybackFailure.timedOut) {
            try await StreamProbe.run(base.appending(path: "channel.ts"), session: URLSession(configuration: configuration))
        }
    }

    @Test("playback-engine/streams-that-cannot-play-fail-with-a-clear-reason a closed port is unreachable")
    func closedPortIsUnreachable() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        await server.stop()
        await #expect(throws: PlaybackFailure.unreachable) {
            try await StreamProbe.run(base.appending(path: "channel.ts"), session: PlaybackNetwork.makeSession())
        }
    }
}

@Suite struct PlaybackPrivacyTests {
    @Test("playback-engine/passwords-never-leak a stream address in a log line keeps only server, port and file type")
    func streamAddressRedaction() throws {
        let url = try #require(URL(string: "http://alice7:s3cr3t@panel.example:8080/live/alice7/s3cr3t/4711.ts?token=abc123"))
        let shown = redacted(url)
        #expect(shown == "http://panel.example:8080/….ts?token=…")
        for secret in ["alice7", "s3cr3t", "4711", "abc123", "/live"] {
            #expect(!shown.contains(secret))
        }
    }

    @Test("playback-engine/passwords-never-leak no reason carries anything from the address")
    func reasonsCarryNothing() {
        let reasons: [PlaybackFailure] = [
            .offline, .unreachable, .secureConnectionFailed, .loginNotOnDevice, .notAllowed, .notFound, .serverBusy, .serverError,
            .refused(status: 418), .timedOut, .stoppedSendingData, .unreadable, .cannotDecode(codec: "mpeg2video"), .noDecoderFree,
        ]
        for reason in reasons {
            let text = String(describing: reason) + String(reflecting: reason)
            #expect(!text.contains("http"))
            #expect(!text.contains("/"))
        }
    }

    @Test("playback-engine/passwords-never-leak the playback session keeps no cache, cookies or credentials")
    func ephemeralSession() {
        let configuration = PlaybackNetwork.makeSession().configuration
        #expect(configuration.urlCache == nil)
        #expect(configuration.httpCookieStorage == nil)
        #expect(configuration.urlCredentialStorage == nil)
        #expect(!configuration.httpShouldSetCookies)
        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
    }
}
