import Foundation

/// One login found in a file's links: a username and password on one host
/// and port. Lives only in the Keychain.
public struct StreamCredential: Codable, Equatable, Hashable, Sendable {
    /// The host, with its port when the link names one.
    public var host: String
    public var username: String
    public var password: String

    public init(host: String, username: String, password: String) {
        self.host = host
        self.username = username
        self.password = password
    }
}

extension PlaylistImport {
    /// A file's text with every login in its links replaced by a placeholder.
    public struct Stripped: Equatable, Sendable {
        public var text: String
        /// One entry per distinct host, username and password, in first-seen order.
        public var credentials: [StreamCredential]
    }

    public enum LoginError: Error, Equatable {
        /// The text names a login the Keychain item does not hold.
        case missingCredential(index: Int)
    }

    /// Replaces each login in a link with `{antenna.<token>.user.N}` and
    /// `{antenna.<token>.pass.N}`. Three forms are matched: `username=` and
    /// `password=` in the query, `/live|movie|series/<user>/<pass>/<id>.<ext>`
    /// as the whole path, and `user:pass@host`. `restoreCredentials` with the
    /// same token gives back `text` byte for byte.
    public static func stripCredentials(_ text: String, token: String) -> Stripped {
        var stripper = LoginStripper(token: Array(token.utf8))
        let bytes = Array(text.utf8)
        var output: [UInt8] = []
        output.reserveCapacity(bytes.count)
        var index = 0
        while index < bytes.count {
            if let schemeEnd = LoginStripper.schemeEnd(bytes, at: index) {
                var end = schemeEnd
                while end < bytes.count, !LoginStripper.endsLink(bytes[end]) { end += 1 }
                output += stripper.strip(bytes[index..<end], schemeEnd: schemeEnd)
                index = end
            } else {
                output.append(bytes[index])
                index += 1
            }
        }
        return Stripped(text: String(decoding: output, as: UTF8.self), credentials: stripper.credentials)
    }

    /// Puts the logins `stripCredentials` took out back in. Text that only
    /// looks like a placeholder, without `token`, is left alone. Throws when
    /// a placeholder names a login `credentials` does not hold.
    public static func restoreCredentials(_ text: String, credentials: [StreamCredential], token: String) throws(LoginError) -> String {
        let prefix = Array("{antenna.\(token).".utf8)
        let bytes = Array(text.utf8)
        var output: [UInt8] = []
        output.reserveCapacity(bytes.count)
        var index = 0
        while index < bytes.count {
            let found = bytes[index] == UInt8(ascii: "{") && bytes[index...].starts(with: prefix)
            if found, let match = placeholder(bytes, after: index + prefix.count) {
                guard credentials.indices.contains(match.number) else { throw .missingCredential(index: match.number) }
                let login = credentials[match.number]
                output += Array((match.field == .user ? login.username : login.password).utf8)
                index = match.end
            } else {
                output.append(bytes[index])
                index += 1
            }
        }
        return String(decoding: output, as: UTF8.self)
    }

    /// True when `text` holds a placeholder made with `token`.
    public static func hasPlaceholders(_ text: String, token: String) -> Bool {
        text.contains("{antenna.\(token).")
    }

    /// A token whose placeholders cannot clash with `text`: `preferred`
    /// when it is usable, so a re-import keeps its channel ids, otherwise
    /// a new random one.
    public static func token(for text: String, preferred: String?) -> String {
        if let preferred, !preferred.isEmpty, !hasPlaceholders(text, token: preferred) { return preferred }
        while true {
            let candidate = String(UUID().uuidString.prefix(8)).lowercased()
            if !hasPlaceholders(text, token: candidate) { return candidate }
        }
    }

    private enum Field { case user, pass }

    /// Parses `user.N}` or `pass.N}` at `start`.
    private struct Placeholder {
        var field: Field
        var number: Int
        /// The index after the closing brace.
        var end: Int
    }

    private static func placeholder(_ bytes: [UInt8], after start: Int) -> Placeholder? {
        let field: Field
        if bytes[start...].starts(with: Array("user.".utf8)) {
            field = .user
        } else if bytes[start...].starts(with: Array("pass.".utf8)) {
            field = .pass
        } else {
            return nil
        }
        var index = start + 5
        var number = 0
        var digits = 0
        while index < bytes.count, let digit = Self.digit(bytes[index]), digits < 9 {
            number = number * 10 + digit
            digits += 1
            index += 1
        }
        guard digits > 0, index < bytes.count, bytes[index] == UInt8(ascii: "}") else { return nil }
        return Placeholder(field: field, number: number, end: index + 1)
    }

    private static func digit(_ byte: UInt8) -> Int? {
        (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) ? Int(byte - UInt8(ascii: "0")) : nil
    }
}

/// Finds and replaces logins inside one link at a time.
private struct LoginStripper {
    let token: [UInt8]
    var credentials: [StreamCredential] = []
    private var indexes: [StreamCredential: Int] = [:]

    init(token: [UInt8]) {
        self.token = token
    }

    /// The index after `://` when an `http://` or `https://` link starts at `index`.
    static func schemeEnd(_ bytes: [UInt8], at index: Int) -> Int? {
        let first = bytes[index] | 0x20
        guard first == UInt8(ascii: "h") else { return nil }
        for scheme in ["http://", "https://"] {
            let pattern = Array(scheme.utf8)
            guard index + pattern.count <= bytes.count else { continue }
            if zip(bytes[index..<index + pattern.count], pattern).allSatisfy({ $0 | 0x20 == $1 | 0x20 }) {
                return index + pattern.count
            }
        }
        return nil
    }

