import Foundation

/// Timing budgets read the fastest of a few runs. Other work on a loaded CI
/// runner or laptop only ever adds time to a run, so the fastest one is the
/// closest to what the code costs, and a budget on it still fails a change
/// that makes every run slow.
enum FastestRun {
    static let runs = 3

    /// The fastest of `runs` timings of `body`.
    static func of(_ runs: Int = runs, _ body: () throws -> Void) rethrows -> Duration {
        let clock = ContinuousClock()
        var fastest = Duration.seconds(Int64.max)
        for _ in 0..<runs { fastest = min(fastest, try clock.measure(body)) }
        return fastest
    }

    /// The fastest of `runs` timings of `body`, for async work.
    static func of(_ runs: Int = runs, _ body: () async throws -> Void) async rethrows -> Duration {
        let clock = ContinuousClock()
        var fastest = Duration.seconds(Int64.max)
        for _ in 0..<runs {
            let started = clock.now
            try await body()
            fastest = min(fastest, started.duration(to: clock.now))
        }
        return fastest
    }
}
