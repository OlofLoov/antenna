import Foundation
import Testing

@testable import AntennaCore

@Suite struct GuideURLResolverTests {
    struct Row: Sendable, CustomTestStringConvertible {
        var name: String
        var kind: SourceKind
        var epgURL: String?
        var playlist: [String] = []
        var withCredential = true
        var expected: String?
        var testDescription: String { name }
    }

    static let rows: [Row] = [
        Row(
            name: "M3U with its own link", kind: .m3u, epgURL: "http://user.example/epg.xml", playlist: ["http://u1/x"],
            expected: "http://user.example/epg.xml"),
        Row(name: "M3U with playlist links", kind: .m3u, playlist: ["http://u1/a.xml", "http://u2/b.xml"], expected: "http://u1/a.xml"),
        Row(name: "M3U with none", kind: .m3u, expected: nil),
        Row(
            name: "Xtream with its own link", kind: .xtream, epgURL: "http://user.example/epg.xml", expected: "http://user.example/epg.xml"),
        Row(name: "Xtream from the login", kind: .xtream, expected: "http://panel:8080/xmltv.php?username=u&password=p%26q"),
        Row(name: "Xtream without a login", kind: .xtream, withCredential: false, expected: nil),
        Row(
            name: "Stalker with its own link", kind: .stalker, epgURL: "http://user.example/epg.xml",
            expected: "http://user.example/epg.xml"),
        Row(name: "Stalker without", kind: .stalker, expected: nil),
    ]

    @Test("0014/AC-1 guide link per source", arguments: rows)
    func resolve(row: Row) throws {
        let resolved = GuideURLResolver.resolve(
            kind: row.kind,
            url: try #require(URL(string: "http://panel:8080")),
            epgURL: row.epgURL.flatMap(URL.init(string:)),
            playlistEPGURLs: row.playlist.compactMap(URL.init(string:)),
            credential: row.withCredential ? (username: "u", password: "p&q") : nil)
        #expect(resolved?.absoluteString == row.expected)
    }
}

@Suite struct RedactionTests {
    @Test(
        "0014/AC-15 redaction removes every login part",
        arguments: [
            ("http://panel:8080/xmltv.php?username=alice7&password=s3cr3t", "http://panel:8080/xmltv.php?username=…&password=…"),
            ("https://alice7:s3cr3t@epg.example/guide.xml.gz", "https://epg.example/guide.xml.gz"),
            ("http://epg.example/g.xml?token=abc123&key=k9#frag", "http://epg.example/g.xml?token=…&key=…"),
            ("http://epg.example/g.xml?abc123", "http://epg.example/g.xml?…"),
            ("http://epg.example/g.xml?abc123=&k9", "http://epg.example/g.xml?…&…"),
        ])
    func redaction(raw: String, expected: String) throws {
        let url = try #require(URL(string: raw))
        let shown = redacted(url)
        #expect(shown == expected)
        for secret in ["alice7", "s3cr3t", "abc123", "k9", "frag"] {
            #expect(!shown.contains(secret))
        }
        #expect(!shown.contains(raw))
    }
}
