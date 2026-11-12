import Foundation
import Testing

@testable import AntennaCore

/// M3U ids come from the guide id, name and group, never from the link.
@Suite struct M3UChannelIDTests {
    private func ids(_ text: String) -> [String] {
        M3UParser().parse(text).channels.map(\.id)
    }

    private static let xc = """
        #EXTM3U
        #EXTINF:-1 tvg-id="bbc1.uk" group-title="UK",BBC One
        http://panel:8080/live/alice/s3cr3t/42.ts
        #EXTINF:-1 group-title="Family",Kids TV
        http://panel:8080/live/alice/s3cr3t/43.ts
        """

    @Test("m3u-playlists/stable-and-unique-ids an id holds no part of the link")
    func noLinkInID() {
        for id in ids(Self.xc) {
            for part in ["://", "panel", "8080", "alice", "s3cr3t", "42", "live"] {
                #expect(!id.contains(part))
            }
        }
    }

    @Test("m3u-playlists/stable-and-unique-ids a new password, a new server or new order keep every id")
    func survivesProviderChanges() {
        let before = Dictionary(uniqueKeysWithValues: M3UParser().parse(Self.xc).channels.map { ($0.name, $0.id) })
        let password = Self.xc.replacingOccurrences(of: "s3cr3t", with: "n3w")
        let server = Self.xc.replacingOccurrences(of: "panel:8080", with: "other.example")
        let lines = Self.xc.split(separator: "\n").map(String.init)
        let reordered = ([lines[0]] + lines[3...4] + lines[1...2]).joined(separator: "\n")
        for text in [password, server, reordered] {
            let after = Dictionary(uniqueKeysWithValues: M3UParser().parse(text).channels.map { ($0.name, $0.id) })
            #expect(after == before)
        }
    }

    @Test("m3u-playlists/stable-and-unique-ids an entry without tvg-id keeps its id when another is inserted before it")
    func notPositional() throws {
        let kids = try #require(M3UParser().parse(Self.xc).channels.last).id
        let inserted = Self.xc.replacingOccurrences(
            of: "#EXTM3U\n", with: "#EXTM3U\n#EXTINF:-1,New\nhttp://s/new.ts\n")
        #expect(try #require(M3UParser().parse(inserted).channels.last).id == kids)
    }

    @Test("m3u-playlists/stable-and-unique-ids repeats are told apart by their order among themselves")
    func repeats() {
        let main = "#EXTINF:-1 tvg-id=\"x\" group-title=\"G\",X\nhttp://s/main.ts\n"
        let backup = "#EXTINF:-1 tvg-id=\"x\" group-title=\"G\",X\nhttp://s/backup.ts\n"
        let same = "#EXTINF:-1 tvg-id=\"x\" group-title=\"G\",X\nhttp://s/main.ts\n"
        let both = ids("#EXTM3U\n" + main + backup + same)
        #expect(Set(both).count == 3)
        #expect(both[1] == both[0] + ".2")
        #expect(both[2] == both[0] + ".3")
        #expect(ids("#EXTM3U\n" + main) == [both[0]])
    }

    @Test("m3u-playlists/stable-and-unique-ids a new name or group gives a new id, and absent differs from empty")
    func renamed() {
        let base = ids("#EXTINF:-1 tvg-id=\"x\" group-title=\"G\",X\nhttp://s/1.ts")
        let renamed = ids("#EXTINF:-1 tvg-id=\"x\" group-title=\"G\",X HD\nhttp://s/1.ts")
        let moved = ids("#EXTINF:-1 tvg-id=\"x\" group-title=\"H\",X\nhttp://s/1.ts")
        let noGroup = ids("#EXTINF:-1 tvg-id=\"x\",X\nhttp://s/1.ts")
        let emptyGroup = ids("#EXTINF:-1 tvg-id=\"x\" group-title=\"\",X\nhttp://s/1.ts")
        let all: [String] = [base, renamed, moved, noGroup, emptyGroup].flatMap { $0 }
        #expect(all.count == 5)
        #expect(Set(all).count == 5)
    }

    @Test("m3u-playlists/stable-and-unique-ids a title that is a link is not copied into the id")
    func linkAsTitle() throws {
        let id = try #require(ids("#EXTINF:-1,http://h/live/u/p/1.ts\nhttp://h/live/u/p/1.ts").first)
        #expect(id.hasPrefix("m3u."))
        #expect(!id.contains("://") && !id.contains("/"))
    }

