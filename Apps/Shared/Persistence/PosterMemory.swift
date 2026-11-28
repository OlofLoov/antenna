import Foundation
import Synchronization

/// Decoded posters up to a limit in bytes, letting go of the least
/// recently shown first, so the posters on screen and those just loaded
/// ahead stay (movies-and-series-browsing/browsing-stays-responsive).
/// `NSCache` lets go in no set order. Safe from any thread, so a card can
/// look for its poster without waiting for the actor: the entries sit
/// behind a mutex, and the memory pressure source is set up once in
/// `init`. Empties itself when the system runs low on memory.
final class PosterMemory: @unchecked Sendable {
    private struct Entry {
        let poster: Poster
        var used: UInt64
        var shown = false
        var origin = ""
    }

    private struct State {
        var entries: [String: Entry] = [:]
        var cost = 0
        var clock: UInt64 = 0
    }

    private let state = Mutex(State())
    private let limit: Int
    private let pressure = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .global(qos: .utility))

    init(limit: Int) {
        self.limit = limit
        pressure.setEventHandler { [weak self] in self?.removeAll() }
        pressure.activate()
    }

    deinit {
        pressure.cancel()
    }

    func removeAll() {
        state.withLock { $0 = State() }
    }

    /// The bytes of the posters held, never more than the limit.
    var cost: Int { state.withLock { $0.cost } }
    var count: Int { state.withLock { $0.entries.count } }

    func object(forKey key: NSString, shown: Bool = true) -> Poster? {
        state.withLock { state in
            guard var entry = state.entries[key as String] else { return nil }
            state.clock += 1
            entry.used = state.clock
            entry.shown = entry.shown || shown
            state.entries[key as String] = entry
            return entry.poster
        }
    }

    func setObject(_ poster: Poster, forKey key: NSString, cost: Int, origin: String = "") {
        guard cost <= limit else { return }
        state.withLock { state in
            state.clock += 1
            if let old = state.entries[key as String] { state.cost -= old.poster.cost }
            state.entries[key as String] = Entry(poster: poster, used: state.clock, origin: origin)
            state.cost += cost
            while state.cost > limit, let oldest = state.entries.min(by: { $0.value.used < $1.value.used })?.key {
                let gone = state.entries.removeValue(forKey: oldest)
                state.cost -= gone?.poster.cost ?? 0
                #if DEBUG
                    PosterTrace.evicted.add(1, ordering: .relaxed)
                    if gone?.shown == false {
                        PosterTrace.evictedUnshown.add(1, ordering: .relaxed)
                        if gone?.origin == "along" { PosterTrace.evictedUnshownAlong.add(1, ordering: .relaxed) }
                        if gone?.origin == "below" { PosterTrace.evictedUnshownRow.add(1, ordering: .relaxed) }
                    }
                #endif
            }
        }
    }
}
