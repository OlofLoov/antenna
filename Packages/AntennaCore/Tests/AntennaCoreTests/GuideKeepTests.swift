import Foundation
import Testing

@testable import AntennaCore

/// What a guide keeps while it is read: a window around the download and
/// caps that the channels' own ids fill first.
@Suite struct GuideKeepTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func programme(_ id: String, at offset: TimeInterval, title: String = "News") -> Programme {
        Programme(channelID: id, start: now.addingTimeInterval(offset), stop: now.addingTimeInterval(offset + 1800), title: title)
    }

    private func limits(slots: Int, text: Int = 1_000_000) -> GuideLimits {
        GuideLimits(compressedBytes: 1_000_000, unpackedBytes: 1_000_000, keptSlots: slots, keptText: text)
    }

    @Test("guide-data/a-large-guide-keeps-what-the-channels-can-use programmes outside 7 days back and 14 ahead are dropped")
    func window() {
        var builder = SourceGuide.Builder(keep: GuideKeep(limits: limits(slots: 100), now: now, named: nil))
        let day: TimeInterval = 86_400
        for offset in [-10 * day, -7 * day - 3600, -6 * day, 0, 13 * day, 14 * day + 60, 20 * day] {
            builder.add(programme("a", at: offset))
        }
        let kept = builder.build().programmes["a"]?.map { $0.start.timeIntervalSince(now) } ?? []
        #expect(kept == [-6 * day, 0, 13 * day])
    }

    @Test("guide-data/a-large-guide-keeps-what-the-channels-can-use other ids stop at half the cap, named ids fill it")
    func namedFirst() {
        var builder = SourceGuide.Builder(keep: GuideKeep(limits: limits(slots: 10), now: now, named: ["mine"]))
        for index in 0..<20 { builder.add(programme("other\(index)", at: Double(index) * 1800)) }
        for index in 0..<20 { builder.add(programme("mine", at: Double(index) * 1800)) }
        let guide = builder.build()
        let others = guide.schedules.filter { $0.key != "mine" }.values.reduce(0) { $0 + $1.count }
        #expect(others == 5, "half the cap")
        #expect(guide.schedules["mine"]?.count == 5, "the rest of the cap")
    }

    @Test("guide-data/a-large-guide-keeps-what-the-channels-can-use the text cap counts too")
    func textCap() {
        var builder = SourceGuide.Builder(keep: GuideKeep(limits: limits(slots: 100, text: 40), now: now, named: ["mine"]))
        for index in 0..<10 { builder.add(programme("mine", at: Double(index) * 1800, title: "Title number \(index)")) }
        let kept = builder.build().schedules["mine"]?.count ?? 0
        #expect(kept == 3, "each title is 14 bytes, and adding stops once 40 are used")
    }

    @Test("guide-data/a-large-guide-keeps-what-the-channels-can-use a guide under the caps keeps every programme and id")
    func underTheCaps() {
        var builder = SourceGuide.Builder(keep: GuideKeep(limits: .platform, now: now, named: ["mine"]))
        builder.add(programme("mine", at: 0))
        builder.add(programme("other", at: 0))
        #expect(Set(builder.build().schedules.keys) == ["mine", "other"])
    }

    @Test("guide-data/download-limits-and-timeouts a guide past the old limits is not too large")
    func pastTheOldLimits() {
        #expect(GuideLimits.platform.unpackedBytes >= 512_000_000)
        #expect(GuideLimits.platform.compressedBytes >= 128_000_000)
    }

    @Test("guide-data/a-large-guide-keeps-what-the-channels-can-use the engine keeps the source's own ids first")
    func engineNamesTheChannels() async throws {
        var body = "<tv>"
        for minute in 0..<20 {
            let stamp = "20261103" + "18" + String(format: "%02d", minute) + "00 +0000"
            body += "<programme channel=\"other\(minute)\" start=\"\(stamp)\" stop=\"20261103190000 +0000\"><title>O</title></programme>\n"
        }
        for minute in 0..<20 {
            let stamp = "20261103" + "18" + String(format: "%02d", minute) + "00 +0000"
            body += "<programme channel=\"mine\" start=\"\(stamp)\" stop=\"20261103190000 +0000\"><title>M</title></programme>\n"
        }
        let world = GuideWorld()
        let source = world.add(host: "keep-named.epg")
        GuideStubProtocol.register(host: "keep-named.epg", body: Data((body + "</tv>").utf8))
        let engine = world.engine(limits: limits(slots: 10))
        engine.update(channels: [
            Channel(id: "1", name: "Mine", streamURL: URL(filePath: "/1.ts"), epgID: "mine", sourceID: source.sourceID, position: 0)
        ])
        try await eventually { await engine.channels[source.sourceID] != nil }
        await engine.refresh(sourceID: source.sourceID)
        await engine.idle()
        let window = DateInterval(start: guideTime(17), end: guideTime(20))
        let mine = GuideKey(sourceID: source.sourceID, epgID: "mine")
        let others = (0..<20).map { GuideKey(sourceID: source.sourceID, epgID: "other\($0)") }
        let found = await engine.index.programmes(for: [mine] + others, in: window)
        #expect(found[mine]?.count == 5)
        #expect(others.reduce(0) { $0 + (found[$1]?.count ?? 0) } == 5)
    }

    @Test("live-tv-on-iphone-ipad-mac/a-very-large-source-stays-responsive names are matched again only when the channels or guides change")
    func matchingRunsOnChange() async throws {
        let world = GuideWorld()
        let source = world.add(host: "match-once.epg")
        GuideStubProtocol.register(host: "match-once.epg", body: try guideFixture("guide.xmltv"), chunkSize: 200, pace: .milliseconds(5))
        let engine = world.engine()
        let channels = (0..<3).map {
            Channel(id: "\($0)", name: "Channel \($0)", streamURL: URL(filePath: "/\($0).ts"), sourceID: source.sourceID, position: $0)
        }
        engine.update(channels: channels)
        try await eventually { await engine.channels[source.sourceID] != nil }
        await engine.refresh(sourceID: source.sourceID)
        await engine.idle()
        let afterLoad = await engine.nameMatchRuns
        engine.update(channels: channels)
        engine.update(channels: channels + [Channel(id: "x", name: "X", streamURL: URL(filePath: "/x.ts"), sourceID: source.sourceID)])
        try await eventually { await engine.nameMatchRuns > afterLoad }
        await engine.settingsChanged()
        #expect(await engine.nameMatchRuns == afterLoad + 1, "the same list matched nothing again, the longer one once")
    }
}
