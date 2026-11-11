import Foundation

/// Why Connect did not save a source, with the sentence the form shows
/// under its fields (first-run-onboarding/a-failed-connection-says-why-and-saves-nothing).
/// Values carry no link, username or password, only a host name.
public enum ConnectFailure: Error, Equatable, Sendable {
    /// A required field is empty. Checked in form order, before any request.
    case missingField(SourceField)
    /// The link has no scheme, the `source-management` validation rule.
    case invalidURL
    /// The server refused the username and password.
    case rejected
    /// The account exists but its status is not active, such as "Expired".
    case inactive(status: String)
    case offline
    /// The request failed before an answer arrived.
    case unreachable(host: String)
    /// The server answered with a status outside 200 to 299.
    case serverError(status: Int)
    /// The reply did not decode.
    case unreadable
    /// The Keychain refused the password; the raw status follows the message.
    case credentials(String)

    /// The sentence shown under the form.
    public var message: String {
        switch self {
        case .missingField(let field): "Enter the \(field.spokenName)."
        case .invalidURL: "Enter a valid URL."
        case .rejected: "Could not sign in. Check the username and password."
        case .inactive(let status): "This account is \(status.lowercased())."
        case .offline: "You're offline. Connect to the internet and try again."
        case .unreachable(let host): "Could not reach \(host). Check the address and try again."
        case .serverError(let status): "The server answered with an error (\(status)). Check the address and try again."
        case .unreadable: "The server replied with something Antenna could not read."
        case .credentials(let reason): "Could not store credentials: \(reason)"
        }
    }

    static let offlineCodes: Set<URLError.Code> = [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed]

    /// Maps what a connection attempt threw. `host` names the server in the
    /// unreachable message. Anything unexpected reads as unreachable.
    public init(_ error: any Error, host: String) {
        switch error {
        case let failure as ConnectFailure:
            self = failure
        case let xtream as XtreamClient.XtreamError:
            switch xtream {
            case .unauthorized: self = .rejected
            case .badStatus(let status): self = .serverError(status: status)
            case .decoding: self = .unreadable
            case .transport(let code): self = Self(code: code, host: host)
            }
        case let urlError as URLError:
            self = Self(code: urlError.code, host: host)
        case is DecodingError:
            self = .unreadable
        default:
            self = .unreachable(host: host)
        }
    }

    private init(code: URLError.Code, host: String) {
        self = Self.offlineCodes.contains(code) ? .offline : .unreachable(host: host)
    }

    /// Nil when `status`, the Xtream `user_info.status`, counts as active:
    /// absent, empty or "Active" in any case.
    public static func accountStatus(_ status: String?) -> ConnectFailure? {
        guard let status = status?.trimmingCharacters(in: .whitespaces), !status.isEmpty,
            status.caseInsensitiveCompare("Active") != .orderedSame
        else { return nil }
        return .inactive(status: status)
    }
}

/// A required field of the add-source form.
public enum SourceField: String, Sendable, CaseIterable {
    case server, username, password, playlist

    /// How the "Enter the …" message names it.
    public var spokenName: String {
        switch self {
        case .server: "server address"
        case .username: "username"
        case .password: "password"
        case .playlist: "playlist URL"
        }
    }
}
