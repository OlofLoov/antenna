import Foundation

/// What a portal guide download turned out to be.
public enum StalkerGuideAnswer: Sendable {
    /// The portal turned the session key down. Call `invalidateToken()`,
    /// ask for a new request and try once more.
    case rejected
    /// Programmes keyed by the portal's channel id, and the rows skipped as
    /// broken or with a stop not after their start.
    case guide([Programme], skipped: Int)
}

extension StalkerClient {
    /// The guide period asked for is clamped to this many hours.
    public static let guideHours = 1...168

    /// True for a Stalker channel reference, whatever its portal.
    public static func isReference(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "stalker"
    }

    /// A fresh playable address for `channel` from `create_link`
    /// (stalker-portal-source/tuning-gets-a-fresh-stream-address). Ask on
    /// every tune; the address holds a short-lived key, so never store or
    /// log it. Throws `.notStalkerChannel` without a request for a channel
    /// from elsewhere, and `.noLink` when the answer holds no address.
    public func playableURL(for channel: Channel) async throws -> URL {
        guard let cmd = command(of: channel) else { throw StalkerError.notStalkerChannel }
        let items = [
            ("type", "itv"), ("action", "create_link"), ("cmd", cmd), ("series", ""), ("forced_storage", ""), ("disable_ad", "0"),
            ("download", "0"), ("force_ch_link_check", "0"),
        ]
        let payload = try await call(items)
        guard let url = Self.decodeLink(payload.value) else { throw StalkerError.noLink }
        return url
    }

    /// The `cmd` of a reference to a channel of this portal, nil otherwise.
    nonisolated func command(of channel: Channel) -> String? {
        let url = channel.streamURL
        guard Self.isReference(url), url.host()?.lowercased() == credentials.portal.url.host()?.lowercased(),
            let cmd = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "cmd" })?.value,
            !cmd.isEmpty
        else { return nil }
        return cmd
    }

    /// The last whitespace-separated piece of `js.cmd` that is an http or
    /// https address with a host, so `ffmpeg <url>`, `auto <url>` and a bare
    /// `<url>` all resolve.
    static func decodeLink(_ js: Any) -> URL? {
        guard let cmd = StalkerWire.string((js as? [String: Any])?["cmd"]) else { return nil }
        return cmd.split(whereSeparator: \.isWhitespace).reversed().lazy.compactMap { Loose.webURL(String($0)) }.first
    }

    // MARK: Guide

    /// A signed-in `get_epg_info` request for the next `period` hours,
    /// clamped to 1 to 168, for the guide to download with its own session.
    /// The request holds the MAC and the session key: never log it.
    public func epgRequest(period: Int) async throws -> URLRequest {
        let signed = try await currentSession()
        guard let endpoint else { throw StalkerError.noPortal }
        let hours = min(max(period, Self.guideHours.lowerBound), Self.guideHours.upperBound)
        let url = StalkerWire.url(endpoint: endpoint, items: [("type", "itv"), ("action", "get_epg_info"), ("period", String(hours))])
        return request(url, token: signed.token, timeout: Self.channelListTimeout)
    }

    /// Reads a `get_epg_info` answer. `js.data` (or `js`) may map channel
    /// ids to row lists, or be one list of rows that carry `ch_id`. A row
    /// needs a channel id, a name and a start, from `start_timestamp`; its
    /// stop is `stop_timestamp`, else the start plus `duration` seconds.
    /// Throws `.serverError` or `.unreadable`, quoting nothing.
    public static func decodeGuide(status: Int, data: Data) throws -> StalkerGuideAnswer {
        let js: Any
        switch try StalkerWire.read(status: status, data: data) {
        case .rejected: return .rejected
        case .payload(let value): js = value
        }
        let body = (js as? [String: Any])?["data"] ?? js
        var programmes: [Programme] = []
        var skipped = 0
        func add(_ row: Any, channel: String?) {
            guard let programme = programme(row, channel: channel) else {
                skipped += 1
                return
            }
            programmes.append(programme)
        }
        if let byChannel = body as? [String: Any] {
            for (channel, rows) in byChannel {
                guard let rows = rows as? [Any] else {
                    skipped += 1
                    continue
                }
                for row in rows { add(row, channel: channel) }
            }
        } else if let rows = body as? [Any] {
            for row in rows { add(row, channel: nil) }
        }
        return .guide(programmes, skipped: skipped)
    }

    private static func programme(_ row: Any, channel: String?) -> Programme? {
        guard let object = row as? [String: Any],
            let channelID = StalkerWire.string(object["ch_id"]) ?? channel, !channelID.isEmpty,
            let title = StalkerWire.string(object["name"]), !title.isEmpty,
            let start = StalkerWire.int(object["start_timestamp"]), start > 0
        else { return nil }
        let stop = StalkerWire.int(object["stop_timestamp"]) ?? StalkerWire.int(object["duration"]).map { start + $0 }
        guard let stop, stop > start else { return nil }
        let summary = StalkerWire.string(object["descr"]).flatMap { $0.isEmpty ? nil : $0 }
        let category = StalkerWire.string(object["category"]).flatMap { $0.isEmpty ? nil : $0 }
        return Programme(
            channelID: channelID, start: Date(timeIntervalSince1970: TimeInterval(start)),
            stop: Date(timeIntervalSince1970: TimeInterval(stop)),
            title: title, summary: summary, category: category)
    }
}
