import Foundation
import Testing

@testable import AntennaCore

@Suite("Playlist import checks")
struct PlaylistImportTests {
    private func inspect(_ text: String) -> PlaylistImport.Outcome {
        PlaylistImport.inspect(Data(text.utf8))
    }

    static func fixture() throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "import-412.m3u", withExtension: nil, subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    @Test("local-m3u-file-import/a-file-too-large-is-refused-before-it-is-read: over 16 MB is too large before decoding")
    func tooLarge() {
        let bytes = Data(repeating: 0xFF, count: PlaylistImport.maximumBytes + 1)
        #expect(PlaylistImport.inspect(bytes) == .tooLarge(bytes: PlaylistImport.maximumBytes + 1))
        #expect(!PlaylistImport.isTooLarge(PlaylistImport.maximumBytes))
    }

    @Test("local-m3u-file-import/a-file-too-large-is-refused-before-it-is-read: the title names the size and the limit")
    func tooLargeText() {
        let text = ImportText(locale: Locale(identifier: "en_US"))
        let known = text.problem(.tooLarge(bytes: 41_700_000), fileName: "big.m3u")
        #expect(known?.title == "This file is 41.7 MB. Antenna imports playlists up to 16 MB.")
        #expect(known?.body == "Split the file, or host it and add the link as an M3U source instead.")
        let unknown = text.problem(.tooLarge(bytes: nil), fileName: "big.m3u")
        #expect(unknown?.title == "This file is larger than 16 MB. Antenna imports playlists up to 16 MB.")
    }

    @Test("local-m3u-file-import/a-file-that-is-not-a-channel-list-is-explained: a web page named .m3u has no channels")
    func webPage() {
        let html = "<!DOCTYPE html>\n<html><head><title>Login</title></head>\n<body>http://example.com/a</body></html>\n"
        #expect(inspect(html) == .noChannels(sawEntries: false))
        let problem = ImportText().problem(inspect(html), fileName: "home.m3u")
        #expect(problem?.title == "No channels found in home.m3u.")
    }

    @Test("local-m3u-file-import/a-file-that-is-not-a-channel-list-is-explained: empty, header only and entries without links")
    func emptyKinds() {
        #expect(inspect("") == .noChannels(sawEntries: false))
        #expect(inspect("#EXTM3U\n") == .noChannels(sawEntries: false))
        #expect(inspect("#EXTM3U\n#EXTINF:-1,One\n#EXTINF:-1,Two\n") == .noChannels(sawEntries: false))
        #expect(PlaylistImport.inspect(Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00])) == .noChannels(sawEntries: false))
        let noScheme = "#EXTM3U\n#EXTINF:-1,One\nchannel one\n#EXTINF:-1,Two\n/streams/2.ts\n"
        #expect(inspect(noScheme) == .noChannels(sawEntries: true))
        #expect(ImportText().problem(inspect(noScheme), fileName: "a.m3u")?.body == "The entries in this file are not links.")
    }

    @Test("local-m3u-file-import/a-file-that-is-not-a-channel-list-is-explained: one link and a list of links")
    func links() throws {
        let one = inspect("http://example.com/list.m3u\n")
        #expect(one == .linkList([try #require(URL(string: "http://example.com/list.m3u"))]))
        #expect(ImportText().problem(one, fileName: "a.txt")?.title == "This file is a link, not a playlist.")
        let several = inspect("# my links\nhttps://a.example.com/1\n\nhttp://b.example.com/2\n")
        guard case .linkList(let urls) = several else {
            Issue.record("expected a link list, got \(several)")
            return
        }
        #expect(urls.map(\.host) == ["a.example.com", "b.example.com"])
        #expect(ImportText().problem(several, fileName: "a.txt")?.title == "This file is a list of links, not a playlist.")
        #expect(inspect("http://a.example.com/1\nnot a link\n") == .noChannels(sawEntries: false))
    }

