import Foundation

/// Why a send over the home network did not get the TV's answer.
public enum PlaySendFailure: String, Sendable, Hashable, CaseIterable {
    /// Local network access is refused on this device.
    case accessRefused
    /// The browser did not find the TV on the network in time.
    case notFound
    /// The handshake failed: one end holds the other's key from before a restart.
    case refused
    /// The connection failed or dropped before the TV answered.
    case unreachable
    /// The request reached the TV and no answer came in time.
    case noAnswer
}

/// What the phone does after a failed send: try the network again after a
/// wait, or send through iCloud (play-on-apple-tv/starts-at-once-on-the-same-network).
/// The TV plays a request id once, so trying again never plays it twice.
public enum PlaySendRetry {
    /// Tries over the network, the first included.
    public static let attempts = 3

    /// The wait before try `attempt + 1` after `failure` on try `attempt`,
    /// counting from 1, or nil to send through iCloud. A refused handshake
    /// waits 1 s and then 2 s, so the TV has read the device list again; a
    /// dropped connection waits half a second. No TV, refused access and no
    /// answer go to iCloud at once.
    public static func delay(after failure: PlaySendFailure, attempt: Int) -> Duration? {
        guard attempt < attempts else { return nil }
        switch failure {
        case .refused: return .seconds(attempt)
        case .unreachable: return .milliseconds(500)
        case .accessRefused, .notFound, .noAnswer: return nil
        }
    }
}
