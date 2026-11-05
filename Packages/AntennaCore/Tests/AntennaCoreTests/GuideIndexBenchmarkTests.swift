import Foundation
import Testing

@testable import AntennaCore

/// The guide's query and join budget. Benchmark, not CI-gated. Run with
/// `ANTENNA_BENCHMARKS=1 swift test`; the baseline machine is 0013's.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"))
struct GuideIndexBenchmarkTests {
    let source = UUID()

    private func seconds(_ body: () -> Void) -> Double {
        let clock = ContinuousClock()
        let elapsed = clock.measure(body)
        return Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
    }

    /// Half-hour programmes over seven days for `channels` ids.
    private func week(channels: Int) -> [Programme] {
        var result: [Programme] = []
        result.reserveCapacity(channels * 336)
        for channel in 0..<channels {
            for slot in 0..<336 {
                let start = guideTime(0, slot * 30)
                result.append(programme("ch\(channel)", start, start.addingTimeInterval(1800), "p"))
            }
        }
        return result
    }

    @Test func queries() throws {
        let index = GuideIndex(programmes: [source: week(channels: 2_000)])
        let keys = (0..<2_000).map { GuideKey(sourceID: source, epgID: "ch\($0)") }
        let now = guideTime(50, 10)
        let horizon = try #require(index.horizon)

        let current = seconds { for key in keys.prefix(50) { _ = index.current(for: key, at: now) } }
        let window = seconds { _ = index.programmes(for: Array(keys.prefix(42)), in: DateInterval(start: now, duration: 9000)) }
        let all = seconds { _ = index.programmes(for: keys, in: horizon) }

        #expect(current < 0.010)
        #expect(window < 0.010)
        #expect(all < 0.100)
    }

    @Test func join() {
        let programmes = (0..<500_000).map { offset in
            let start = guideTime(0, (offset / 20_000) * 30)
            return programme("ch\(offset % 20_000)", start, start.addingTimeInterval(1800), "p")
        }
        let channels = (0..<20_000).map {
            Channel(id: "\($0)", name: "\($0)", streamURL: URL(filePath: "/\($0)"), epgID: "ch\($0)", sourceID: source)
        }
        let elapsed = seconds { _ = SourceGuide(programmes).summary(channels: channels, now: guideTime(1)) }
        #expect(elapsed < 2)
    }
}
