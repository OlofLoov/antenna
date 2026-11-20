import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// Main-thread work the app's screens do over a provider-sized catalogue:
/// 50 000 channels in 400 groups. Benchmark, not CI-gated: run with
/// `TEST_RUNNER_ANTENNA_BENCHMARKS=1 xcodebuild test`. Each line prints the
/// median of five runs.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"))
struct AppBrowsingBenchmarkTests {
    static let source = UUID()
    static let raw = (0..<50_000).map { index in
        Channel(
            id: "\(index)", name: "Channel \(index)", streamURL: URL(filePath: "/\(index)"), group: "G\(index % 400)",
            epgID: "ch\(index % 1_000)", number: index + 1)
    }

    let container: ModelContainer

    init() throws {
        let schema = Schema(AntennaSchema.models)
        container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    private func median(_ body: () -> Void) -> Duration {
        let clock = ContinuousClock()
        let runs = (0..<5).map { _ in clock.measure(body) }.sorted()
        return runs[2]
    }

    private func loadedLive() async -> LiveModel {
        let channels = Self.raw
        let live = LiveModel(
            .init(
                engine: UITestingLive.Engine(log: nil), load: { _ in Playlist(channels: channels) }, hasLogin: { _ in true },
                guide: nil, programmes: UITestingLive.guide))
        live.sourcesChanged([SourceDescriptor(id: Self.source, name: "Home", kind: .m3u, url: URL(filePath: "/home.m3u"))])
        await live.settled()
        return live
    }

    @Test("guide-on-iphone-ipad-and-mac/filter-channels-by-typing the guide's rows for a typed filter")
    func guideFilter() async {
        let live = await loadedLive()
        let model = GuideBoardModel(store: GuideZoomStore(defaults: UserDefaults(suiteName: "benchmark") ?? .standard))
        let reading = GuideBoardReading(live: live, model: model)
        model.filter = "channel 12"
        let filtered = median { _ = reading.data(at: .now, filtered: true).rows.count }
        model.filter = ""
        let whole = median { _ = reading.data(at: .now, filtered: true).rows.count }
        print("benchmark guide data: filtered \(filtered), unfiltered \(whole)")
        live.filter = "channel 12"
        let liveFiltered = median { _ = live.rows.count }
        #expect(filtered < liveFiltered * 1.5, "about as fast as Live's list, which keeps its name index")
    }

    @Test("live-tv-on-iphone-ipad-mac/type-to-narrow-the-list Live's rows for a typed filter")
    func liveFilter() async {
        let live = await loadedLive()
        live.filter = "channel 12"
        let filtered = median { _ = live.rows.count }
        print("benchmark live rows: filtered \(filtered)")
    }

    @Test("live-tv-on-iphone-ipad-mac/watch-without-leaving-the-list loading a 50 000 channel source")
    func load() async {
        let clock = ContinuousClock()
        var runs: [Duration] = []
        for _ in 0..<5 {
            let start = clock.now
            _ = await loadedLive()
            runs.append(clock.now - start)
        }
        print("benchmark live load: \(runs.sorted()[2])")
    }

    @Test("new-channels/a-new-group-lists-channels-added-lately a 50 000 channel load holds the main actor under 150 ms at a time")
    func loadStall() async {
        let clock = ContinuousClock()
        var stalls: [Duration] = []
        for _ in 0..<5 {
            var done = false
            let ticker = Task { @MainActor in
                var longest = Duration.zero
                while !done {
                    let before = clock.now
                    await Task.yield()
                    longest = max(longest, clock.now - before)
                }
                return longest
            }
            _ = await loadedLive()
            done = true
            stalls.append(await ticker.value)
        }
        let stall = stalls.sorted()[2]
        print("benchmark live load longest main-actor stall: \(stall)")
        #expect(stall < .milliseconds(150))
    }

    @Test("search/find-things-the-way-you-type-them a settled query over 50 000 channels")
    func search() async {
        let live = await loadedLive()
        let model = SearchModel(.init(debounce: .zero, sleep: { _ in }, now: { .now }))
        await model.load(
            SearchCorpus(
                catalogue: live.catalogue, sourceOrder: [Self.source: 0], guide: GuideIndex(programmes: [:]), titles: [],
                hasTitles: false, sources: .loaded))
        let settle = median {
            model.run("channel 12")
            model.run("channel 1")
        }
        print("benchmark search settle (two queries): \(settle)")
    }
}
