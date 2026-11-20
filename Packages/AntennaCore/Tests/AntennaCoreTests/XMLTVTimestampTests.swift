import Foundation
import Testing

@testable import AntennaCore

/// `XMLTVParser.utcDate` computes common stamps itself and hands the rest to
/// the formatter. Both must agree on every input.
@Suite struct XMLTVTimestampTests {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyyMMddHHmmss"
        return f
    }()

    private static func formatted(_ s: String) -> Date? { formatter.date(from: String(s.prefix(14))) }

    @Test(
        "xmltv-guide-parsing/timestamp-without-zone-is-utc stamps read as the formatter reads them",
        arguments: [
            "20261103200000", "19000101000000", "19700101000000", "20000229235959", "20240229120000", "21000228000000",
            "99991231235959", "20261103200000 +0100", "20261103200000+0100", "20261103200000Z", "20261103200000\u{301}",
            "20261103200000é", "2026110320000", "", "2026XX03200000", "20261303200000", "20260003200000",
            "20261100200000", "20261131200000", "20230229000000", "19000229000000", "20261103240000", "20261103206000",
            "20261103200060", "18991231235959", "00010101000000", "２０２６1103200000", " 20261103200000",
            "-2026110320000",
        ])
    func matchesFormatter(stamp: String) {
        #expect(XMLTVParser.utcDate(stamp) == Self.formatted(stamp), "\(stamp)")
    }

    @Test(
        "xmltv-guide-parsing/timestamp-without-zone-is-utc a random stamp in each month from 1900 to 2100 reads as the formatter reads it"
    )
    func matchesFormatterAcrossYears() {
        var random = SystemRandomNumberGenerator()
        for year in stride(from: 1900, through: 2100, by: 1) {
            for month in 1...12 {
                let day = Int.random(in: 1...31, using: &random)
                let hour = Int.random(in: 0...23, using: &random)
                let minute = Int.random(in: 0...59, using: &random)
                let second = Int.random(in: 0...59, using: &random)
                let stamp = String(format: "%04d%02d%02d%02d%02d%02d", year, month, day, hour, minute, second)
                #expect(XMLTVParser.utcDate(stamp) == Self.formatted(stamp), "\(stamp)")
            }
        }
    }

    @Test(
        "xmltv-guide-parsing/large-documents-parse-in-bounded-time 100,000 stamps read within 100 ms",
        .enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"))
    func benchmark() {
        let stamps = (0..<100_000).map { String(format: "202611%02d%02d0000 +0100", $0 % 28 + 1, $0 % 24) }
        var read = 0
        let elapsed = FastestRun.of {
            read = 0
            for stamp in stamps where XMLTVParser.utcDate(stamp) != nil { read += 1 }
        }
        #expect(read == stamps.count)
        if Benchmarks.enabled { #expect(elapsed < .milliseconds(100), "100 000 stamps took \(elapsed)") }
    }
}