    @Test("local-m3u-file-import/a-file-that-is-not-a-channel-list-is-explained: a single HLS stream")
    func hlsStream() {
        let media = "#EXTM3U\n#EXT-X-TARGETDURATION:6\n#EXTINF:6.0,\nseg1.ts\n"
        #expect(inspect(media) == .hlsStream)
        let variants = "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=800000\nhttp://example.com/low.m3u8\n"
        #expect(inspect(variants) == .hlsStream)
        let withSessionData = "#EXTM3U\n#EXT-X-SESSION-DATA:DATA-ID=\"x\"\n#EXTINF:-1,One\nhttp://example.com/1.ts\n"
        guard case .playlist = inspect(withSessionData) else {
            Issue.record("session data alone is not a single stream")
            return
        }
        #expect(ImportText().problem(.hlsStream, fileName: "a.m3u8")?.title == "This is a single stream, not a channel list.")
    }

    @Test("local-m3u-file-import/see-what-s-in-the-file-before-importing: an old Windows encoding imports with replacement characters")
    func windowsEncoding() {
        var data = Data("#EXTM3U\n#EXTINF:-1,Caf".utf8)
        data.append(0xE9)
        data.append(Data("\nhttp://example.com/1.ts\n".utf8))
        guard case .playlist(let inspected) = PlaylistImport.inspect(data) else {
            Issue.record("expected a playlist")
            return
        }
        #expect(inspected.playlist.channels.first?.name == "Caf\u{FFFD}")
    }

    @Test("local-m3u-file-import/see-what-s-in-the-file-before-importing: byte-order marks and UTF-16")
    func encodings() {
        let text = "#EXTM3U\r\n#EXTINF:-1,Één\r\nhttp://example.com/1.ts\r\n"
        let bom = Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8)
        #expect(PlaylistImport.decode(bom) == text)
        var little = Data([0xFF, 0xFE])
        for unit in text.utf16 { little.append(contentsOf: [UInt8(unit & 0xFF), UInt8(unit >> 8)]) }
        #expect(PlaylistImport.decode(little) == text)
        var big = Data([0xFE, 0xFF])
        for unit in text.utf16 { big.append(contentsOf: [UInt8(unit >> 8), UInt8(unit & 0xFF)]) }
        #expect(PlaylistImport.decode(big) == text)
        guard case .playlist(let inspected) = PlaylistImport.inspect(little) else {
            Issue.record("expected a playlist")
            return
        }
        #expect(inspected.playlist.channels.map(\.name) == ["Één"])
    }

    @Test("local-m3u-file-import/see-what-s-in-the-file-before-importing: the 412-channel fixture")
    func summary() throws {
        guard case .playlist(let inspected) = PlaylistImport.inspect(try Self.fixture()) else {
            Issue.record("expected a playlist")
            return
        }
        let summary = ImportText(locale: Locale(identifier: "en_US")).summary(inspected)
        #expect(summary.channels == "412 channels in 18 groups")
        #expect(summary.groups == "News, Sport, Movies, Kids, Music, Documentary, Entertainment, Series and 10 more")
        #expect(summary.guideHost == "guide.example.com")
        #expect(summary.skipped == "3 entries skipped")
        #expect(PlaylistImport.channels(from: inspected.text).playlist.channels.count == 412)
    }

    @Test("local-m3u-file-import/see-what-s-in-the-file-before-importing: Swedish counts group with a no-break space")
    func swedishCounts() {
        let channels = (1...1240).map {
            Channel(id: "\($0)", name: "\($0)", streamURL: URL(fileURLWithPath: "/\($0)"), group: "G\($0 % 3)")
        }
        let inspected = PlaylistImport.Inspected(text: "", playlist: Playlist(channels: channels), skipped: 0)
        #expect(ImportText(locale: Locale(identifier: "sv_SE")).summary(inspected).channels == "1\u{00A0}240 channels in 3 groups")
        #expect(ImportText(locale: Locale(identifier: "sv_SE")).summary(inspected).skipped == nil)
    }

    @Test("local-m3u-file-import/a-file-that-is-not-a-channel-list-is-explained: an unreadable file")
    func unreadable() {
        #expect(ImportText().unreadable(fileName: "a.m3u").title == "Could not read a.m3u. Make sure it is downloaded and try again.")
        #expect(ImportText().unreadable(fileName: "a.m3u").body == nil)
    }

    @Test("local-m3u-file-import/see-what-s-in-the-file-before-importing: the default name drops the extension")
    func defaultName() {
        #expect(ImportText.defaultName(fileName: "home-playlist.m3u") == "home-playlist")
        #expect(ImportText.defaultName(fileName: "list") == "list")
    }
}
