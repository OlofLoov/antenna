import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// The store's time budgets. Benchmark, not CI-gated, like the guide's: run
/// with `TEST_RUNNER_ANTENNA_BENCHMARKS=1 xcodebuild test`. It prints the
/// three timings.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"))
struct ActivityStoreBenchmarkTests {
    let container: ModelContainer
    let source = UUID()
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        let schema = Schema(AntennaSchema.models)
        container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    private var context: ModelContext { container.mainContext }
    private var store: ActivityStore { ActivityStore(context: context) }

    private func insertProgress(_ range: Range<Int>) throws {
        for index in range {
            context.insert(
                ProgressRecord(
                    WatchProgress(
                        id: "", titleID: "xtream#host.tv#vod#\(index % 5_000)", sourceID: source, position: Double(index % 90),
                        duration: 100, updatedAt: start.addingTimeInterval(Double(index))),
                    profileID: nil))
        }
        try context.save()
    }

    @Test("watch-progress-sync/progress-is-saved-and-read-back resolving and reading stay inside their budgets")
    func budgets() throws {
        let clock = ContinuousClock()
        try insertProgress(0..<5_000)
        let rows = try context.fetch(FetchDescriptor<ProgressRecord>()).map(\.value)
        let resolve = clock.measure { _ = WatchProgress.resolve(rows) }
        let readAll = clock.measure { _ = store.allProgress() }
        try insertProgress(5_000..<20_000)
        let point = clock.measure { _ = store.progress(of: "xtream#host.tv#vod#42", source: source) }
        print("activity budgets: resolve \(resolve), all \(readAll), point \(point)")
        #expect(resolve < .milliseconds(500), "resolving 5 000 rows")
        #expect(readAll < .milliseconds(250), "reading all of 5 000 rows")
        #expect(point < .milliseconds(500), "a point read over 20 000 rows")
    }
}
