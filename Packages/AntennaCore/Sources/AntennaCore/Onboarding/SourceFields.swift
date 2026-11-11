import Foundation

/// What the user typed into the add-source form. `check()` applies the
/// form's rules before anything is sent
/// (first-run-onboarding/mistakes-in-the-form-are-caught-before-connecting).
public struct SourceFields: Equatable, Sendable {
    public var kind: SourceKind
    public var name: String
    /// The playlist URL for M3U, the server for Xtream.
    public var url: String
    public var epgURL: String
    public var username: String
    public var password: String

    public init(
        kind: SourceKind = .xtream, name: String = "", url: String = "", epgURL: String = "", username: String = "", password: String = ""
    ) {
        self.kind = kind
        self.name = name
        self.url = url
        self.epgURL = epgURL
        self.username = username
        self.password = password
    }

    /// The first problem in form order, or nil when Connect may go ahead.
    /// An empty required field comes first, then a link without a scheme.
    public func check() -> ConnectFailure? {
        let required: [(SourceField, String)] =
            switch kind {
            case .m3u: [(.playlist, url)]
            case .xtream, .stalker: [(.server, url), (.username, username), (.password, password)]
            }
        if let empty = required.first(where: { $0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return .missingField(empty.0)
        }
        return link == nil ? .invalidURL : nil
    }

    /// The link with surrounding spaces trimmed, nil when it has no scheme.
    public var link: URL? {
        guard let url = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines)), url.scheme != nil else { return nil }
        return url
    }

    /// The host Connect names when the server cannot be reached.
    public var host: String {
        link?.host() ?? url.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Fills the fields from a copied link
    /// (first-run-onboarding/fill-the-form-from-a-copied-link). The name and
    /// guide link are kept.
    public mutating func fill(from link: CopiedLink) {
        switch link {
        case .xtream(let server, let username, let password):
            kind = .xtream
            url = server
            self.username = username
            self.password = password
        case .playlist(let playlist):
            kind = .m3u
            url = playlist
        }
    }
}

/// Compares source links the way duplicates are found: spaces and one
/// trailing slash dropped, scheme and host lower-cased.
public enum SourceLink {
    public static func key(_ url: URL) -> String {
        var text = url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasSuffix("/") { text.removeLast() }
        guard var components = URLComponents(string: text) else { return text }
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        return components.string ?? text
    }
}

/// A link found on the clipboard, sorted into the form it fills.
public enum CopiedLink: Equatable, Sendable {
    /// A link carrying `username` and `password`: the server is its scheme,
    /// host and port.
    case xtream(server: String, username: String, password: String)
    /// Any other web link, used as the playlist URL.
    case playlist(String)

    /// Nil when `text` is not a single http or https link with a host.
    public init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: \.isWhitespace), let components = URLComponents(string: trimmed),
            let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https",
            let host = components.host, !host.isEmpty
        else { return nil }
        let items = components.queryItems ?? []
        let username = items.first { $0.name == "username" }?.value
        let password = items.first { $0.name == "password" }?.value
        if let username, let password {
            var server = URLComponents()
            server.scheme = components.scheme
            server.host = host
            server.port = components.port
            self = .xtream(server: server.string ?? "\(scheme)://\(host)", username: username, password: password)
        } else {
            self = .playlist(trimmed)
        }
    }
}
