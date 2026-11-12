import Foundation

/// One genre from `get_genres`.
public struct StalkerGenre: Sendable, Hashable {
    public var id: String
    public var title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }

    /// The portal's catch-all genre: id `*`, or the title "All" in any case.
    public var isAll: Bool {
        id == "*" || title.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare("All") == .orderedSame
    }
}

/// Which id a Stalker channel's guide is matched by.
public enum StalkerGuideMatch: Sendable, Equatable {
    /// The source has no guide link and reads the portal's guide, which
    /// names channels by the portal's channel id. Every channel's guide id
    /// is that id, so channels with and without an XMLTV id match.
    case portal
    /// The source has a guide link the user added, matched by XMLTV id.
    case xmltv
}

/// A portal's channel list as the catalogue takes it.
public struct StalkerChannelLoad: Sendable, Equatable {
    /// In portal order, no two with the same id.
    public var channels: [Channel]
    /// Channel rows dropped as broken or repeated.
    public var skippedChannels: Int
    /// Genre rows dropped as broken.
    public var skippedGenres: Int

    public init(channels: [Channel], skippedChannels: Int, skippedGenres: Int) {
        self.channels = channels
        self.skippedChannels = skippedChannels
        self.skippedGenres = skippedGenres
    }
}

extension StalkerClient {
    /// How long the channel list may take, since one answer can hold tens of
    /// thousands of channels
    /// (stalker-portal-source/channels-show-up-grouped-by-genre).
    public static let channelListTimeout: TimeInterval = 300

    /// `get_genres`. Rows that are not objects or lack an id or a title are
    /// skipped and counted.
    public func genres() async throws -> (genres: [StalkerGenre], skipped: Int) {
        let payload = try await call([("type", "itv"), ("action", "get_genres")])
        return Self.decodeGenres(payload.value)
    }

    /// Genres, then every channel, mapped onto `Channel`.
    public func liveLoad(guide: StalkerGuideMatch) async throws -> StalkerChannelLoad {
        let genres = try await genres()
        let payload = try await call([("type", "itv"), ("action", "get_all_channels")], timeout: Self.channelListTimeout)
        let names = Dictionary(genres.genres.filter { !$0.isAll }.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
        var load = decodeChannels(payload.value, genreNames: names, guide: guide)
        load.skippedGenres = genres.skipped
        return load
    }

    static func decodeGenres(_ js: Any) -> (genres: [StalkerGenre], skipped: Int) {
        guard let rows = js as? [Any] else { return ([], 0) }
        var genres: [StalkerGenre] = []
        var skipped = 0
        for row in rows {
            guard let object = row as? [String: Any], let id = StalkerWire.string(object["id"]), !id.isEmpty,
                let title = StalkerWire.string(object["title"])
            else {
                skipped += 1
                continue
            }
            genres.append(StalkerGenre(id: id, title: title))
        }
        return (genres, skipped)
    }

    /// Maps `get_all_channels`. `js` may be `{"data": [...]}` or the list
    /// itself; `false` and any other shape give no channels. A row without
    /// an id, a name or a `cmd`, or with an id seen before, is skipped and
    /// counted.
    func decodeChannels(_ js: Any, genreNames: [String: String], guide: StalkerGuideMatch) -> StalkerChannelLoad {
        let rows = ((js as? [String: Any])?["data"] as? [Any]) ?? (js as? [Any]) ?? []
        var channels: [Channel] = []
        channels.reserveCapacity(rows.count)
        var seen = Set<String>()
        var skipped = 0
        let logoBase = logoDirectory()
        for row in rows {
            guard let object = row as? [String: Any], let id = StalkerWire.string(object["id"]), !id.isEmpty,
                let name = StalkerWire.string(object["name"]), !name.isEmpty,
                let cmd = StalkerWire.string(object["cmd"]), !cmd.isEmpty,
                let reference = Self.reference(host: credentials.portal, id: id, cmd: cmd), seen.insert(id).inserted
            else {
                skipped += 1
                continue
            }
            let xmltv = StalkerWire.string(object["xmltv_id"])?.trimmingCharacters(in: .whitespacesAndNewlines)
            let archive = StalkerWire.int(object["tv_archive"]) ?? ((object["tv_archive"] as? Bool) == true ? 1 : 0)
            let hours = StalkerWire.int(object["tv_archive_duration"])
            channels.append(
                Channel(
                    id: "stalker#\(credentials.portal.host)#\(id)",
                    name: name,
                    streamURL: reference,
                    group: StalkerWire.string(object["tv_genre_id"]).flatMap { genreNames[$0] },
                    logoURL: Self.logo(StalkerWire.string(object["logo"]), base: logoBase, portal: credentials.portal.url),
                    epgID: guide == .portal ? id : (xmltv?.isEmpty == false ? xmltv : nil),
                    number: StalkerWire.int(object["number"]),
                    hasCatchup: archive > 0,
                    catchupDays: archive > 0 ? hours.flatMap { $0 > 0 ? ($0 + 23) / 24 : nil } : nil,
                    catchupMode: archive > 0 ? .unsupported("stalker") : nil
                ))
        }
        return StalkerChannelLoad(channels: channels, skippedChannels: skipped, skippedGenres: 0)
    }

    /// `stalker://<host>/<id>?cmd=<cmd>`, the address a Stalker channel
    /// keeps until it is tuned.
    static func reference(host portal: StalkerPortal, id: String, cmd: String) -> URL? {
        var components = URLComponents()
        components.scheme = "stalker"
        let host = portal.url.host(percentEncoded: true) ?? ""
        components.percentEncodedHost = host.contains(":") && !host.hasPrefix("[") ? "[\(host)]" : host
        components.percentEncodedPath = "/" + XtreamClient.percentEncode(id)
        components.percentEncodedQuery = "cmd=" + XtreamClient.percentEncode(cmd)
        return components.url
    }

    /// The directory bare logo file names go under: the endpoint's directory
    /// with `server/` dropped, then `misc/logos/320/`.
    func logoDirectory() -> URL? {
        guard let endpoint else { return nil }
        var directory = endpoint.deletingLastPathComponent()
        if directory.lastPathComponent == "server" { directory = directory.deletingLastPathComponent() }
        return directory.appending(path: "misc/logos/320")
    }

    /// An http or https logo is used as is. A path starting with "/" is
    /// taken from the portal's origin. A bare file name goes under `base`.
    static func logo(_ text: String?, base: URL?, portal: URL) -> URL? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        if let web = Loose.webURL(text) { return web }
        if text.contains("://") { return nil }
        if text.hasPrefix("/") {
            var origin = URLComponents(url: portal, resolvingAgainstBaseURL: false)
            origin?.percentEncodedPath = ""
            return origin?.url.flatMap { URL(string: text, relativeTo: $0)?.absoluteURL }
        }
        return base.map { $0.appending(path: text) }
    }
}
