import Foundation
import Synchronization

#if DEBUG
    /// Where posters go between loading ahead and showing, since launch,
    /// for the browsing benchmarks. Read by the large shelf's probe.
    enum PosterTrace {
        static let prefetchAsked = Atomic<Int>(0)
        static let prefetchStarted = Atomic<Int>(0)
        static let cancelledByRow = Atomic<Int>(0)
        static let cancelledByCard = Atomic<Int>(0)
        static let evicted = Atomic<Int>(0)
        static let evictedUnshown = Atomic<Int>(0)
        static let evictedUnshownAlong = Atomic<Int>(0)
        static let evictedUnshownRow = Atomic<Int>(0)
        static let startedAlong = Atomic<Int>(0)
        static let missCold = Atomic<Int>(0)
        static let missInFlight = Atomic<Int>(0)
        static let rowTriggers = Atomic<Int>(0)
        static let alongTriggers = Atomic<Int>(0)
        /// Gauges, as of the last prefetch or stop.
        static let loading = Atomic<Int>(0)
        static let groups = Atomic<Int>(0)
        static let wanted = Atomic<Int>(0)
        /// The row the Apple TV highlight is in and its position there.
        static let focusedRow = Mutex("")
        /// Time spent finding the highlight's position in its row, and how
        /// many times, on the main actor.
        static let lookupMicros = Atomic<Int>(0)
        static let lookups = Atomic<Int>(0)
        /// Moves between rows the focus engine landed off the column, so
        /// the follower moved the highlight a second time.
        static let corrections = Atomic<Int>(0)

        static func lookup(since start: ContinuousClock.Instant) {
            let elapsed = ContinuousClock.now - start
            let micros = elapsed.components.seconds * 1_000_000 + elapsed.components.attoseconds / 1_000_000_000_000
            lookupMicros.add(Int(micros), ordering: .relaxed)
            lookups.add(1, ordering: .relaxed)
        }

        static var line: String {
            func v(_ counter: borrowing Atomic<Int>) -> Int { counter.load(ordering: .relaxed) }
            let counts: [(String, Int)] = [
                ("ask", v(prefetchAsked)), ("start", v(prefetchStarted)), ("startAlong", v(startedAlong)),
                ("cxRow", v(cancelledByRow)), ("cxCard", v(cancelledByCard)), ("evict", v(evicted)),
                ("evictUnshown", v(evictedUnshown)), ("euAlong", v(evictedUnshownAlong)), ("euRow", v(evictedUnshownRow)),
                ("missCold", v(missCold)), ("missFlight", v(missInFlight)), ("rowTrig", v(rowTriggers)),
                ("alongTrig", v(alongTriggers)), ("loading", v(loading)), ("groups", v(groups)), ("wanted", v(wanted)),
                ("lookups", v(lookups)), ("lookupMicros", v(lookupMicros)), ("corrections", v(corrections)),
            ]
            return (counts.map { $0.0 + "=" + String($0.1) } + ["row=" + focusedRow.withLock { $0 }]).joined(separator: " ")
        }
    }
#endif
