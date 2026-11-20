import Foundation
import Testing

@testable import AntennaCore

/// The Live filter's budgets over 50 000 channels, in CPU time on a debug
/// build, with room for a slow CI runner: building the name index, which
/// happens off the main actor, and each keystroke, which runs on it. A
/// release build on an M-series Mac takes about 1 ms a keystroke and 33 ms
/// to build.
@Suite struct ChannelFilterBenchmarkTests {
    static let words = ["Sport", "News", "Kids", "Film", "Música", "Arena", "World", "North", "Harbour", "Café"]

    static let catalogue: Catalogue<Int> = {
        let channels = (0..<50_000).map { index in
            Channel(
                id: "\(index)", name: "\(words[index % 10]) \(words[(index / 10) % 10]) \(index)", streamURL: URL(filePath: "/\(index)"),
                group: "G\(index % 400)", number: index + 1)
        }
        return Catalogue<Int>(channels: Channel.tagged(channels, sourceID: UUID()), groupOrder: [:], favorites: [])
    }()

    /// CPU time of one run of `body` on this thread.
    private static func cpu(_ body: () -> Void) -> Duration {
        let started = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
        body()
        return .nanoseconds(Int64(clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID) - started))
    }

    @Test("live-tv-on-iphone-ipad-mac/type-to-narrow-the-list each keystroke over 50 000 channels stays under 250 ms in a debug build")
    func typing() {
        let index = ChannelNameIndex(Self.catalogue)
        let all = Self.catalogue.rows(in: .all)
        var times: [String: Duration] = [:]
        for typed in ["s", "sp", "spo", "spor", "sport", "sport m", "sport mu", "sport m", "sport", "1", "12", "123", "harbour 4"] {
            times[typed] = Self.cpu { _ = index.filter(all, by: ChannelFilter(typed)) }
        }
        let group = Self.catalogue.rows(in: .named(all[0].sourceID, "G7"))
        times["group"] = Self.cpu { _ = index.filter(group, by: ChannelFilter("sport")) }
        let slowest = times.values.max() ?? .zero
        print("benchmark live filter keystrokes: slowest \(slowest), \(times.sorted { $0.key < $1.key })")
        #expect(slowest < .milliseconds(250), "slowest keystroke took \(slowest)")
    }

    @Test("live-tv-on-iphone-ipad-mac/type-to-narrow-the-list a letter added to the filter costs less than the first one")
    func typingOn() {
        let index = ChannelNameIndex(Self.catalogue)
        let all = Self.catalogue.rows(in: .all)
        let first = FastestRun.of {
            _ = index.filter(all, by: ChannelFilter("harbour"))
            _ = index.filter(all, by: ChannelFilter("1"))
        }
        let onward = FastestRun.of {
            _ = index.filter(all, by: ChannelFilter("1"))
            _ = index.filter(all, by: ChannelFilter("12"))
        }
        print("benchmark live filter: fresh word \(first), one letter on \(onward)")
        #expect(onward < first, "typing on tests only the rows the last keystroke kept")
    }

    @Test("live-tv-on-iphone-ipad-mac/type-to-narrow-the-list building the name index for 50 000 channels stays under 900 ms")
    func building() {
        let built = FastestRun.of { _ = ChannelNameIndex(Self.catalogue) }
        print("benchmark live name index: \(built)")
        #expect(built < .milliseconds(900))
    }
}