    static func endsLink(_ byte: UInt8) -> Bool {
        switch byte {
        case 0x20, 0x09, 0x0A, 0x0D, UInt8(ascii: "\""), UInt8(ascii: "'"), UInt8(ascii: "<"), UInt8(ascii: ">"): true
        default: false
        }
    }

    mutating func strip(_ link: ArraySlice<UInt8>, schemeEnd: Int) -> [UInt8] {
        let bytes = Array(link)
        let start = schemeEnd - link.startIndex
        let authorityEnd =
            bytes[start...].firstIndex { $0 == UInt8(ascii: "/") || $0 == UInt8(ascii: "?") || $0 == UInt8(ascii: "#") } ?? bytes.count
        var output = Array(bytes[..<start])
        var host = bytes[start..<authorityEnd]
        if let at = host.lastIndex(of: UInt8(ascii: "@")) {
            let userInfo = bytes[start..<at]
            host = bytes[(at + 1)..<authorityEnd]
            if let colon = userInfo.firstIndex(of: UInt8(ascii: ":")), colon > start, colon + 1 < at {
                let number = index(host: host, user: bytes[start..<colon], pass: bytes[(colon + 1)..<at])
                output += placeholder("user", number)
                output.append(UInt8(ascii: ":"))
                output += placeholder("pass", number)
                output.append(UInt8(ascii: "@"))
            } else {
                output += bytes[start...at]
            }
        }
        output += host
        let rest = bytes[authorityEnd...]
        let queryStart = rest.firstIndex { $0 == UInt8(ascii: "?") || $0 == UInt8(ascii: "#") } ?? bytes.count
        output += strippedPath(bytes[authorityEnd..<queryStart], host: host)
        output += strippedQuery(bytes[queryStart...], host: host)
        return output
    }

    /// `/live/<user>/<pass>/<id>.<ext>` with exactly four segments.
    private mutating func strippedPath(_ path: ArraySlice<UInt8>, host: ArraySlice<UInt8>) -> [UInt8] {
        guard path.first == UInt8(ascii: "/") else { return Array(path) }
        let segments = path.dropFirst().split(separator: UInt8(ascii: "/"), omittingEmptySubsequences: false)
        guard segments.count == 4, ["live", "movie", "series"].contains(String(decoding: segments[0], as: UTF8.self)),
            !segments[1].isEmpty, !segments[2].isEmpty, Self.isFileName(segments[3])
        else { return Array(path) }
        let number = index(host: host, user: segments[1], pass: segments[2])
        let parts: [[UInt8]] = [[], Array(segments[0]), placeholder("user", number), placeholder("pass", number), Array(segments[3])]
        return Array(parts.joined(separator: [UInt8(ascii: "/")]))
    }

    /// `<id>.<ext>`: something on both sides of the last dot.
    private static func isFileName(_ segment: ArraySlice<UInt8>) -> Bool {
        guard let dot = segment.lastIndex(of: UInt8(ascii: ".")) else { return false }
        return dot > segment.startIndex && dot + 1 < segment.endIndex
    }

    /// `username=` and `password=` in the query, both present and not empty.
    private mutating func strippedQuery(_ rest: ArraySlice<UInt8>, host: ArraySlice<UInt8>) -> [UInt8] {
        guard rest.first == UInt8(ascii: "?") else { return Array(rest) }
        let fragment = rest.firstIndex(of: UInt8(ascii: "#")) ?? rest.endIndex
        let query = rest[(rest.startIndex + 1)..<fragment]
        let pairs = query.split(separator: UInt8(ascii: "&"), omittingEmptySubsequences: false)
        func value(_ key: String) -> ArraySlice<UInt8>? {
            let prefix = Array("\(key)=".utf8)
            return pairs.first { $0.starts(with: prefix) }.map { $0.dropFirst(prefix.count) }
        }
        guard let user = value("username"), let pass = value("password"), !user.isEmpty, !pass.isEmpty else { return Array(rest) }
        let number = index(host: host, user: user, pass: pass)
        var parts: [[UInt8]] = []
        for pair in pairs {
            if pair.starts(with: Array("username=".utf8)) {
                parts.append(Array("username=".utf8) + placeholder("user", number))
            } else if pair.starts(with: Array("password=".utf8)) {
                parts.append(Array("password=".utf8) + placeholder("pass", number))
            } else {
                parts.append(Array(pair))
            }
        }
        var output: [UInt8] = [UInt8(ascii: "?")]
        output += parts.joined(separator: [UInt8(ascii: "&")])
        output += rest[fragment...]
        return output
    }

    private mutating func index(host: ArraySlice<UInt8>, user: ArraySlice<UInt8>, pass: ArraySlice<UInt8>) -> Int {
        let credential = StreamCredential(
            host: String(decoding: host, as: UTF8.self), username: String(decoding: user, as: UTF8.self),
            password: String(decoding: pass, as: UTF8.self))
        if let known = indexes[credential] { return known }
        credentials.append(credential)
        indexes[credential] = credentials.count - 1
        return credentials.count - 1
    }

    private func placeholder(_ field: String, _ number: Int) -> [UInt8] {
        Array("{antenna.".utf8) + token + Array(".\(field).\(number)}".utf8)
    }
}