    @Test("m3u-playlists/title-fallback an entry with no comma still gets an id")
    func noComma() throws {
        let channel = try #require(M3UParser().parse("#EXTINF:-1 tvg-id=\"x\"\nhttp://s/1.ts").channels.first)
        #expect(channel.name.isEmpty)
        #expect(channel.epgID == nil)
        #expect(channel.id.hasPrefix("m3u."))
    }

    @Test("session-restore-and-recently-watched/links-with-passwords-are-never-stored an M3U channel goes into Recents without its link")
    func recentsKeepM3U() throws {
        let channel = try #require(Channel.tagged(M3UParser().parse(Self.xc).channels, sourceID: UUID()).first)
        let key = try #require(LastChannelKey(channel))
        var recents = RecentChannels()
        recents.record(key)
        #expect(recents.entries == [key])
        let stored = String(decoding: try #require(recents.data), as: UTF8.self)
        let last = String(decoding: try JSONEncoder().encode(key), as: UTF8.self)
        for text in [stored, last] {
            #expect(!text.contains("alice") && !text.contains("s3cr3t") && !text.contains("panel"))
        }
        #expect(GroupRules.canSave(channelID: channel.id))
    }

    // MARK: Earlier ids

    @Test("m3u-playlists/earlier-ids-map-to-the-new-ones earlier ids with and without a guide id map to the new ids")
    func formerIDs() {
        let text = """
            #EXTM3U
            #EXTINF:-1 tvg-id="same.uk",One
            http://s/one.ts
            #EXTINF:-1 tvg-id="",Two
            http://s/two.ts
            #EXTINF:-1,Three
            http://s/three.ts
            """
        let playlist = M3UParser().parse(text)
        let channels = playlist.channels
        #expect(playlist.formerIDs.count == 3)
        #expect(playlist.formerIDs["same.uk#http://s/one.ts"] == channels[0].id)
        #expect(playlist.formerIDs["m3u#http://s/two.ts#2"] == channels[1].id)
        #expect(playlist.formerIDs["m3u#http://s/three.ts#3"] == channels[2].id)
    }

    @Test("m3u-playlists/earlier-ids-map-to-the-new-ones two entries that shared an earlier id map to the first")
    func sharedFormerID() {
        let entry = "#EXTINF:-1 tvg-id=\"x\",X\nhttp://s/1.ts\n"
        let playlist = M3UParser().parse("#EXTM3U\n" + entry + entry)
        #expect(playlist.formerIDs == ["x#http://s/1.ts": playlist.channels[0].id])
    }

    @Test("m3u-playlists/earlier-ids-map-to-the-new-ones positions count channels left out for having no scheme")
    func positionsCountSkipped() {
        let text = "#EXTM3U\n#EXTINF:-1,Bad\nno-scheme\n#EXTINF:-1,Good\nhttp://s/good.ts\n"
        let playlist = PlaylistImport.channels(from: text).playlist
        #expect(playlist.channels.map(\.name) == ["Good"])
        #expect(playlist.formerIDs["m3u#http://s/good.ts#2"] == playlist.channels[0].id)
    }

    @Test("m3u-playlists/earlier-ids-map-to-the-new-ones an imported file maps its earlier ids from the synced text")
    func fileFormerIDs() throws {
        let text = """
            #EXTM3U
            #EXTINF:-1 tvg-id="bbc1.uk",BBC One
            http://panel:8080/live/alice/s3cr3t/42.ts
            #EXTINF:-1,Kids TV
            http://panel:8080/live/alice/s3cr3t/43.ts
            """
        let stripped = PlaylistImport.stripCredentials(text, token: "t0k")
        let restored = try PlaylistImport.restoreCredentials(stripped.text, credentials: stripped.credentials, token: "t0k")
        let playlist = PlaylistImport.playlist(stored: stripped.text, restored: restored)
        let synced = PlaylistImport.channels(from: stripped.text).playlist
        #expect(playlist.channels.map(\.id) == M3UParser().parse(text).channels.map(\.id))
        #expect(playlist.channels[0].streamURL.absoluteString.contains("s3cr3t"))
        // Earlier versions took file ids from the synced text, placeholders and all.
        let earlier = synced.channels.indices.map { M3UParser.formerID(synced.channels[$0], position: $0 + 1) }
        #expect(earlier.allSatisfy { $0.contains("antenna.t0k.user.0") })
        #expect(earlier.map { playlist.formerIDs[$0] } == playlist.channels.map(\.id))
        #expect(playlist.formerIDs.keys.allSatisfy { !$0.contains("s3cr3t") })
    }
}
