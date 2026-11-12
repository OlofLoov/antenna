import Foundation

/// How long the passcode prompt refuses input after wrong entries
/// (group-management/guessing-the-passcode-is-slow). Kept per device and
/// stored as JSON, so closing the app does not cut a wait short.
///
/// Five wrong entries in a row start a wait of 30 seconds; each further
/// run of five doubles it, up to five minutes. The right passcode resets it.
public struct PasscodeLockout: Codable, Hashable, Sendable {
    /// Wrong entries in a row before a wait.
    public static let runLength = 5
    public static let firstWait: TimeInterval = 30
    public static let longestWait: TimeInterval = 300

    /// Wrong entries since the last wait or the last right one.
    public private(set) var wrongInRun = 0
    /// Waits served since the last right entry.
    public private(set) var waits = 0
    /// When input is accepted again; nil when it is now.
    public private(set) var until: Date?

    public init() {}

    /// The lockout stored as `data`; a fresh one when `data` is nil or cannot be read.
    public init(data: Data?) {
        self = data.flatMap { try? JSONDecoder().decode(Self.self, from: $0) } ?? Self()
    }

    public var data: Data? { try? JSONEncoder().encode(self) }

    /// Seconds left before input is accepted, 0 when it is now.
    public func remaining(at now: Date) -> TimeInterval {
        guard let until else { return 0 }
        return max(0, until.timeIntervalSince(now))
    }

    /// A wrong entry at `now`. Ignored while a wait runs.
    public mutating func wrong(at now: Date) {
        guard remaining(at: now) == 0 else { return }
        wrongInRun += 1
        guard wrongInRun >= Self.runLength else { return }
        let wait = min(Self.longestWait, Self.firstWait * pow(2, Double(waits)))
        waits += 1
        wrongInRun = 0
        until = now.addingTimeInterval(wait)
    }

    /// The right passcode: no wait and no count.
    public mutating func right() {
        self = Self()
    }
}
