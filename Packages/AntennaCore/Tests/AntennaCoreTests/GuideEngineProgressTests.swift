import Foundation
import Testing

@testable import AntennaCore

@Suite(.timeLimit(.minutes(1))) struct GuideEngineProgressTests {
    private func channel(_ source: GuideSourceDescriptor, _ epgID: String?, id: String = UUID().uuidString) -> Channel {
        Channel(id: id, name: id, streamURL: URL(filePath: "/\(id)"), epgID: epgID, sourceID: source.sourceID)
    }

    private func loaded(_ events: [GuideProgress]) -> [GuideProgress] {
        events.filter(isLoaded)
    }

    @Test("guide-data/programmes-land-on-the-right-channels join holds in either order")
    func eitherOrder() async throws {
        let world = GuideWorld()
        let channelsFirst = world.add(host: "ac2-channels-first.epg")
        let guideFirst = world.add(host: "ac2-guide-first.epg")
        for host in ["ac2-channels-first.epg", "ac2-guide-first.epg"] {
            GuideStubProtocol.register(host: host, body: try guideFixture("guide.xmltv"))
        }
        let engine = world.engine()
        let tap = ProgressTap(engine.progressStream())

        engine.update(channels: [channel(channelsFirst, " news.se"), channel(channelsFirst, nil)])
        await engine.refreshIfStale(now: world.now)
        await engine.idle()
        engine.update(channels: [channel(guideFirst, " news.se"), channel(guideFirst, nil)])

        let expected = { (source: GuideSourceDescriptor) in
            GuideProgress.loaded(sourceID: source.sourceID, channelsWithGuide: 1, channelsTotal: 2, days: 2, unmatched: 3)
        }
        try await tap.wait { $0.contains(expected(channelsFirst)) && $0.contains(expected(guideFirst)) }
        #expect(
            loaded(tap.of(guideFirst)).first
                == .loaded(sourceID: guideFirst.sourceID, channelsWithGuide: 0, channelsTotal: 0, days: 2, unmatched: 6))
        let index = await engine.index
        for source in [channelsFirst, guideFirst] {
            #expect(
                index.current(for: GuideKey(sourceID: source.sourceID, epgID: "news.se"), at: guideTime(18, 30))?.title == "Evening News")
            #expect(index.loadingState(for: channel(source, nil)) == .noData)
        }
    }

    @Test("guide-data/progress-a-screen-can-show loaded counts")
    func loadedCounts() async throws {
        let world = GuideWorld()
        world.now = guideTime(30)
        let source = world.add(host: "ac9-counts.epg")
        GuideStubProtocol.register(host: "ac9-counts.epg", body: try guideFixture("guide.xmltv"))
        let engine = world.engine()
        let tap = ProgressTap(engine.progressStream())
        engine.update(channels: [
            channel(source, "news.se"), channel(source, "sport.se"), channel(source, "gone.se"), channel(source, nil),
        ])
        await engine.refreshIfStale(now: world.now)
        await engine.idle()

        let all = GuideProgress.loaded(sourceID: source.sourceID, channelsWithGuide: 2, channelsTotal: 4, days: 1, unmatched: 0)
        try await tap.wait { $0.contains(all) }
        #expect(tap.of(source).first.map { if case .downloading = $0 { true } else { false } } == true)

        engine.update(channels: [channel(source, "news.se")])
        let newsOnly = GuideProgress.loaded(sourceID: source.sourceID, channelsWithGuide: 1, channelsTotal: 1, days: 1, unmatched: 3)
        try await tap.wait { $0.contains(newsOnly) }
        #expect(await engine.index.loadingState(for: GuideKey(sourceID: source.sourceID, epgID: "sport.se")) == .loaded)
    }

    @Test("guide-data/progress-a-screen-can-show every listener hears every event, and a late one hears the latest per source")
    func listeners() async throws {
        let world = GuideWorld()
        let failing = world.add(host: "ac9-late-a.epg")
        let working = world.add(host: "ac9-late-b.epg")
        GuideStubProtocol.register(host: "ac9-late-a.epg", .http(status: 500, chunks: []))
        GuideStubProtocol.register(host: "ac9-late-b.epg", body: try guideFixture("guide.xmltv"))
        let engine = world.engine()
        let first = ProgressTap(engine.progressStream())
        let second = ProgressTap(engine.progressStream())
        await engine.refreshIfStale(now: world.now)
        await engine.idle()
        try await first.wait { $0.contains(where: isLoaded) }
        try await second.wait { $0.contains(where: isLoaded) }
        #expect(first.events.all == second.events.all)

        // Make the lower-sortOrder source the one heard from last, so the
        // replay order below can only come from sortOrder.
        await engine.refresh(sourceID: failing.sourceID)
        await engine.idle()
        try await first.wait { $0.filter(isFailed).count == 2 }

        let late = ProgressTap(engine.progressStream())
        try await late.wait { $0.count >= 2 }
        #expect(late.events.all.first == .failed(sourceID: failing.sourceID, .httpStatus(500)))
        #expect(late.events.all.dropFirst().first.map(isLoaded) == true)
        #expect(late.events.all.dropFirst().first?.sourceID == working.sourceID)
    }

    @Test("guide-data/failures-say-why other sources are untouched")
    func otherSources() async throws {
        let world = GuideWorld()
        let healthy = world.add(host: "ac12-healthy.epg")
        let broken = world.add(host: "ac12-broken.epg")
        GuideStubProtocol.register(host: "ac12-healthy.epg", body: try guideFixture("guide.xmltv"))
        GuideStubProtocol.register(host: "ac12-broken.epg", body: Data("<tv><programme".utf8))
        let engine = world.engine()
        let tap = ProgressTap(engine.progressStream())
        await engine.refreshIfStale(now: world.now)
        await engine.idle()

        try await tap.wait { $0.contains(.failed(sourceID: broken.sourceID, .malformed)) }
        #expect(!tap.of(healthy).contains(where: isFailed))
        let index = await engine.index
        #expect(index.loadingState(for: GuideKey(sourceID: healthy.sourceID, epgID: "news.se")) == .loaded)
        #expect(index.loadingState(for: GuideKey(sourceID: broken.sourceID, epgID: "news.se")) == .failed(.malformed))
        #expect(index.horizon == DateInterval(start: guideTime(18), end: guideTime(25)))
    }

    @Test("guide-data/logins-never-in-the-clear logs and file names carry no login")
    func noLoginInLogs() async throws {
        let world = GuideWorld()
        let link = "http://alice7:s3cr3t@ac15.epg/guide.xml?username=alice7&password=s3cr3t&token=abc123"
        let source = GuideSourceDescriptor(
            sourceID: UUID(), kind: .m3u, url: URL(string: "http://ac15.epg/get.php?password=s3cr3t")!, epgURL: URL(string: link)!)
        world.sources = [source]
        let engine = world.engine()
        let secretChannel = Channel(
            id: "channel-id-9f2", name: "Secret", streamURL: URL(string: "http://ac15.epg/live/alice7/s3cr3t/1.ts")!,
            epgID: "news.se", sourceID: source.sourceID)
        engine.update(channels: [secretChannel])

        GuideStubProtocol.register(host: "ac15.epg", .http(status: 500, chunks: []))
        await engine.refreshIfStale(now: world.now)
        await engine.idle()
        GuideStubProtocol.register(host: "ac15.epg", body: try guideFixture("guide.xmltv"))
        await engine.refresh(sourceID: source.sourceID)
        await engine.idle()

        let lines = world.log.all
        #expect(lines.count == 3)
        #expect(
            lines.contains(
                "guide failed \(source.sourceID.uuidString) http://ac15.epg/….xml?username=…&password=…&token=… httpStatus(500)"))
        for line in lines {
            for secret in ["alice7", "s3cr3t", "abc123", link, "channel-id-9f2", secretChannel.streamURL.absoluteString] {
                #expect(!line.contains(secret))
            }
        }

        // Watch the directory while a load is in flight: the stub sends part
        // of the body and never ends the response.
        let body = try guideFixture("guide.xmltv")
        GuideStubProtocol.register(host: "ac15.epg", body: body.prefix(body.count / 2), finish: false)
        await engine.refresh(sourceID: source.sourceID)
        var names: [String] = []
        try await eventually {
            names = (try? FileManager.default.contentsOfDirectory(atPath: world.directory.path())) ?? []
            return !names.isEmpty
        }
        let allowed = ["download", "xml", "parse.xml"].map { "\(source.sourceID.uuidString).\($0)" }
        #expect(names.allSatisfy(allowed.contains))
        await engine.remove(sourceID: source.sourceID)
        await engine.idle()
    }
}
