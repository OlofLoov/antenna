import Foundation

/// A playlist link served by an Xtream panel, `<server>/get.php?username=U&password=P…`
/// (source-management/xtream-panel-playlist-links-are-recognized).
///
/// `description` and `debugDescription` are the server host only, so the
/// value can be interpolated into logs without leaking the login.
public struct XtreamPanelLink: Sendable, Hashable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    /// The server (scheme, host, port and any path before `get.php`) with the link's login.
    public let credentials: XtreamCredentials

    /// Nil unless `url` is http or https with a host, its last path part is
    /// `get.php`, and its query has a non-empty `username` and `password`.
    public init?(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https",
            let host = components.host, !host.isEmpty
        else { return nil }
        var path = components.percentEncodedPath
        guard path.lowercased().hasSuffix("/get.php") else { return nil }
        path.removeLast("/get.php".count)
        let items = components.queryItems ?? []
        guard let username = items.first(where: { $0.name == "username" })?.value, !username.isEmpty,
            let password = items.first(where: { $0.name == "password" })?.value, !password.isEmpty
        else { return nil }
        var server = URLComponents()
        server.scheme = scheme
        server.host = host
        server.port = components.port
        server.percentEncodedPath = path
        guard let serverURL = server.url else { return nil }
        credentials = XtreamCredentials(server: serverURL, username: username, password: password)
    }

    /// The text with surrounding spaces trimmed, read as a link; nil as for `init(_:)`.
    public init?(_ text: String) {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        self.init(url)
    }

    public var description: String { credentials.description }
    public var debugDescription: String { description }
    /// Shows the host only, so `dump` does not print the login either.
    public var customMirror: Mirror { Mirror(self, children: ["host": description]) }

    /// The panel's guide link for this login. It holds the login: never log it.
    public var guideURL: URL { XtreamClient(credentials: credentials).xmltvURL() }

    /// The Xtream id each live channel would have on this panel, keyed by
    /// its playlist id. A channel is mapped when its link is on the
    /// server's host, under the server's path, as `[live/]<user>/<password>/<stream id>[.<ext>]`
    /// with a numeric stream id. Movie, series and other links are left out.
    public func liveChannelIDs(for channels: [Channel]) -> [String: String] {
        let host = credentials.server.host() ?? ""
        var map: [String: String] = [:]
        for channel in channels {
            guard let streamID = liveStreamID(channel.streamURL) else { continue }
            map[channel.id] = map[channel.id] ?? XtreamTitleID(host: host, kind: .live, rawID: streamID).description
        }
        return map
    }

    private func liveStreamID(_ url: URL) -> Int? {
        guard url.host()?.lowercased() == credentials.server.host()?.lowercased() else { return nil }
        let base = credentials.server.pathComponents.filter { $0 != "/" }
        var parts = url.pathComponents.filter { $0 != "/" }
        guard parts.starts(with: base) else { return nil }
        parts.removeFirst(base.count)
        if parts.first == "live" { parts.removeFirst() }
        guard parts.count == 3, let last = parts.last else { return nil }
        let stem = last.split(separator: ".", maxSplits: 1).first.map(String.init) ?? last
        guard !stem.isEmpty, stem.allSatisfy(\.isASCIIDigit) else { return nil }
        return Int(stem)
    }
}

extension Character {
    fileprivate var isASCIIDigit: Bool { isASCII && isNumber }
}

extension SourceFields {
    /// The panel login in `url` when the form is a playlist and its link is
    /// one (source-management/the-add-form-offers-xtream-for-a-panel-link).
    public var xtreamPanel: XtreamPanelLink? {
        kind == .m3u ? XtreamPanelLink(url) : nil
    }

    /// Switches a playlist form holding a panel link to Xtream, with the
    /// server, username and password from the link. The name and guide link
    /// are kept. Does nothing when `xtreamPanel` is nil.
    public mutating func useXtream() {
        guard let panel = xtreamPanel else { return }
        kind = .xtream
        url = panel.credentials.server.absoluteString
        username = panel.credentials.username
        password = panel.credentials.password
    }
}
