import Foundation

/// What the user typed into the add-source form. `check()` applies the
/// form's rules before anything is sent
/// (first-run-onboarding/mistakes-in-the-form-are-caught-before-connecting).
public struct SourceFields: Equatable, Sendable {
    public var kind: SourceKind
    public var name: String
    /// The playlist URL for M3U, the server for Xtream, Jellyfin and
    /// Channels DVR, the portal for Stalker.
    public var url: String
    public var epgURL: String
    /// The Xtream or Jellyfin username, the optional Stalker portal login,
    /// or the optional Channels DVR proxy username.
    public var username: String
    /// The Xtream or Jellyfin password, or the optional Stalker portal password.
    public var password: String
    /// The MAC address a Stalker portal knows the device by. Other kinds ignore it.
    public var mac: String

    public init(
        kind: SourceKind = .xtream, name: String = "", url: String = "", epgURL: String = "", username: String = "", password: String = "",
        mac: String = ""
    ) {
        self.kind = kind
        self.name = name
        self.url = url
        self.epgURL = epgURL
        self.username = username
        self.password = password
        self.mac = mac
    }

    /// The first problem in form order, or nil when Connect may go ahead.
    /// An empty required field comes first, then a link without a scheme.
    /// A portal also needs `http` or `https` and a MAC that parses; its
    /// login and password are optional (first-run-onboarding/add-a-stalker-portal).
    public func check() -> ConnectFailure? {
        let required: [(SourceField, String)] =
            switch kind {
            case .m3u, .m3uFile: [(.playlist, url)]
            case .xtream, .jellyfin: [(.server, url), (.username, username), (.password, password)]
            case .stalker: [(.portal, url), (.mac, mac)]
            case .channelsDVR: [(.server, url)]
            }
        if let empty = required.first(where: { $0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return .missingField(empty.0)
        }
        if kind == .channelsDVR { return checkChannelsDVR() }
        guard let link else { return .invalidURL }
        if kind == .jellyfin {
            // first-run-onboarding/add-a-jellyfin-server
            let scheme = link.scheme?.lowercased()
            return (scheme == "http" || scheme == "https") && link.host()?.isEmpty == false ? nil : .invalidURL
        }
        guard kind == .stalker else { return nil }
        guard StalkerPortal(url) != nil else { return .invalidURL }
        return MACAddress(mac) == nil ? .invalidMAC : nil
    }

    /// A Channels DVR address `ChannelsDVRClient.serverURL(from:)` turns
    /// down, then one Remote access field filled without the other
    /// (first-run-onboarding/add-a-channels-dvr-server).
    private func checkChannelsDVR() -> ConnectFailure? {
        guard ChannelsDVRClient.serverURL(from: url) != nil else {
            let typed = url.trimmingCharacters(in: .whitespacesAndNewlines)
            let authority = typed.components(separatedBy: "://").last?.split(separator: "/").first ?? ""
            return authority.contains("@") ? .addressHasLogin : .invalidServer
        }
        let hasUsername = !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasUsername != !password.isEmpty { return .missingField(hasUsername ? .password : .username) }
        if hasUsername, HTTPBasicCredential(username: username, password: password) == nil { return .invalidUsername }
        return nil
    }

    /// The link with surrounding spaces trimmed, nil when it has no scheme.
    /// For a Channels DVR server, the tidy server address.
    public var link: URL? {
        if kind == .channelsDVR { return ChannelsDVRClient.serverURL(from: url) }
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
