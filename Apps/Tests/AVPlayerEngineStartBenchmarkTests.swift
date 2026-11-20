import AVFoundation
import AntennaCore
import AntennaTestSupport
import Foundation
import Synchronization
import Testing

@testable import Antenna

/// How soon `load` on Apple's player engine returns once the player item is
/// ready, for an HLS channel on the in-test server. Run with
/// `TEST_RUNNER_ANTENNA_BENCHMARKS=1 xcodebuild test`. It prints the medians
/// of 15 loads.
@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"))
struct AVPlayerEngineStartBenchmarkTests {
    @Test func loadReturnsSoonAfterTheItemIsReady() async throws {
        let harness = try await PlayerHarness()
        let readyAt = Mutex<ContinuousClock.Instant?>(nil)
        let watch = harness.engine.player.observe(\.currentItem?.status, options: [.new]) { player, _ in
            guard player.currentItem?.status == .readyToPlay else { return }
            readyAt.withLock { $0 = $0 ?? .now }
        }
        var loads: [Duration] = []
        var lags: [Duration] = []
        for _ in 0..<15 {
            await harness.engine.stop()
            readyAt.withLock { $0 = nil }
            let started = ContinuousClock.now
            try await harness.engine.load(harness.url("hls/index.m3u8"), options: PlaybackOptions())
            let loaded = ContinuousClock.now
            loads.append(loaded - started)
            if let ready = readyAt.withLock({ $0 }) { lags.append(loaded - ready) }
        }
        watch.invalidate()
        let load = loads.sorted()[loads.count / 2]
        let lag = try #require(lags.sorted().dropFirst(lags.count / 2).first)
        print("AVPlayerEngine: HLS load median \(load), returned \(lag) after the item was ready")
        #expect(lag < .milliseconds(15))
        await harness.stop()
    }
}
