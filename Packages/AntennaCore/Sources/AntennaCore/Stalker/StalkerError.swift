import Foundation

/// What a Stalker portal sign-in needs. The MAC, password and login come
/// from the source's Keychain item.
///
/// `description`, `debugDescription` and `dump` show the portal's host only.
public struct StalkerCredentials: Sendable, Hashable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var portal: StalkerPortal
    public var mac: MACAddress
    public var password: String
    /// Sent with `do_auth` when present. A nil login skips that step.
    public var login: String?

    public init(portal: StalkerPortal, mac: MACAddress, password: String, login: String? = nil) {
        self.portal = portal
        self.mac = mac
        self.password = password
        self.login = login?.isEmpty == true ? nil : login
    }

    public var description: String { portal.description }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: ["host": description]) }
}

/// Why a Stalker portal call failed
/// (stalker-portal-source/connect-says-why-it-failed). Values hold no
/// address, MAC, login, password, session key or response body.
public enum StalkerError: Error, Sendable, Equatable {
    /// The request failed before an answer arrived. Only the code is kept.
    /// `isOffline` tells a missing connection apart.
    case transport(URLError.Code)
    /// The portal answered with this 5xx, or another non-2xx status after
    /// sign-in.
    case serverError(status: Int)
    /// The portal turned down the device or its login, or turned down a
    /// renewed session.
    case notAuthorized
    /// The portal refused the device with a message of its own. Every
    /// spelling of the MAC, the login and the password read "…".
    case deviceRefused(message: String)
    /// No address the portal could be under answered as a portal.
    case noPortal
    /// The answer was not the JSON the call expects. Quotes nothing from it.
    case unreadable
    /// The channel is not a Stalker channel of this portal.
    case notStalkerChannel
    /// The portal's answer to a tune held no address to play.
    case noLink

    static let offlineCodes: Set<URLError.Code> = [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed]

    /// True for a transport failure that means no connection.
    public var isOffline: Bool {
        if case .transport(let code) = self { return Self.offlineCodes.contains(code) }
        return false
    }
}
