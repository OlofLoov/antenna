import Foundation
import Testing

@testable import AntennaCore

@Suite struct GuideListTests {
    private func url(_ text: String) throws -> URL {
        try #require(URL(string: text))
    }

    @Test("guide-data/find-the-guide-for-each-source order of preference, nothing over the network")
    func defaultOrder() throws {
        let settings = GuideSettings(links: [
            "l1": GuideSettings.Link(scheme: "http", host: "mine", plain: try url("http://mine/g.xml"), addedAt: .distantPast)
        ])
        let list = GuideList.resolve(
            kind: .xtream, savedURL: try url("http://saved/g.xml"), playlistLinks: [try url("http://head/a.xml")], settings: settings)
        #expect(list.map(\.reference) == [.playlist(0), .saved, .provider, .added("l1")])
        #expect(list.map(\.enabled) == [true, true, false, true])
        #expect(list.map(\.url?.absoluteString) == ["http://head/a.xml", "http://saved/g.xml", nil, "http://mine/g.xml"])
    }

    @Test("guide-data/find-the-guide-for-each-source a link named twice is listed once")
    func duplicates() throws {
        let list = GuideList.resolve(
            kind: .m3u, savedURL: try url("http://head/a.xml"),
            playlistLinks: [try url("http://head/a.xml"), try url("http://head/b.xml"), try url("http://head/a.xml")], settings: .empty)
        #expect(list.map(\.reference) == [.playlist(0), .playlist(1)])
    }

    @Test("guide-data/find-the-guide-for-each-source no guide, and servers that bring their own")
    func ownGuides() throws {
        #expect(GuideList.resolve(kind: .m3u, savedURL: nil, playlistLinks: [], settings: .empty).isEmpty)
        for kind in [SourceKind.stalker, .jellyfin, .channelsDVR, .xtream] {
            let list = GuideList.resolve(kind: kind, savedURL: nil, playlistLinks: [], settings: .empty)
            #expect(list == [GuideListEntry(reference: .provider, enabled: true)])
        }
    }

    @Test("guide-sources-and-channel-mapping/choose-which-guide-wins the user's order and flags apply")
    func userOrder() throws {
        let settings = GuideSettings(
            order: ["provider", "playlist.1"], flags: ["playlist.0": GuideSettings.Flag(enabled: false, modifiedAt: .distantPast)])
        let list = GuideList.resolve(
            kind: .xtream, savedURL: nil, playlistLinks: [try url("http://a/1.xml"), try url("http://a/2.xml")], settings: settings)
        #expect(list.map(\.reference) == [.provider, .playlist(1), .playlist(0)])
        #expect(list.map(\.enabled) == [true, true, false])
    }

    @Test("guide-sources-and-channel-mapping/passwords-in-guide-links-stay-private an added link without its login has no address")
    func keychainLink() {
        let settings = GuideSettings(links: ["k": GuideSettings.Link(scheme: "https", host: "epg.example", addedAt: .distantPast)])
        let missing = GuideList.resolve(kind: .m3u, savedURL: nil, playlistLinks: [], settings: settings)
        #expect(missing == [GuideListEntry(reference: .added("k"), enabled: true, url: nil)])
        let removed = GuideSettings(
            links: ["k": GuideSettings.Link(scheme: "https", host: "epg.example", addedAt: .distantPast, removed: true)])
        #expect(GuideList.resolve(kind: .m3u, savedURL: nil, playlistLinks: [], settings: removed).isEmpty)
    }

    @Test func storageKeysRoundTrip() {
        for reference in [GuideReference.provider, .saved, .playlist(3), .added("a.b")] {
            #expect(GuideReference(storageKey: reference.storageKey) == reference)
        }
        #expect(GuideReference(storageKey: "playlist.x") == nil)
        #expect(GuideReference(storageKey: "added.") == nil)
    }
}

@Suite struct GuideNameMatcherTests {
    let source = UUID()

    private func channel(_ id: String, _ name: String, epgID: String? = nil) -> Channel {
        Channel(id: id, name: name, streamURL: URL(filePath: "/\(id)"), epgID: epgID, sourceID: source)
    }

    private func guide(_ names: [String: String]) -> SourceGuide {
        SourceGuide(names.keys.map { programme($0, guideTime(20), guideTime(21)) }, names: names)
    }

    @Test("guide-sources-and-channel-mapping/channels-matched-by-name one entry with the same name, quality marks ignored")
    func unique() {
        let guides = [guide(["sport1.se": "Sport One", "news": "Nyheter"])]
        let found = GuideNameMatcher.matches(
            channels: [channel("a", "SPORT ONE HD"), channel("b", "Nyhéter"), channel("c", "Sport 1")], guides: guides, excluding: [])
        #expect(found == ["a": "sport1.se", "b": "news"])
    }

    @Test("guide-sources-and-channel-mapping/channels-matched-by-name two candidates or a near match stay unmatched")
    func ambiguous() {
        let guides = [guide(["sport1.se": "Sport One"]), guide(["sportone": "Sport One FHD", "arena": "Arena"])]
        let found = GuideNameMatcher.matches(
            channels: [channel("a", "Sport One"), channel("b", "Arena TV")], guides: guides, excluding: [])
        #expect(found.isEmpty)
    }

    @Test("guide-sources-and-channel-mapping/channels-matched-by-name a channel with a guide id or an undo is left alone")
    func excluded() {
        let guides = [guide(["sport1.se": "Sport One"])]
        let found = GuideNameMatcher.matches(
            channels: [channel("a", "Sport One", epgID: "sport1"), channel("b", "Sport One")], guides: guides, excluding: ["b"])
        #expect(found.isEmpty)
    }

    @Test func words() {
        #expect(GuideNameMatcher.words("SVT1 HD | Sverige") == ["svt1", "sverige"])
        #expect(GuideNameMatcher.words("Kanal 5 +1") == ["kanal", "5", "+1"])
        #expect(GuideNameMatcher.words("HD").isEmpty)
    }
}
