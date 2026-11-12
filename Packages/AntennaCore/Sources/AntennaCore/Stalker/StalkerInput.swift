import Foundation

/// A MAC address as a provider registers it with a Stalker portal.
///
/// `description`, `debugDescription` and `dump` show "…", so the value can
/// be interpolated into a log line without showing the MAC.
public struct MACAddress: Sendable, Hashable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    /// Uppercase with colons, such as `00:1A:79:12:34:56`. This is the form
    /// the portal, the cookie and the device identity use.
    public let text: String

    /// Accepts colons, dashes or twelve plain hex digits, in either case,
    /// with spaces around it. Nil for any other count of hex digits, a
    /// non-hex character, or separators in the wrong places
    /// (stalker-portal-source/type-the-mac-and-portal-address-the-way-your-provider-wrote-them).
    public init?(_ typed: String) {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let hexDigits = Set("0123456789ABCDEF")
        let digits: String
        if trimmed.count == 12 {
            digits = trimmed
        } else if trimmed.count == 17 {
            let separator = Array(trimmed)[2]
            guard separator == ":" || separator == "-" else { return nil }
            let parts = trimmed.split(separator: separator, omittingEmptySubsequences: false)
            guard parts.count == 6, parts.allSatisfy({ $0.count == 2 }) else { return nil }
            digits = parts.joined()
        } else {
            return nil
        }
        guard digits.count == 12, digits.allSatisfy(hexDigits.contains) else { return nil }
        let pairs = stride(from: 0, to: 12, by: 2).map { offset in
            let start = digits.index(digits.startIndex, offsetBy: offset)
            return String(digits[start..<digits.index(start, offsetBy: 2)])
        }
        text = pairs.joined(separator: ":")
    }

    /// The MAC as the `mac` cookie carries it, `:` written `%3A`.
    var cookieValue: String { text.replacingOccurrences(of: ":", with: "%3A") }

    /// Every way the MAC may be written in a portal message, longest first,
    /// for redaction.
    var spellings: [String] {
        let bare = text.replacingOccurrences(of: ":", with: "")
        let forms = [text, cookieValue, text.replacingOccurrences(of: ":", with: "-"), bare]
        return forms + forms.map { $0.lowercased() } + [text.replacingOccurrences(of: ":", with: "%3a")]
    }

    public var description: String { "…" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: []) }
}

/// A Stalker portal's address, tidied to the form every request starts from.
///
/// `description` is the host only, so the port and path, which can name the
/// provider's account, stay out of logs.
public struct StalkerPortal: Sendable, Hashable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    /// Scheme and host lowercased, port and path kept, a trailing `/c`,
    /// `/c/` and slash dropped, no query, fragment or user info.
    public let url: URL
    /// The lowercased host, without brackets for an IPv6 address.
    public let host: String

    /// Nil for an address without `http` or `https`, or without a host. A
    /// string without a scheme is rejected, not taken as `http`.
    public init?(_ typed: String) {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
            let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https",
            let host = components.host?.lowercased(), !host.isEmpty
        else { return nil }
        var path = components.percentEncodedPath
        while path.hasSuffix("/") { path.removeLast() }
        if path.hasSuffix("/c") { path.removeLast(2) }
        while path.hasSuffix("/") { path.removeLast() }
        var tidy = URLComponents()
        tidy.scheme = scheme
        tidy.percentEncodedHost = components.percentEncodedHost?.lowercased()
        tidy.port = components.port
        tidy.percentEncodedPath = path
        guard let url = tidy.url else { return nil }
        self.url = url
        self.host = host
    }

    public var description: String { host }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: ["host": host]) }
}
