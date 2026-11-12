import Foundation
import Testing

@testable import AntennaCore

@Suite struct GuideSettingsTests {
    private let early = Date(timeIntervalSince1970: 1_000)
    private let late = Date(timeIntervalSince1970: 2_000)

    @Test("guide-sources-and-channel-mapping/settings-follow-you-to-every-device two devices match different channels at once")
    func mergeKeepsBoth() {
        var phone = GuideSettings()
        _ = phone.setMatch("news", for: "a", at: late, present: [])
        var tablet = GuideSettings()
        _ = tablet.setMatch("sport", for: "b", at: late, present: [])
        let merged = phone.merged(with: tablet)
        #expect(merged.activeMatches == ["a": "news", "b": "sport"])
        #expect(tablet.merged(with: phone) == merged)
    }

    @Test("guide-sources-and-channel-mapping/settings-follow-you-to-every-device the later change wins, a removal included")
    func laterWins() {
        var base = GuideSettings()
        _ = base.setMatch("news", for: "a", at: early, present: [])
        base.setEnabled(false, for: .provider, at: early)
        base.setOrder([.saved, .provider], at: early)

        var other = base
        other.removeMatch(for: "a", at: late)
        other.setEnabled(true, for: .provider, at: late)
        other.setOrder([.provider, .saved], at: late)

        let merged = base.merged(with: other)
        #expect(merged.activeMatches.isEmpty)
        #expect(merged.flags["provider"]?.enabled == true)
        #expect(merged.order == ["provider", "saved"])
        #expect(other.merged(with: base) == merged)
    }

    @Test("guide-sources-and-channel-mapping/matches-survive-a-playlist-refresh matches for channels that left go first at the cap")
    func cap() {
        var settings = GuideSettings()
        for number in 0..<GuideSettings.matchCap {
            let at = Date(timeIntervalSince1970: TimeInterval(number))
            let done = settings.setMatch("e\(number)", for: "c\(number)", at: at, present: [])
            #expect(done)
        }
        let present = Set((0..<GuideSettings.matchCap).map { "c\($0)" }).subtracting(["c7"])
        let added = settings.setMatch("new", for: "fresh", at: late, present: present)
        #expect(added)
        #expect(settings.matches["c7"] == nil)
        #expect(settings.matches["fresh"]?.entryID == "new")

        let everyone = present.union(["fresh"])
        let refused = settings.setMatch("more", for: "another", at: late, present: everyone)
        #expect(!refused)
        #expect(settings.matches["another"] == nil)
    }

    @Test("guide-sources-and-channel-mapping/passwords-in-guide-links-stay-private a link with a login goes to the Keychain")
    func linkStorage() throws {
        let plain = try #require(URL(string: "https://epg.example/all.xml.gz"))
        let stored = GuideLinkInput.storage(for: plain, at: early)
        #expect(stored.secret == nil)
        #expect(stored.link.plain == plain)

        for text in [
            "http://alice:s3cr3t@epg.example/g.xml", "http://epg.example/all.xml.gz?key=abc123", "http://epg.example/alice/s3cr3t/g.xml",
        ] {
            let url = try #require(URL(string: text))
            let split = GuideLinkInput.storage(for: url, at: early)
            #expect(split.secret == url)
            #expect(split.link.plain == nil)
            let encoded = String(decoding: try JSONEncoder().encode(GuideSettings(links: ["x": split.link])), as: UTF8.self)
            for secret in ["alice", "s3cr3t", "abc123"] { #expect(!encoded.contains(secret)) }
            #expect(GuideLinkInput.shortName(split.link) == "epg.example/…")
        }
    }

    @Test("guide-sources-and-channel-mapping/add-a-guide-link a bad or repeated link is refused")
    func checks() throws {
        let existing = [try #require(URL(string: "http://epg.example/g.xml?key=1"))]
        #expect(GuideLinkInput.check("", existing: existing) == .failure(.invalid))
        #expect(GuideLinkInput.check("epg.example/g.xml", existing: existing) == .failure(.invalid))
        #expect(GuideLinkInput.check("ftp://epg.example/g.xml", existing: existing) == .failure(.invalid))
        #expect(GuideLinkInput.check(" http://epg.example/g.xml?key=1 ", existing: existing) == .failure(.duplicate))
        #expect(
            GuideLinkInput.check("http://epg.example/g.xml?key=2", existing: existing)
                == .success(try #require(URL(string: "http://epg.example/g.xml?key=2"))))
        #expect(GuideLinkInput.Problem.invalid.message == "Enter a valid URL.")
        #expect(GuideLinkInput.Problem.duplicate.message == "This guide is already in the list.")
    }

    @Test func decodesWhatItCanAndDropsLinks() throws {
        let partial = try JSONDecoder().decode(GuideSettings.self, from: Data(#"{"order":["saved"]}"#.utf8))
        #expect(partial.order == ["saved"])
        #expect(partial.matches.isEmpty)

        var settings = GuideSettings()
        let done = settings.addLink(GuideSettings.Link(scheme: "https", host: "h", addedAt: early), id: "a")
        #expect(done)
        settings.setEnabled(false, for: .added("a"), at: early)
        settings.removeLink("a", at: late)
        #expect(settings.activeLinks.isEmpty)
        #expect(settings.links["a"]?.removed == true)
        #expect(settings.flags["added.a"] == nil)
    }
}
