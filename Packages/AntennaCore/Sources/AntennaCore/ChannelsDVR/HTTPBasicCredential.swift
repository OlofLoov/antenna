import Foundation

/// A username and password sent as `Authorization: Basic`, for a reverse
/// proxy in front of a Channels DVR server.
///
/// `description`, `debugDescription` and `dump` show the type name only, so
/// neither part nor their encoded form reaches a log
/// (channels-dvr-source/passwords-never-show-up-in-messages-or-logs).
public struct HTTPBasicCredential: Sendable, Hashable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public let username: String
    public let password: String

    /// Nil for an empty username or one with a colon, which Basic
    /// authentication cannot carry. A colon in the password is kept
    /// (channels-dvr-source/reach-a-remote-server-behind-a-password).
    public init?(username: String, password: String) {
        guard !username.isEmpty, !username.contains(":") else { return nil }
        self.username = username
        self.password = password
    }

    /// `Basic ` and the Base64 of the UTF-8 `username:password`.
    public var headerValue: String {
        "Basic " + Data("\(username):\(password)".utf8).base64EncodedString()
    }

    public var description: String { "HTTPBasicCredential" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: []) }
}
