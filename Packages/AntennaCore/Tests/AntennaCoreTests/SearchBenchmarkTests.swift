import Darwin
import Foundation
import Testing

@testable import AntennaCore

/// Search's budgets from the change's design: 20 000 channels, seven days of
/// half-hour programmes for 2 000 of them and 10 000 titles index within
/// 1 500 ms, a query answers within 300 ms, and the index stays under 150 MB.
/// Debug build, not CI-gated. Run with `ANTENNA_BENCHMARKS=1 swift test`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"))
struct SearchBenchmarkTests {
    private static func footprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }

    @Test func budgets() {
        let source = UUID()
        let words = ["Sport", "News", "Kids", "Film", "Música", "Arena", "World", "North", "Harbour", "Café"]
        let channels = (0..<20_000).map { index in
            Channel(
                id: "\(index)", name: "\(words[index % 10]) \(words[(index / 10) % 10]) \(index)", streamURL: URL(filePath: "/\(index)"),
                group: words[(index / 100) % 10], epgID: index < 2_000 ? "ch\(index)" : nil, number: index + 1)
        }
        let catalogue = Catalogue<Int>(channels: Channel.tagged(channels, sourceID: source), groupOrder: [:], favorites: [])
        let start = Date(timeIntervalSince1970: 1_793_664_000)
        var programmes: [Programme] = []
        programmes.reserveCapacity(2_000 * 336)
        for channel in 0..<2_000 {
            for slot in 0..<336 {
                let begin = start.addingTimeInterval(Double(slot) * 1800)
                let title = "\(words[(channel + slot) % 10]) Show \((channel * 7 + slot) % 4_000)"
                programmes.append(
                    Programme(
                        channelID: "ch\(channel)", start: begin, stop: begin.addingTimeInterval(1800), title: title,
                        subtitle: "Episode \(slot % 40)"))
            }
        }
        let guide = GuideIndex(programmes: [source: programmes])
        programmes = []
        let titles = (0..<10_000).map { index in
            ShelfTitle(
                id: "xtream#h#vod#\(index)", kind: index.isMultiple(of: 3) ? .series : .movie, sourceID: source,
                name: "\(words[index % 10]) Story \(index)")
        }
        let now = start.addingTimeInterval(3600)

        let before = Self.footprint()
        var index = SearchIndex()
        let building = ContinuousClock().measure {
            index = SearchIndex(channels: SearchChannel.all(in: catalogue), guide: guide, titles: titles, now: now)
        }
        let grown = Self.footprint() - before

        var slowest = Duration.zero
        for typed in ["sp", "spo", "sport", "sport n", "north show", "cafe", "12", "1234", "episode 3", "zz"] {
            let elapsed = ContinuousClock().measure { _ = index.results(for: SearchQuery(typed), now: now) }
            slowest = max(slowest, elapsed)
        }
        print("search index \(building), slowest query \(slowest), \(grown / 1_048_576) MB")
        #expect(building < .milliseconds(1_500))
        #expect(slowest < .milliseconds(300))
        #expect(grown < 150 * 1_048_576)
    }
}
