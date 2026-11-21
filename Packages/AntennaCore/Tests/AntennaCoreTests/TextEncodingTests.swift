import Foundation
import Testing

@testable import AntennaCore

@Suite struct TextEncodingTests {
    private func latin1(_ text: String) throws -> Data {
        try #require(text.data(using: .isoLatin1))
    }

    @Test("m3u-playlists/playlist-text-in-older-encodings a Latin-1 or Windows-1252 playlist reads its letters")
    func latin1Playlist() throws {
        var data = try latin1("#EXTM3U\n#EXTINF:-1 group-title=\"Españoles\",München\nhttp://a/1.ts\n")
        data.append(Data("#EXTINF:-1,Caf".utf8) + Data([0x80, 0x0A]) + Data("http://a/2.ts\n".utf8))
        let channels = M3UParser().parse(TextEncoding.text(data)).channels
        #expect(channels.map(\.name) == ["München", "Caf€"])
        #expect(channels.first?.group == "Españoles")
    }

    @Test("m3u-playlists/playlist-text-in-older-encodings UTF-8 with a few Latin-1 names keeps both")
    func mixed() throws {
        let data = Data("Zürich ".utf8) + (try latin1("Málaga")) + Data(" ✓".utf8)
        #expect(TextEncoding.text(data) == "Zürich Málaga ✓")
    }

    @Test("m3u-playlists/playlist-text-in-older-encodings byte-order marks, UTF-16 and plain UTF-8")
    func marks() {
        let text = "#EXTM3U\r\n#EXTINF:-1,Één\r\nhttp://example.com/1.ts\r\n"
        #expect(TextEncoding.text(Data(text.utf8)) == text)
        #expect(TextEncoding.text(Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8)) == text)
        var little = Data([0xFF, 0xFE])
        for unit in text.utf16 { little.append(contentsOf: [UInt8(unit & 0xFF), UInt8(unit >> 8)]) }
        #expect(TextEncoding.text(little) == text)
        var big = Data([0xFE, 0xFF])
        for unit in text.utf16 { big.append(contentsOf: [UInt8(unit >> 8), UInt8(unit & 0xFF)]) }
        #expect(TextEncoding.text(big) == text)
        #expect(TextEncoding.text(Data()).isEmpty)
    }

    @Test("m3u-playlists/playlist-text-in-older-encodings bytes the code page leaves out and cut sequences")
    func edges() {
        // 0x81 has no Windows-1252 character; a lead byte at the end has no continuation.
        #expect(TextEncoding.text(Data([0x41, 0x81, 0x42])) == "A\u{FFFD}B")
        #expect(TextEncoding.text(Data([0x41, 0xC3])) == "AÃ")
        #expect(TextEncoding.text(Data([0xED, 0xA0, 0x80])) == "í\u{A0}€")
    }
}
