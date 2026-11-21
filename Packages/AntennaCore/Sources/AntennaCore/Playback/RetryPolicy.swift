import Foundation

/// How often and how soon a stream is tried again.
public struct RetryPolicy: Sendable {
    /// The wait before each retry. Its count is the number of retries.
    public var delays: [Duration]
    /// Whether a failure is worth another try under this policy.
    public var retries: @Sendable (PlaybackFailure) -> Bool
    /// Failures `retries` turns down that get one more try all the same.
    public var retriesOnce: @Sendable (PlaybackFailure) -> Bool

    public init(
        delays: [Duration], retriesOnce: @escaping @Sendable (PlaybackFailure) -> Bool = { _ in false },
        retries: @escaping @Sendable (PlaybackFailure) -> Bool
    ) {
        self.delays = delays
        self.retriesOnce = retriesOnce
        self.retries = retries
    }

    /// A channel that will not start: 3 tries in all, 0.5 s and 1 s apart,
    /// for a busy server, a server error or a broken connection. Offline,
    /// login refusals, missing streams, unreadable streams and failed secure
    /// connections fail at once.
    public static let tune = RetryPolicy(delays: [.milliseconds(500), .seconds(1)]) { failure in
        switch failure {
        case .serverBusy, .serverError, .stoppedSendingData: true
        default: false
        }
    }

    /// A channel started within `switchWindow` of another channel from the
    /// same server closing. A provider that allows one connection can still
    /// hold the old one and refuse the new one, answer with an unusual code
    /// or not answer in time. Those get one more try a second later; the
    /// rest is as `tune`.
    public static let tuneAfterSwitch = RetryPolicy(
        delays: [.seconds(1), .seconds(1)],
        retriesOnce: { failure in
            switch failure {
            case .notAllowed, .timedOut: true
            case .refused(let status): (400..<500).contains(status)
            default: false
            }
        },
        retries: tune.retries)

    /// How soon after a close on the same server a start counts as a switch.
    public static let switchWindow = Duration.seconds(3)

    /// `tuneAfterSwitch` when a stream from `host` closed less than
    /// `switchWindow` before `now`, otherwise `tune`.
    public static func tune(
        host: String?, lastClosed: (host: String?, at: ContinuousClock.Instant)?, now: ContinuousClock.Instant = .now
    ) -> RetryPolicy {
        guard let lastClosed, lastClosed.host == host, now - lastClosed.at < switchWindow else { return tune }
        return tuneAfterSwitch
    }

    /// A channel that dropped after it played: 8 reconnects over about 45
    /// seconds. Everything a network or server can recover from is retried,
    /// offline included; refusals and unreadable streams are not.
    public static let drop = RetryPolicy(
        delays: [.milliseconds(500), .seconds(1), .seconds(2), .seconds(4), .seconds(8), .seconds(10), .seconds(10), .seconds(10)]
    ) { failure in
        switch failure {
        case .offline, .unreachable, .timedOut, .stoppedSendingData, .serverBusy, .serverError: true
        default: false
        }
    }

    /// This policy, with a busy server and server errors no longer retried
    /// when `final` is true. Multi-view sets it while another tile plays
    /// from the same source: a 503 or 509 there is the provider's stream
    /// limit, and trying again would loop (multi-view/a-tile-that-fails-says-why).
    public func refusals(final: Bool) -> RetryPolicy {
        guard final else { return self }
        let retries = self.retries
        return RetryPolicy(delays: delays, retriesOnce: retriesOnce) { failure in
            failure != .serverBusy && failure != .serverError && retries(failure)
        }
    }

    /// Steady play that resets the reconnect count.
    public static let steadyPlay = Duration.seconds(60)

    /// Waiting for data longer than this counts as a drop.
    public static let stallBudget = Duration.seconds(10)

    /// Runs `attempt` until it succeeds, fails with a reason this policy does
    /// not retry, or runs out of retries. Throws the last `PlaybackFailure`,
    /// or `CancellationError` when the task is cancelled during a wait.
    public func run<Value: Sendable>(
        sleep: @Sendable (Duration) async throws -> Void,
        _ attempt: @Sendable () async throws -> Value
    ) async throws -> Value {
        var retry = 0
        var triedOnce = false
        while true {
            do {
                return try await attempt()
            } catch let failure as PlaybackFailure {
                let again = retries(failure) || (!triedOnce && retriesOnce(failure))
                guard retry < delays.count, again else { throw failure }
                if !retries(failure) { triedOnce = true }
                try await sleep(delays[retry])
                try Task.checkCancellation()
                retry += 1
            }
        }
    }
}

/// Counts reconnects for one stream. The count starts over once the stream
/// has played for `RetryPolicy.steadyPlay` since it last started.
public struct ReconnectBudget: Sendable {
    public let policy: RetryPolicy
    /// Reconnects so far, 0 before the first.
    public private(set) var attempts = 0
    /// A busy server and server errors fail the stream at once, as
    /// `RetryPolicy.refusals(final:)` describes. It can change while the
    /// stream plays.
    public var refusalsAreFinal: Bool
    private var playingSince: ContinuousClock.Instant?

    public init(policy: RetryPolicy = .drop, refusalsAreFinal: Bool = false) {
        self.policy = policy
        self.refusalsAreFinal = refusalsAreFinal
    }

    public var maxAttempts: Int { policy.delays.count }

    /// Call each time the stream reaches playing.
    public mutating func playing(at now: ContinuousClock.Instant) {
        playingSince = now
    }

    /// Call when the stream drops with `failure`. Returns the attempt number
    /// and the wait before it, or nil when the stream should fail with
    /// `failure`: the reason is not retried or the attempts ran out.
    public mutating func dropped(_ failure: PlaybackFailure, at now: ContinuousClock.Instant) -> (attempt: Int, delay: Duration)? {
        if let since = playingSince, now - since >= RetryPolicy.steadyPlay { attempts = 0 }
        playingSince = nil
        guard policy.refusals(final: refusalsAreFinal).retries(failure), attempts < policy.delays.count else { return nil }
        attempts += 1
        return (attempts, policy.delays[attempts - 1])
    }
}
