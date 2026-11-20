import Foundation
import Testing

@testable import AntennaCore

/// The parser reads ASCII lines byte by byte and splits lines on bytes. These
/// check both against the Character reading on random text.
@Suite struct M3UByteReadingTests {
    /// A deterministic generator, so a failure repeats.
    private struct Generator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state
        }
    }

    private static let asciiPieces = [
        " ", "\t", "\u{0B}", "\u{0C}", "-1", "0", "12.5", "-", "=", "\"", ",", "tvg-id", "TVG-Name", "group-title", "a", "Z", "x=y",
        "inf", "nan", "1e3", "#", "|", "  ", "key=\"v, w\"", "catchup=\"default\"",
    ]

    private static let otherPieces = [
        "\n", "\r", "\r\n", "\u{85}", "\u{2028}", "\u{2029}", "\u{A0}", "\u{301}", "é", "Ö", "١٢", "\u{0600}", "\u{3000}", "🇸🇪",
        "\u{200D}", "©", "€", "\u{FEFF}",
    ]

    private static func text(_ pieces: [String], count: Int, using generator: inout Generator) -> String {
        (0..<count).map { _ in pieces.randomElement(using: &generator)! }.joined()
    }

    @Test("m3u-playlists/standard-attributes-map-to-the-channel an ASCII EXTINF body reads as the Character reading reads it")
    func asciiBodiesMatch() {
        var generator = Generator(state: 1)
        for _ in 0..<20_000 {
            let body = Substring(Self.text(Self.asciiPieces, count: Int.random(in: 0...14, using: &generator), using: &generator))
            #expect(M3UParser.parseASCIIExtInf(body) == M3UParser.parseCharacterExtInf(body), "\(body.debugDescription)")
        }
    }

    @Test("m3u-playlists/standard-attributes-map-to-the-channel lines split as Character.isNewline splits them")
    func linesMatch() {
        var generator = Generator(state: 2)
        let pieces = Self.asciiPieces + Self.otherPieces + ["\n", "\r\n", "\r"]
        for _ in 0..<20_000 {
            let text = Substring(Self.text(pieces, count: Int.random(in: 0...16, using: &generator), using: &generator))
            let expected = text.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
            #expect(M3UParser.lines(text) == expected, "\(text.debugDescription)")
        }
    }

    @Test("m3u-playlists/standard-attributes-map-to-the-channel lines trim as trimmingCharacters(in: .whitespaces) trims them")
    func trimMatches() {
        var generator = Generator(state: 3)
        let pieces = Self.asciiPieces + Self.otherPieces
        for _ in 0..<20_000 {
            let line = Substring(Self.text(pieces, count: Int.random(in: 0...8, using: &generator), using: &generator))
            #expect(M3UParser.trimmedLine(line) == line.trimmingCharacters(in: .whitespaces), "\(line.debugDescription)")
        }
    }

    @Test("m3u-playlists/standard-attributes-map-to-the-channel a mixed playlist parses the same with every line as Characters")
    func playlistsMatch() {
        var generator = Generator(state: 4)
        let names = ["News", "Sport HD", "Café ✓", "قناة", "Kids\u{301}", "Film, Night"]
        var text = "\u{FEFF}#EXTM3U url-tvg=\"http://guide.example/a.xml\"\r\n"
        for index in 0..<500 {
            let name = names.randomElement(using: &generator)!
            text += "#EXTINF:-1 tvg-id=\"c\(index)\" tvg-name=\"\(name)\" group-title=\"G\(index % 7)\",\(name)\r\n"
            text += index.isMultiple(of: 9) ? "#EXTGRP: Extra \n" : ""
            text += "http://example.com/\(index).ts\(index.isMultiple(of: 2) ? "\n" : "\u{2028}")"
        }
        let parsed = M3UParser().parse(text)
        var expected = 0
        for line in text.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("#EXTINF:") else { continue }
            let body = trimmed.dropFirst("#EXTINF:".count)
            let entry = M3UParser.parseCharacterExtInf(body)
            #expect(parsed.channels[expected].name == entry.channel(url: URL(filePath: "/")).name)
            #expect(parsed.channels[expected].group == entry.group)
            expected += 1
        }
        #expect(parsed.channels.count == expected)
    }
}
