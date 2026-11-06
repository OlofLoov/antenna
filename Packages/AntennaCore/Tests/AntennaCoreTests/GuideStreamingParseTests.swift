import Foundation
import Testing

@testable import AntennaCore

/// The streamed parse the guide uses must read a document exactly as the
/// whole-document parse of 0002 does.
@Suite struct GuideStreamingParseTests {
    static let messy = Data(
        """
        <?xml version="1.0"?>
        <tv><programme start="20261103180000 +0000" stop="20261103190000 +0000" channel="a">\
        <title>Tom &amp; Jerry &nbsp;&copy; & more &#38; &bogus; end</title></programme></tv>
        """.utf8)

    static let rewritten =
        """
        <?xml version="1.0"?>
        <tv><programme start="20261103180000 +0000" stop="20261103190000 +0000" channel="a">\
        <title>Tom &amp; Jerry &#160;&#169; &amp; more &#38; &amp;bogus; end</title></programme></tv>
        """

    @Test("A rewrite that falls on a piece boundary comes out whole", arguments: [1, 2, 3, 5, 7, 16, 64, 1 << 16])
    func pieceBoundaries(chunkSize: Int) {
        var output = Data()
        var largestPiece = 0
        let changed = XMLEntitySanitizer.sanitize(Self.messy, flushingEvery: chunkSize) { piece in
            output.append(contentsOf: piece)
            largestPiece = max(largestPiece, piece.count)
        }
        #expect(changed)
        #expect(String(decoding: output, as: UTF8.self) == Self.rewritten)
    }

    @Test func cleanInputIsLeftAlone() throws {
        var written = 0
        let changed = XMLEntitySanitizer.sanitize(try guideFixture("guide.xmltv").prefix(200), flushingEvery: 16) { written += $0.count }
        #expect(!changed)
        #expect(written == 0)
    }

    @Test func streamedParseMatchesWholeParse() throws {
        for document in [try guideFixture("guide.xmltv"), Self.messy] {
            let whole = try XMLTVParser().parse(document).programmes
            var streamed: [Programme] = []
            let stream = InputStream(data: XMLEntitySanitizer.sanitize(document))
            try XMLTVParser().parseSanitized(stream) { streamed.append($0) }
            #expect(streamed == whole)
            #expect(!streamed.isEmpty)
        }
    }

    @Test func streamedParseReportsWhereItStopped() {
        let stream = InputStream(data: Data("<tv>\n<programme channel=\"a\"".utf8))
        #expect(throws: XMLTVParser.XMLTVError.self) { try XMLTVParser().parseSanitized(stream) { _ in } }
    }
}
