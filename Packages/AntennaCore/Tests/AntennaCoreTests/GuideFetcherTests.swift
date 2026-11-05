import Foundation
import Testing

@testable import AntennaCore

/// An uptime that moves on by `step` each time it is read.
final class SteppingUptime: @unchecked Sendable {
    private let lock = NSLock()
    private var now: Duration = .zero
    private let step: Duration
    init(step: Duration) { self.step = step }
    func read() -> Duration {
        lock.withLock {
            now += step
            return now
        }
    }
}

@Suite struct GuideFetcherTests {
    static let small = GuideLimits(compressedBytes: 2_000, unpackedBytes: 4_000)

    private func fetcher(limits: GuideLimits = .platform, uptime: SteppingUptime = SteppingUptime(step: .zero)) -> GuideFetcher {
        GuideFetcher(
            session: GuideStubProtocol.session(), limits: limits, directory: temporaryGuideDirectory(),
            uptime: { uptime.read() }, chunkSize: 1024)
    }

    private func fetch(
        host: String, limits: GuideLimits = .platform, loginURL: Bool = false, events: Recorder<GuideProgress> = Recorder()
    ) async throws -> GuideFetcher.Outcome {
        await fetcher(limits: limits).fetch(
            try #require(URL(string: "http://\(host)/guide.xml")), sourceID: UUID(), loginURL: loginURL,
            progress: { events.append($0) })
    }

    private func error(of outcome: GuideFetcher.Outcome) -> GuideError? {
        if case .failed(let error) = outcome { return error }
        return nil
    }

    static func xml(programmes count: Int) -> Data {
        var body = "<tv>"
        for index in 0..<count {
            body += "<programme channel=\"c\" start=\"2026110318\(String(format: "%02d", index % 60))00 +0000\" "
            body += "stop=\"20261103190000 +0000\"><title>T\(index)</title></programme>\n"
        }
        return Data((body + "</tv>").utf8)
    }

    enum Cause: String, CaseIterable, Sendable {
        case serverError, unauthorizedLogin, forbiddenLogin, unauthorizedPlain, timeout, offline, connectionLost, dataNotAllowed
        case otherNetwork, truncatedGzip, badDeflate, unparsable, noProgrammes, emptyBody, loginPage, png
    }

