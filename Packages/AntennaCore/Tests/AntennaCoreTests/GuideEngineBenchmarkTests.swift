import Darwin
import Foundation
import Testing

@testable import AntennaCore

/// A memory figure for the guide engine. Benchmark, not CI-gated. Run with
/// `ANTENNA_BENCHMARKS=1 swift test`. The 5 ms budget for
/// `update(channels:)` holds by construction: it only yields to an inbox.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"))
struct GuideEngineBenchmarkTests {
    /// The process's physical footprint, the figure jetsam compares to its limit.
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

    /// Loads a 96 MB guide with stray `&`, so the entity sanitizer copies it,
    /// twice through one engine, so the first guide is held during the second
    /// load. Prints the peak footprint above the baseline. Not a device figure.
    @Test func memoryForTheTVOSLimit() async throws {
        var text = "<tv>\n"
        var index = 0
        while text.utf8.count < 96_000_000 - 400 {
            let start = guideTime(0, (index / 2_000) * 30)
            let stamp = { (date: Date) in
                let parts = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "UTC")!, from: date)
                return String(format: "%04d%02d%02d%02d%02d00 +0000", parts.year!, parts.month!, parts.day!, parts.hour!, parts.minute!)
            }
            text += "<programme start=\"\(stamp(start))\" stop=\"\(stamp(start.addingTimeInterval(1800)))\" channel=\"ch\(index % 2_000)\">"
            text += "<title>News & Weather \(index)</title><desc>Headlines & sport for the region</desc></programme>\n"
            index += 1
        }
        text += "</tv>\n"
        let body = Data(text.utf8)
        text = ""

        let world = GuideWorld()
        let source = world.add(host: "bench-memory.epg")
        GuideStubProtocol.register(host: "bench-memory.epg", body: body, chunkSize: 1_000_000)
        let engine = world.engine(limits: GuideLimits(compressedBytes: 32_000_000, unpackedBytes: 96_000_000))
        let tap = ProgressTap(engine.progressStream())
        let baseline = Self.footprint()
        let peak = Recorder<UInt64>()
        let sampler = Task.detached {
            while !Task.isCancelled {
                peak.append(Self.footprint())
                try? await Task.sleep(for: .milliseconds(20))
            }
        }
        for _ in 0..<2 {
            await engine.refresh(sourceID: source.sourceID)
            await engine.idle()
        }
        sampler.cancel()
        #expect(!tap.events.all.contains(where: isFailed))
        #expect(tap.of(source).filter(isLoaded).count == 2)
        let above = (peak.all.max() ?? baseline) - baseline
        print("guide memory: \(body.count / 1_000_000) MB guide, \(index) programmes, peak \(above / 1_000_000) MB above baseline")
    }
}
