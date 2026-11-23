import Foundation

/// A stream or logo link as the launch record keeps it: every path part and
/// query value equal to a login's username or password is a mark naming that
/// login, never its text
/// (session-restore-and-recently-watched/what-is-saved-for-launch-holds-no-login).
public struct SavedLink: Codable, Hashable, Sendable {
    /// One path part or query value.
    public enum Part: Codable, Hashable, Sendable {
        /// Percent-encoded as in the link.
        case text(String)
        /// The username of the login at this index.
        case username(Int)
        /// The password of the login at this index.
        case password(Int)
    }

    public struct QueryItem: Codable, Hashable, Sendable {
        /// Percent-encoded as in the link.
        public var name: String
        public var value: Part?
    }

    /// Scheme, host and port, such as `http://panel:8080`.
    public var origin: String
    /// The path split at each `/`, so the first part of an absolute path is empty.
    public var path: [Part]
    /// Nil when the link has no `?`.
    public var query: [QueryItem]?

    /// Nil when the link cannot be kept without a login in it: a scheme other
    /// than http, https or file, a user or password before the host, a
    /// fragment, a query value named like a login or token that is not one
    /// of `logins`, or a text part that still holds a username or password of
    /// six or more characters.
    public init?(_ url: URL, logins: [SavedChannel.Login]) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let scheme = components.scheme?.lowercased(), Self.schemes.contains(scheme),
            components.percentEncodedUser == nil, components.percentEncodedPassword == nil, components.fragment == nil
        else { return nil }
        let host = components.percentEncodedHost ?? ""
        guard scheme == "file" || !host.isEmpty else { return nil }
        var server = URLComponents()
        server.scheme = scheme
        server.percentEncodedHost = host
        server.port = components.port
        guard let origin = server.string else { return nil }
        self.origin = origin
        path = components.percentEncodedPath.split(separator: "/", omittingEmptySubsequences: false).map {
            Self.part(String($0), logins: logins)
        }
        query = components.percentEncodedQueryItems?.map { item in
            QueryItem(name: item.name, value: item.value.map { Self.part($0, logins: logins) })
        }
        guard !holdsLogin(logins) else { return nil }
    }

    /// The link with each mark replaced by its login, percent-encoded outside
    /// the unreserved set. Nil when a mark names a login `logins` lacks.
    public func url(logins: [SavedChannel.Login]) -> URL? {
        func text(_ part: Part) -> String? {
            switch part {
            case .text(let text): text
            case .username(let index): logins.indices.contains(index) ? Self.encoded(logins[index].username) : nil
            case .password(let index): logins.indices.contains(index) ? Self.encoded(logins[index].password) : nil
            }
        }
        var parts: [String] = []
        for part in path {
            guard let piece = text(part) else { return nil }
            parts.append(piece)
        }
        var string = origin + parts.joined(separator: "/")
        if let query {
            var items: [String] = []
            for item in query {
                guard let value = item.value else {
                    items.append(item.name)
                    continue
                }
                guard let piece = text(value) else { return nil }
                items.append("\(item.name)=\(piece)")
            }
            string += "?" + items.joined(separator: "&")
        }
        return URL(string: string)
    }

    static let schemes: Set<String> = ["http", "https", "file"]
    static let secretNames = ["pass", "pwd", "user", "token", "auth", "key", "sign", "secret", "session", "hash"]
    /// Logins at least this long are also looked for inside text parts.
    static let searchedLength = 6
    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    private static func encoded(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? text
    }

    private static func part(_ encoded: String, logins: [SavedChannel.Login]) -> Part {
        let decoded = encoded.removingPercentEncoding ?? encoded
        guard !decoded.isEmpty else { return .text(encoded) }
        if let index = logins.firstIndex(where: { $0.password == decoded }) { return .password(index) }
        if let index = logins.firstIndex(where: { $0.username == decoded }) { return .username(index) }
        return .text(encoded)
    }

    private func holdsLogin(_ logins: [SavedChannel.Login]) -> Bool {
        for item in query ?? [] {
            let name = (item.name.removingPercentEncoding ?? item.name).lowercased()
            if case .text = item.value, Self.secretNames.contains(where: name.contains) { return true }
        }
        var texts = [origin]
        for part in path + (query ?? []).compactMap(\.value) {
            if case .text(let text) = part { texts.append(text.removingPercentEncoding ?? text) }
        }
        texts += (query ?? []).map { $0.name.removingPercentEncoding ?? $0.name }
        let searched = logins.flatMap { [$0.username, $0.password] }.filter { $0.count >= Self.searchedLength }
        return texts.contains { text in searched.contains { text.contains($0) } }
    }
}
