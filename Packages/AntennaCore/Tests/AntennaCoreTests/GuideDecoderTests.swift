import Foundation
import Testing

@testable import AntennaCore

/// Compresses `data` with the system `gzip` at `level`.
func gzip(_ data: Data, level: Int = 9) throws -> Data {
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/gzip")
    process.arguments = ["-c", "-\(level)"]
    let input = Pipe()
    let output = Pipe()
    process.standardInput = input
    process.standardOutput = output
    try process.run()
    let writer = Thread {
        input.fileHandleForWriting.write(data)
        try? input.fileHandleForWriting.close()
    }
    writer.start()
    let result = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return result
}

/// Collects whatever a test is handed, from any thread.
final class Recorder<Element: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Element] = []
    func append(_ element: Element) { lock.withLock { stored.append(element) } }
    var all: [Element] { lock.withLock { stored } }
}

@Suite struct GuideDecoderTests {
    private func decode(_ body: Data, chunkSize: Int = 1000) throws -> SourceGuide {
        let decoder = try GuideDecoder(limits: .platform, expectedLength: nil, directory: temporaryGuideDirectory(), sourceID: UUID())
        for start in stride(from: 0, to: body.count, by: chunkSize) {
            try decoder.append(body.subdata(in: start..<min(body.count, start + chunkSize)))
        }
        return try decoder.finish()
    }

    private func titles(_ guide: SourceGuide) -> [String: [String]] {
        guide.programmes.mapValues { $0.map(\.title) }
    }

    @Test("guide-data/compressed-guides gzip gives the same programmes")
    func gzipMatchesPlain() throws {
        let plain = try decode(try guideFixture("guide.xmltv"))
        let packed = try decode(try guideFixture("guide.xmltv.gz"), chunkSize: 7)
        #expect(plain.count == 6)
        #expect(packed.programmes == plain.programmes)
        #expect(titles(packed)["news.se"] == ["Evening News", "Debate", "Film \u{A0}Night"])
    }

    @Test(
        "guide-data/compressed-guides gzip at every level and with stored blocks unpacks byte for byte",
        arguments: [1, 6, 9])
    func gunzipLevels(level: Int) throws {
        var random = SystemRandomNumberGenerator()
        var body = Data("<tv>".utf8)
        for index in 0..<4000 {
            body += Data("<programme channel=\"c\(index % 37)\"><title>Show \(index * 7919 % 1000)</title></programme>\n".utf8)
        }
        body += Data((0..<70_000).map { _ in UInt8.random(in: 0...255, using: &random) })
        let packed = try gzip(body, level: level)
        let unpacked = Recorder<Data>()
        try Gunzip.unpack(packed, limit: .max) { unpacked.append($0) }
        #expect(unpacked.all.reduce(Data(), +) == body)
    }

    @Test("guide-data/compressed-guides a short body in one fixed-code block unpacks")
    func fixedBlock() throws {
        let body = Data("<tv/>".utf8)
        let packed = try gzip(body)
        let unpacked = Recorder<Data>()
        try Gunzip.unpack(packed, limit: .max) { unpacked.append($0) }
        #expect(unpacked.all.reduce(Data(), +) == body)
    }

    @Test("guide-data/failures-say-why gunzip stops at the block that crosses the limit")
    func gunzipLimit() throws {
        let bomb = try gzip(Data(repeating: 0x20, count: 1_000_000))
        let written = Recorder<Int>()
        #expect(throws: Gunzip.Failure.tooLarge) {
            try Gunzip.unpack(bomb, limit: 100_000) { written.append($0.count) }
        }
        #expect(written.all.reduce(0, +) <= 100_000)
    }

    @Test("guide-data/compressed-guides a clean document after leading whitespace parses")
    func cleanAfterWhitespace() throws {
        let clean = GuideFetcherTests.xml(programmes: 30)
        #expect(!clean.contains(UInt8(ascii: "&")))
        #expect(try decode(Data("\n\n  ".utf8) + clean).count == 30)
    }

    @Test("guide-data/compressed-guides hundreds of newlines before XML are skipped")
    func longWhitespace() throws {
        let body = Data(String(repeating: "\n", count: 800).utf8) + (try guideFixture("guide.xmltv"))
        #expect(try decode(body, chunkSize: 100).count == 6)
        #expect(try decode(try gzip(body)).count == 6)
    }

    @Test("guide-data/compressed-guides a byte order mark and whitespace before XML are accepted")
    func byteOrderMark() throws {
        let body = Data([0xef, 0xbb, 0xbf]) + Data(" \n\t".utf8) + (try guideFixture("guide.xmltv"))
        #expect(try decode(body, chunkSize: 2).count == 6)
    }

    @Test(
        "guide-data/compressed-guides neither XML nor gzip is unsupported",
        arguments: [
            Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
            Data("{\"user_info\":{\"auth\":0}}".utf8),
            Data([0xef, 0xbb, 0x00]),
            Data([0x1f, 0x00, 0x00]),
        ])
    func unsupported(body: Data) throws {
        #expect(throws: GuideError.unsupportedEncoding) { try decode(body, chunkSize: 1) }
    }

    @Test("guide-data/compressed-guides gzip inside gzip is unsupported")
    func nestedGzip() throws {
        let twice = try gzip(try guideFixture("guide.xmltv.gz"))
        #expect(throws: GuideError.unsupportedEncoding) { try decode(twice) }
    }

    @Test("guide-data/compressed-guides sniffing waits for enough bytes")
    func sniffing() {
        #expect(GuideDecoder.sniff([]) == nil)
        #expect(GuideDecoder.sniff([0x1f]) == nil)
        #expect(GuideDecoder.sniff([0xef, 0xbb]) == nil)
        #expect(GuideDecoder.sniff(Array("  \n".utf8)) == nil)
        #expect(GuideDecoder.sniff([0x1f, 0x8b]) == .some(.gzip))
        #expect(GuideDecoder.sniff(Array("\n<".utf8)) == .some(.xml))
    }
}
