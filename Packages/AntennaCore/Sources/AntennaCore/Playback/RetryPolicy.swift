import Foundation

/// How often and how soon a stream is tried again.
public struct RetryPolicy: Sendable {
    /// The wait before each retry. Its count is the number of retries.
    public var delays: [Duration]
    /// Whether a failure is worth another try under this policy.
    public var retries: @Sendable (PlaybackFailure) -> Bool

    public init(delays: [Duration], retries: @escaping @Sendable (PlaybackFailure) -> Bool) {
        self.delays = delays
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
        while true {
            do {
                return try await attempt()
            } catch let failure as PlaybackFailure {
                guard retry < delays.count, retries(failure) else { throw failure }
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
    private var playingSince: ContinuousClock.Instant?

    public init(policy: RetryPolicy = .drop) {
        self.policy = policy
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
        guard policy.retries(failure), attempts < policy.delays.count else { return nil }
        attempts += 1
        return (attempts, policy.delays[attempts - 1])
    }
}
