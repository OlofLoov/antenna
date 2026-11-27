import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import Antenna

/// How long an Xtream channel takes from asking to playing on the app's
/// engine, as HLS on Apple's player and as MPEG-TS on the demuxer, from the
/// in-test server: HLS in 2-second segments in a three-segment live window,
/// MPEG-TS sent at its own bit rate. Run with
/// `TEST_RUNNER_ANTENNA_BENCHMARKS=1 xcodebuild test`. It prints the medians
/// of 10 starts each. A local server leaves out the provider's network, so
/// only the gap between the two paths means anything.
@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"))
struct XtreamZapBenchmarkTests {
    @Test func hlsAndTransportStreamStartTimes() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        await server.alias("/live/u/p/5.m3u8", to: "hls/index.m3u8")
        await server.alias("/live/u/p/5.ts", to: "channel.ts")
        await server.always("/live/u/p/5.ts", .paced(bytesPerSecond: 262_017 / 8))
        let engine = RoutedEngine.app()
        var times: [String: [Duration]] = [:]
        for _ in 0..<10 {
            for name in ["5.m3u8", "5.ts"] {
                await engine.stop()
                let started = ContinuousClock.now
                try await engine.load(base.appending(path: "live/u/p/\(name)"), options: PlaybackOptions(isLive: true))
                await engine.play()
                #expect(await eventually(timeout: .seconds(20)) { await engine.state == .playing })
                times[name, default: []].append(ContinuousClock.now - started)
            }
        }
        for (name, values) in times.sorted(by: { $0.key < $1.key }) {
            print("XtreamZapBenchmark: \(name) median \(values.sorted()[values.count / 2])")
        }
        await engine.stop()
        await server.stop()
    }
}
