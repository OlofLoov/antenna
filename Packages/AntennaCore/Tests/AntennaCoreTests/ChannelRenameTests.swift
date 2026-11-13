import Foundation
import Testing

@testable import AntennaCore

/// The rewrites a playlist's switch to Xtream runs on what the device and
/// the synced guide settings remember per channel.
@Suite struct ChannelRenameTests {
    let source = UUID()
    let other = UUID()
    let ids = ["m3u.news": "xtream#tv.example#101", "m3u.sport": "xtream#tv.example#102", "m3u.bad": "http://tv.example/u/p/1"]

    @Test("source-management/switching-to-xtream-keeps-what-was-remembered-per-channel recents keep their order, other sources stay")
    func recents() {
        var list = RecentChannels([
            LastChannelKey(sourceID: source, channelID: "m3u.sport"),
            LastChannelKey(sourceID: other, channelID: "m3u.news"),
            LastChannelKey(sourceID: source, channelID: "m3u.movie"),
            LastChannelKey(sourceID: source, channelID: "xtream#tv.example#101"),
            LastChannelKey(sourceID: source, channelID: "m3u.news"),
            LastChannelKey(sourceID: source, channelID: "m3u.bad"),
        ])
        list.renameChannels(ids, source: source)
        #expect(
            list.entries == [
                LastChannelKey(sourceID: source, channelID: "xtream#tv.example#102"),
                LastChannelKey(sourceID: other, channelID: "m3u.news"),
                LastChannelKey(sourceID: source, channelID: "m3u.movie"),
                LastChannelKey(sourceID: source, channelID: "xtream#tv.example#101"),
                LastChannelKey(sourceID: source, channelID: "m3u.bad"),
            ])
        #expect(!list.entries.contains { $0.channelID.contains("://") })
    }

    @Test("source-management/switching-to-xtream-keeps-what-was-remembered-per-channel the last channel moves within its source only")
    func lastChannel() {
        #expect(
            LastChannelKey(sourceID: source, channelID: "m3u.news").renamingChannel(ids, source: source)
                == LastChannelKey(sourceID: source, channelID: "xtream#tv.example#101"))
        #expect(
            LastChannelKey(sourceID: other, channelID: "m3u.news").renamingChannel(ids, source: source)
                == LastChannelKey(sourceID: other, channelID: "m3u.news"))
        #expect(
            LastChannelKey(sourceID: source, channelID: "m3u.bad").renamingChannel(ids, source: source)
                == LastChannelKey(sourceID: source, channelID: "m3u.bad"))
    }

    @Test("source-management/switching-to-xtream-keeps-what-was-remembered-per-channel language picks move, the newer pick wins")
    func languages() {
        let spanish = LanguagePick(audio: "es", subtitle: nil)
        let english = LanguagePick(audio: "en", subtitle: "en")
        var memory = LanguageMemory()
        memory.remember(english, for: "S/xtream#tv.example#101")
        memory.remember(spanish, for: "S/m3u.news")
        memory.remember(english, for: "S/m3u.sport")
        memory.renameChannels(["S/m3u.news": "S/xtream#tv.example#101", "S/m3u.sport": "S/http://x/1"])
        #expect(memory.pick(for: "S/xtream#tv.example#101") == spanish)
        #expect(memory.pick(for: "S/m3u.news") == nil)
        #expect(memory.pick(for: "S/m3u.sport") == english)
        #expect(memory.entries.map(\.channel) == ["S/xtream#tv.example#101", "S/m3u.sport"])
    }

    @Test("source-management/switching-to-xtream-keeps-what-was-remembered-per-channel guide matches move and leave a tombstone")
    func guideMatches() throws {
        let then = Date(timeIntervalSince1970: 1_000)
        let now = Date(timeIntervalSince1970: 2_000)
        var settings = GuideSettings(matches: [
            "m3u.news": .init(entryID: "news.uk", modifiedAt: then),
            "m3u.sport": .init(entryID: "sport.old", modifiedAt: then),
            "xtream#tv.example#102": .init(entryID: "sport.picked", modifiedAt: then),
            "m3u.bad": .init(entryID: "bad", modifiedAt: then),
            "m3u.gone": .init(entryID: nil, modifiedAt: then, removed: true),
        ])
        let moved = settings.moveMatches(ids.merging(["m3u.gone": "xtream#tv.example#9"]) { $1 }, at: now)
        #expect(moved)
        #expect(settings.matches["xtream#tv.example#101"] == .init(entryID: "news.uk", modifiedAt: now))
        #expect(settings.matches["m3u.news"] == .init(entryID: nil, modifiedAt: now, removed: true))
        #expect(settings.matches["xtream#tv.example#102"]?.entryID == "sport.picked")
        #expect(settings.matches["m3u.sport"]?.removed == true)
        #expect(settings.matches["m3u.bad"]?.entryID == "bad")
        #expect(settings.matches["xtream#tv.example#9"] == nil)
        #expect(!settings.matches.keys.contains { $0.contains("://") })

        let older = GuideSettings(matches: ["m3u.news": .init(entryID: "news.uk", modifiedAt: then)])
        #expect(settings.merged(with: older).activeMatches["m3u.news"] == nil)
        let movedAgain = settings.moveMatches(ids, at: now)
        #expect(!movedAgain)
    }
}