    private func register(_ cause: Cause, host: String) throws -> (loginURL: Bool, expected: GuideError) {
        let gz = try guideFixture("guide.xmltv.gz")
        switch cause {
        case .serverError:
            GuideStubProtocol.register(host: host, .http(status: 500, chunks: []))
            return (false, .httpStatus(500))
        case .unauthorizedLogin:
            GuideStubProtocol.register(host: host, .http(status: 401, chunks: []))
            return (true, .unauthorized)
        case .forbiddenLogin:
            GuideStubProtocol.register(host: host, .http(status: 403, chunks: []))
            return (true, .unauthorized)
        case .unauthorizedPlain:
            GuideStubProtocol.register(host: host, .http(status: 401, chunks: []))
            return (false, .httpStatus(401))
        case .timeout:
            GuideStubProtocol.register(host: host, .failure(.timedOut))
            return (false, .timeout)
        case .offline:
            GuideStubProtocol.register(host: host, .failure(.notConnectedToInternet))
            return (false, .offline)
        case .connectionLost:
            GuideStubProtocol.register(host: host, .failure(.networkConnectionLost))
            return (false, .offline)
        case .dataNotAllowed:
            GuideStubProtocol.register(host: host, .failure(.dataNotAllowed))
            return (false, .offline)
        case .otherNetwork:
            GuideStubProtocol.register(host: host, .failure(.cannotConnectToHost))
            return (false, .network(.cannotConnectToHost))
        case .truncatedGzip:
            GuideStubProtocol.register(host: host, body: gz.prefix(gz.count / 2))
            return (false, .malformed)
        case .badDeflate:
            GuideStubProtocol.register(host: host, body: Data([0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 3, 0x07, 0, 0]))
            return (false, .malformed)
        case .unparsable:
            GuideStubProtocol.register(host: host, body: Data("<tv><programme channel=\"c\"".utf8))
            return (false, .malformed)
        case .noProgrammes:
            GuideStubProtocol.register(host: host, body: Data("<?xml version=\"1.0\"?><tv></tv>".utf8))
            return (false, .empty)
        case .emptyBody:
            GuideStubProtocol.register(host: host, .http(chunks: []))
            return (false, .empty)
        case .loginPage:
            GuideStubProtocol.register(host: host, body: Data("<html><body><form>Log in</form></body></html>".utf8))
            return (false, .empty)
        case .png:
            GuideStubProtocol.register(host: host, body: Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0]))
            return (false, .unsupportedEncoding)
        }
    }

    @Test("0014/AC-12 failures say why", arguments: Cause.allCases)
    func failures(cause: Cause) async throws {
        let host = "ac12-\(cause.rawValue.lowercased()).epg"
        let (loginURL, expected) = try register(cause, host: host)
        let outcome = try await fetch(host: host, loginURL: loginURL)
        #expect(error(of: outcome) == expected)
    }

    enum Oversize: String, CaseIterable, Sendable {
        case plainWithLength, plainWithoutLength, gzipWithLength, gzipWithoutLength, unpacksTooLarge
    }

    @Test("0014/AC-12 too large stops within a chunk", arguments: Oversize.allCases)
    func tooLarge(kind: Oversize) async throws {
        let host = "ac12-large-\(kind.rawValue.lowercased()).epg"
        var random = SystemRandomNumberGenerator()
        let noise = Data((0..<20_000).map { _ in UInt8.random(in: 0x61...0x7a, using: &random) })
        let limit: Int64
        switch kind {
        case .plainWithLength, .plainWithoutLength:
            GuideStubProtocol.register(host: host, body: Data("<tv>".utf8) + noise, contentLength: kind == .plainWithLength, finish: false)
            limit = Self.small.unpackedBytes
        case .gzipWithLength, .gzipWithoutLength:
            GuideStubProtocol.register(
                host: host, body: try gzip(Data("<tv>".utf8) + noise), contentLength: kind == .gzipWithLength, finish: false)
            limit = Self.small.compressedBytes
        case .unpacksTooLarge:
            let bomb = try gzip(Data("<tv>".utf8) + Data(repeating: 0x20, count: 200_000))
            GuideStubProtocol.register(host: host, body: bomb)
            #expect(Int64(bomb.count) < Self.small.compressedBytes)
            limit = Self.small.compressedBytes
        }
        let events = Recorder<GuideProgress>()
        let outcome = try await fetch(host: host, limits: Self.small, events: events)

        #expect(error(of: outcome) == .tooLarge)
        guard case .downloading(_, let received, _) = events.all.last else {
            Issue.record("no download progress before the failure")
            return
        }
        #expect(received <= limit + 1024)
        if kind != .unpacksTooLarge {
            // The stub never ends these responses, so the fetch returns only
            // because the fetcher cancelled the download.
            try await eventually { GuideStubProtocol.wasStopped(host: host) }
        }
    }

    @Test("0014/AC-17 a gzip guide without Content-Encoding loads end to end")
    func gzipEndToEnd() async throws {
        GuideStubProtocol.register(host: "ac17-gzip.epg", body: try guideFixture("guide.xmltv.gz"), chunkSize: 5)
        let outcome = try await fetch(host: "ac17-gzip.epg")
        guard case .loaded(let guide) = outcome else {
            Issue.record("expected a loaded guide, got \(outcome)")
            return
        }
        #expect(guide.count == 6)
    }

    @Test("0014/AC-9 download progress is throttled")
    func progressThrottle() async throws {
        let body = Self.xml(programmes: 120)
        let size = body.count
        let chunks = (size + 1023) / 1024
        GuideStubProtocol.register(host: "ac9-throttle.epg", body: body)
        GuideStubProtocol.register(host: "ac9-unknown.epg", body: body, contentLength: false)
        let uptime = SteppingUptime(step: .milliseconds(100))
        let events = Recorder<GuideProgress>()
        let sourceID = UUID()
        _ = await fetcher(uptime: uptime).fetch(
            try #require(URL(string: "http://ac9-throttle.epg/g.xml")), sourceID: sourceID, loginURL: false,
            progress: { events.append($0) })

        var expected: [Int64] = Array(stride(from: 1, through: chunks - 1, by: 3)).map { Int64($0 * 1024) }
        if expected.last != Int64(size) { expected.append(Int64(size)) }
        #expect(events.all == expected.map { .downloading(sourceID: sourceID, bytesReceived: $0, expectedBytes: Int64(size)) })

        let unknown = Recorder<GuideProgress>()
        _ = await fetcher().fetch(
            try #require(URL(string: "http://ac9-unknown.epg/g.xml")), sourceID: sourceID, loginURL: false,
            progress: { unknown.append($0) })
        #expect(unknown.all.first == .downloading(sourceID: sourceID, bytesReceived: 1024, expectedBytes: nil))
    }

    @Test func requestAndSessionConfiguration() async throws {
        GuideStubProtocol.register(host: "config.epg", body: try guideFixture("guide.xmltv"))
        _ = try await fetch(host: "config.epg")
        let request = try #require(GuideStubProtocol.requests(host: "config.epg").first)
        #expect(request.value(forHTTPHeaderField: "Range") == nil)
        #expect(request.value(forHTTPHeaderField: "Cookie") == nil)

        let configuration = URLSessionConfiguration.guide
        #expect(configuration.timeoutIntervalForRequest == 30)
        #expect(configuration.timeoutIntervalForResource == 600)
        #expect(configuration.urlCache == nil)
        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
        #expect(configuration.httpShouldSetCookies == false)
        #expect(configuration.httpCookieAcceptPolicy == .never)
        #expect(configuration.httpCookieStorage == nil)
    }
}
