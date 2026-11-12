import Foundation

/// Why a Channels DVR call failed
/// (channels-dvr-source/connect-says-what-it-found). Values hold no
/// address, port, username, password or response body.
public enum ChannelsDVRError: Error, Sendable, Equatable {
    /// No connection on this device.
    case offline
    /// The host did not answer, could not be found, or timed out.
    case unreachable(URLError.Code)
    /// Any other failure before an answer arrived.
    case transport(URLError.Code)
    /// The address answered, but not as a Channels DVR server.
    case notAChannelsServer
    /// The server answered that it has not finished starting.
    case starting
    /// The server, or a proxy in front of it, asked for a username and password.
    case unauthorized
    /// The server answered with this status. -1 when the answer was not HTTP.
    case httpStatus(Int)
    /// The lineup was not a playlist.
    case malformed
    /// The source's Keychain item exists but cannot be read.
    case credentialUnreadable

    static let offlineCodes: Set<URLError.Code> = [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed]
    static let unreachableCodes: Set<URLError.Code> = [.cannotConnectToHost, .cannotFindHost, .timedOut, .dnsLookupFailed]

    init(code: URLError.Code) {
        if Self.offlineCodes.contains(code) {
            self = .offline
        } else if Self.unreachableCodes.contains(code) {
            self = .unreachable(code)
        } else {
            self = .transport(code)
        }
    }
}
