import Foundation

/// A request the Apple TV plays when five seconds have passed since
/// `started`, unless the viewer or the sender cancels it first
/// (play-on-apple-tv/the-tv-counts-down-a-waiting-request). Once started it
/// plays even if the request expires during the five seconds.
public struct PlayCountdown: Sendable, Hashable, Identifiable {
    /// How long the countdown runs.
    public static let length: TimeInterval = 5

    public let request: PlayRequest
    public let started: Date

    public var id: UUID { request.id }

    public init(_ request: PlayRequest, started: Date) {
        self.request = request
        self.started = started
    }

    /// The whole seconds left at `now`, from 5 down to 0, as "Starts in 5" shows them.
    public func secondsLeft(at now: Date) -> Int {
        let left = Self.length - now.timeIntervalSince(started)
        return max(0, Int(left.rounded(.up)))
    }

    /// True once the five seconds are over and the request plays.
    public func isDue(at now: Date) -> Bool {
        now.timeIntervalSince(started) >= Self.length
    }
}
