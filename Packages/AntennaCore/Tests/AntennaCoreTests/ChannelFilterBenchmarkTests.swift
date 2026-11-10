import AntennaCore
import Foundation
import Testing

/// The Live filter's budget: one keystroke over 20 000 channels in under
/// 50 ms in a debug build, once the names are indexed. Run with `ANTENNA_BENCHMARKS=1 swift test`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"))
struct ChannelFilterBenchmarkTests {
    @Test("live-tv-on-iphone-ipad-mac/type-to-narrow-the-list filtering 20 000 channels takes under 50 ms")
    func twentyThousand() {
        let words = ["Sport", "News", "Kids", "Film", "Música", "Arena", "World", "HD"]
        let channels = (0..<20_000).map { index in
            Channel(
                id: "\(index)", name: "\(words[index % words.count]) \(words[(index / 8) % words.count]) \(index)",
                streamURL: URL(filePath: "/\(index)"), group: "All", number: index + 1)
        }
        let catalogue = Catalogue<Int>(channels: Channel.tagged(channels, sourceID: UUID()), groupOrder: [:], favorites: [])
        let index = ChannelNameIndex(catalogue)
        let rows = catalogue.rows(in: .all)
        var slowest = Duration.zero
        for query in ["s", "sp", "spo", "spor", "sport", "sport m", "sport mu", "1", "12", "123"] {
            let elapsed = ContinuousClock().measure { _ = index.filter(rows, by: ChannelFilter(query)) }
            slowest = max(slowest, elapsed)
        }
        #expect(slowest < .milliseconds(50), "slowest keystroke took \(slowest)")
    }
}
