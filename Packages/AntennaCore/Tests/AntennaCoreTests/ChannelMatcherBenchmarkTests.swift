import Foundation
import Testing

@testable import AntennaCore

/// The change's budget for asking Siri for a channel: 50 000 channels answer
/// a query within 50 ms on the reference machine and 250 ms on CI. Run with
/// `ANTENNA_BENCHMARKS=1 swift test`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"))
struct ChannelMatcherBenchmarkTests {
    @Test("app-intents/ask-for-a-channel-by-name-or-number 50 000 channels within budget")
    func budget() {
        let words = ["Sport", "News", "Kids", "Film", "Música", "Arena", "World", "North", "Harbour", "Café"]
        let sources = (0..<5).map { _ in UUID() }
        let channels = sources.enumerated().flatMap { offset, source in
            Channel.tagged(
                (0..<10_000).map { index in
                    let number = offset * 10_000 + index + 1
                    return Channel(
                        id: "\(number)", name: "\(words[index % 10]) \(words[(index / 10) % 10]) \(number)",
                        streamURL: URL(filePath: "/\(number)"), group: words[(index / 100) % 10], number: number)
                }, sourceID: source)
        }
        let catalogue = Catalogue<Int>(channels: channels, groupOrder: [:], favorites: [])
        let matcher = ChannelMatcher(catalogue)
        let limit = ProcessInfo.processInfo.environment["CI"] == nil ? Duration.milliseconds(50) : .milliseconds(250)
        for query in ["sport", "cafe arena", "musica", "1234", "harbour north 4", "zzz"] {
            let elapsed = ContinuousClock().measure { _ = matcher.matches(query, limit: 20) }
            #expect(elapsed < limit, "\(query): \(elapsed)")
        }
    }
}
