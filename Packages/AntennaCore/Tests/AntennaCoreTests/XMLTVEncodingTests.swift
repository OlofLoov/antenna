import Foundation
import Testing

@testable import AntennaCore

/// Guides saved in Latin-1, with and without an encoding declaration.
@Suite struct XMLTVEncodingTests {
    private func guide(declaration: String) throws -> Data {
        let body = """
            \(declaration)<tv>
            <programme channel="a" start="20261103200000" stop="20261103210000"><title>Bärenstark</title></programme>
            <programme channel="a" start="20261103210000" stop="20261103220000"><title>Fútbol &amp; más</title></programme>
            </tv>
            """
        return try #require(body.data(using: .isoLatin1))
    }

    private func streamedTitles(_ document: Data) throws -> [String] {
        let file = FileManager.default.temporaryDirectory.appending(path: "latin1-\(UUID().uuidString).xml")
        defer { try? FileManager.default.removeItem(at: file) }
        var output = Data()
        let rewritten = XMLEntitySanitizer.sanitize(document, flushingEvery: 7) { output.append(contentsOf: $0) }
        try (rewritten ? output : document).write(to: file)
        let stream = try #require(InputStream(url: file))
        var titles: [String] = []
        try XMLTVParser().parseSanitized(stream) { titles.append($0.title) }
        return titles
    }

    @Test(
        "xmltv-guide-parsing/guide-text-in-latin-1 a guide with no declared encoding, or UTF-8 declared, reads Latin-1 bytes",
        arguments: ["", #"<?xml version="1.0"?>"#, #"<?xml version="1.0" encoding="UTF-8"?>"#, "<?xml version='1.0' encoding='utf8' ?>"])
    func undeclared(declaration: String) throws {
        let document = try guide(declaration: declaration)
        let expected = ["Bärenstark", "Fútbol & más"]
        #expect(try XMLTVParser().parse(document).programmes.map(\.title) == expected)
        #expect(try streamedTitles(document) == expected)
    }

    @Test("xmltv-guide-parsing/guide-text-in-latin-1 a guide that declares Latin-1 is read in Latin-1")
    func declared() throws {
        let document = try guide(declaration: #"<?xml version="1.0" encoding="ISO-8859-1"?>"#)
        var written = 0
        #expect(!XMLEntitySanitizer.sanitize(document, flushingEvery: 64) { written += $0.count })
        #expect(try XMLTVParser().parse(document).programmes.map(\.title) == ["Bärenstark", "Fútbol & más"])
    }

    @Test("xmltv-guide-parsing/stray-ampersands-and-html-entities-are-read-as-text valid UTF-8 needs no rewrite")
    func validUTF8Untouched() {
        let document = Data(
            #"<tv><programme channel="a" start="20261103200000" stop="20261103210000"><title>Bärenstark ✓</title></programme></tv>"#.utf8)
        var written = 0
        #expect(!XMLEntitySanitizer.sanitize(document, flushingEvery: 64) { written += $0.count })
        #expect(written == 0)
    }
}
