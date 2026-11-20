import Foundation
import Testing

@testable import AntennaCore

/// The check a typed guide link gets before it is saved, through a stubbed
/// network and the same reading code the app uses. Each test has its own hosts.
@Suite(.timeLimit(.minutes(1))) struct GuideLinkProbeTests {
    private let probe = GuideLinkProbe(timeout: .seconds(30), fetch: GuideLinkProbe.live(session: GuideStubProtocol.session()))

    private func check(_ host: String, _ reply: GuideStubProtocol.Reply) async throws -> GuideLinkProbe.Verdict {
        GuideStubProtocol.register(host: host, reply)
        return await probe.check(try #require(URL(string: "http://alice:s3cr3t@\(host)/get.php?token=abc123")))
    }

    private func body(_ text: String) -> GuideStubProtocol.Reply {
        .http(chunks: [Data(text.utf8)])
    }

    @Test("guide-sources-and-channel-mapping/add-a-guide-link a link that is not a guide is refused")
    func refused() async throws {
        #expect(try await check("probe-404.test", .http(status: 404, chunks: [])) == .refused(.notFound))
        #expect(try await check("probe-410.test", .http(status: 410, chunks: [])) == .refused(.notFound))
        #expect(try await check("probe-401.test", .http(status: 401, chunks: [])) == .refused(.unauthorized))
        #expect(try await check("probe-403.test", .http(status: 403, chunks: [])) == .refused(.unauthorized))
        #expect(try await check("probe-html.test", body("\n  <!DOCTYPE html><html><body>Log in</body></html>")) == .refused(.webPage))
        #expect(try await check("probe-html2.test", body("<HTML><head>")) == .refused(.webPage))
        #expect(try await check("probe-json.test", body(#"{"user_info":{"auth":0}}"#)) == .refused(.notGuide))
        #expect(try await check("probe-m3u.test", body("#EXTM3U\n#EXTINF:-1,News\n")) == .refused(.notGuide))
        #expect(try await check("probe-rss.test", body("<rss version=\"2.0\">")) == .refused(.notGuide))
    }

    @Test("guide-sources-and-channel-mapping/add-a-guide-link a guide's first bytes pass")
    func guide() async throws {
        #expect(try await check("probe-xml.test", body("\u{FEFF}\r\n<?xml version=\"1.0\"?><tv>")) == .guide)
        #expect(try await check("probe-tv.test", body("  <tv generator-info-name=\"x\">")) == .guide)
        #expect(try await check("probe-doctype.test", body("<!DOCTYPE tv SYSTEM \"xmltv.dtd\">")) == .guide)
        #expect(try await check("probe-gzip.test", .http(chunks: [Data([0x1f, 0x8b, 0x08, 0x00])])) == .guide)
        let fixture = try guideFixture("guide.xmltv")
        GuideStubProtocol.register(host: "probe-big.test", body: fixture + Data(count: 100_000), chunkSize: 1024)
        #expect(await probe.check(try #require(URL(string: "http://probe-big.test/g.xml"))) == .guide)
        #expect(GuideStubProtocol.wasStopped(host: "probe-big.test"))
    }

    @Test("guide-sources-and-channel-mapping/add-a-guide-link an uncertain link is saved")
    func uncertain() async throws {
        #expect(try await check("probe-offline.test", .failure(.notConnectedToInternet)) == .uncertain)
        #expect(try await check("probe-nohost.test", .failure(.cannotFindHost)) == .uncertain)
        #expect(try await check("probe-500.test", .http(status: 500, chunks: [])) == .uncertain)
        #expect(try await check("probe-503.test", .http(status: 503, chunks: [])) == .uncertain)
        #expect(try await check("probe-429.test", .http(status: 429, chunks: [])) == .uncertain)
        #expect(try await check("probe-empty.test", body("")) == .uncertain)
        #expect(try await check("probe-blank.test", body(" \n\t ")) == .uncertain)
        #expect(try await check("probe-comment.test", body("<!-- made by a script -->")) == .uncertain)
        #expect(try await check("probe-short.test", body("<?x")) == .uncertain)

        GuideStubProtocol.register(host: "probe-hang.test", .hang)
        var quick = probe
        quick.timeout = .seconds(1)
        let started = ContinuousClock.now
        #expect(await quick.check(try #require(URL(string: "http://probe-hang.test/g.xml"))) == .uncertain)
        #expect(ContinuousClock.now - started < .seconds(20))
        try await eventually { GuideStubProtocol.wasStopped(host: "probe-hang.test") }
    }

    @Test("the check sends the typed link once")
    func sendsTheTypedLink() async throws {
        _ = try await check("probe-once.test", body("<tv>"))
        let requests = GuideStubProtocol.requests(host: "probe-once.test")
        #expect(requests.count == 1)
        #expect(requests.first?.url?.absoluteString == "http://alice:s3cr3t@probe-once.test/get.php?token=abc123")
    }

    @Test func messages() {
        #expect(GuideLinkInput.Problem.notFound.message(Locale(identifier: "en")) == "The server has nothing at this link.")
        #expect(GuideLinkInput.Problem.webPage.message(Locale(identifier: "en")) == "This link opens a web page, not a guide.")
        #expect(GuideLinkInput.Problem.webPage.message(Locale(identifier: "sv")) == "Länken öppnar en webbsida, inte en guide.")
    }
}
