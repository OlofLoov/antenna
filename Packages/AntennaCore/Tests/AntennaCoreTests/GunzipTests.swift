import Foundation
import Testing

@testable import AntennaCore

@Suite struct GunzipTests {
    /// A deterministic generator, so a failure repeats.
    private struct Generator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state
        }
    }

    /// Guide-like text with varied words, so the codes run long and short.
    private static func guideText(programmes: Int, seed: UInt64) -> Data {
        var generator = Generator(state: seed)
        let letters = Array("abcdefghijklmnopqrstuvwxyzåäö &<>\"'")
        func pick<T>(_ items: [T]) -> T { items[Int.random(in: 0..<items.count, using: &generator)] }
        let words = (0..<3_000).map { _ in String((0..<Int.random(in: 2...11, using: &generator)).map { _ in pick(letters) }) }
        var text = "<?xml version=\"1.0\"?>\n<tv>\n"
        for index in 0..<programmes {
            let summary = (0..<Int.random(in: 10...40, using: &generator)).map { _ in pick(words) }
            text += "<programme channel=\"c\(index % 300)\" start=\"2026110\(index % 10)120000 +0100\">"
            text += "<title>\(words[index % words.count])</title><desc>\(summary.joined(separator: " "))</desc></programme>\n"
        }
        return Data(text.utf8)
    }

    private static func unpack(_ packed: Data, limit: Int64 = .max) throws(Gunzip.Failure) -> [Data] {
        let pieces = Recorder<Data>()
        try Gunzip.unpack(packed, limit: limit) { pieces.append($0) }
        return pieces.all
    }

    @Test("guide-data/compressed-guides varied text unpacks byte for byte in 64 KiB pieces", arguments: [1, 6, 9])
    func variedText(level: Int) throws {
        let body = Self.guideText(programmes: 3_000, seed: UInt64(level))
        let pieces = try Self.unpack(try gzip(body, level: level))
        #expect(pieces.reduce(Data(), +) == body)
        #expect(pieces.dropLast().allSatisfy { $0.count == 65_536 })
    }

    @Test("guide-data/compressed-guides a cut-short gzip body fails as malformed")
    func truncated() throws {
        let body = Self.guideText(programmes: 400, seed: 7)
        let packed = try gzip(body)
        // The last 8 bytes are the CRC and length trailer, which are not read.
        for end in stride(from: 10, to: packed.count - 8, by: 97) {
            #expect(throws: Gunzip.Failure.malformed) { _ = try Self.unpack(packed.prefix(end)) }
        }
        #expect(try Self.unpack(packed.prefix(packed.count - 8)).reduce(Data(), +) == body)
    }

    @Test("guide-data/compressed-guides a damaged gzip body fails or unpacks without trapping")
    func damaged() throws {
        let packed = try gzip(Self.guideText(programmes: 200, seed: 8))
        var generator = Generator(state: 9)
        for _ in 0..<300 {
            var copy = packed
            let index = Int.random(in: 10..<copy.count, using: &generator)
            copy[index] ^= UInt8.random(in: 1...255, using: &generator)
            _ = try? Self.unpack(copy)
        }
    }

    @Test(
        "guide-data/compressed-guides 20 MB of varied guide text unpacks within 200 ms",
        .enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"))
    func benchmark() throws {
        let body = Self.guideText(programmes: 60_000, seed: 10)
        let packed = try gzip(body, level: 6)
        var size = 0
        let elapsed = try FastestRun.of {
            size = 0
            try Gunzip.unpack(packed, limit: .max) { size += $0.count }
        }
        #expect(size == body.count)
        if Benchmarks.enabled { #expect(elapsed < .milliseconds(200), "\(body.count / 1_000_000) MB took \(elapsed)") }
    }
}
