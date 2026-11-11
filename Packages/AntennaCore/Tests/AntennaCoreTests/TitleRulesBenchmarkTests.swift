import AntennaCore
import Foundation
import Testing

/// Season grouping and the play target each stay under 50 ms for 5 000
/// episodes in 40 seasons with 1 000 saved positions, in a debug build.
/// Run with `ANTENNA_BENCHMARKS=1 swift test`; the baseline machine is the
/// Xtream client's (Apple M1, 16 GB).
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"))
struct TitleRulesBenchmarkTests {
    private let episodes = (0..<5_000).map { index in
        Episode(id: "e\(index)", episodeID: index, season: index % 40 + 1, number: index / 40 + 1, title: "Episode", duration: 2_400)
    }

    private var progress: [String: WatchProgress] {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let source = UUID()
        return Dictionary(
            uniqueKeysWithValues: (0..<1_000).map { index in
                let id = "e\(index * 5)"
                let position = index.isMultiple(of: 3) ? 1_200.0 : 2_390
                let record = WatchProgress(
                    id: id, titleID: id, seriesID: "s", sourceID: source, position: position, duration: 2_400,
                    updatedAt: now.addingTimeInterval(Double(index)))
                return (id, record)
            })
    }

    // title-detail-and-episode-picker/pick-a-season
    @Test("grouping 5 000 episodes in 40 seasons takes under 50 ms")
    func grouping() {
        var groups: [SeasonGroup] = []
        let elapsed = ContinuousClock().measure { groups = SeasonGroup.group(episodes) }
        #expect(groups.count == 40)
        #expect(elapsed < .milliseconds(50), "took \(elapsed)")
    }

    // title-detail-and-episode-picker/play-starts-the-right-episode
    @Test("the play target over 5 000 episodes and 1 000 positions takes under 50 ms")
    func playTarget() {
        let saved = progress
        var target: SeriesPlayTarget?
        let elapsed = ContinuousClock().measure { target = SeriesPlayTarget.resolve(episodes: episodes, progress: saved) }
        #expect(target != nil)
        #expect(elapsed < .milliseconds(50), "took \(elapsed)")
    }
}
