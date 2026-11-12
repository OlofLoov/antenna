import Foundation

/// Builds the address that plays part of a past or running programme from
/// the provider's catch-up, in the channel's catch-up style
/// (timeshift-catch-up-and-start-over/catch-up-asks-the-provider-the-way-it-expects).
///
/// Pure: it requests nothing. Nil means no address can be built, and the
/// caller falls back to the local buffer. Every address it returns can hold
/// the login, so it is never logged or stored.
public enum CatchupURLBuilder {
    /// The catch-up address for `request` on `channel`.
    ///
    /// - `xtream` is the login and panel time zone of the channel's source,
    ///   needed for an Xtream channel. A nil context, or one without a time
    ///   zone, gives nil.
    /// - `deviceTimeZone` writes the date parts of playlist styles, shifted
    ///   by the channel's hour correction. Unix times are never shifted.
    public static func url(
        for channel: Channel, request: CatchupRequest, xtream: XtreamCatchupContext?, deviceTimeZone: TimeZone = .current
    ) -> URL? {
        guard channel.hasCatchup, let mode = channel.catchupMode, accepts(request, days: channel.catchupDays) else { return nil }
        let values = Placeholders(request: request, zone: deviceTimeZone, correctionHours: channel.catchupCorrectionHours ?? 0)
        switch mode {
        case .default:
            return channel.catchupSource.flatMap(values.expand).flatMap(web)
        case .append:
            return channel.catchupSource.flatMap { append($0, to: channel.streamURL, values: values) }
        case .shift:
            return append(channel.catchupSource ?? "?utc={utc}&lutc={lutc}", to: channel.streamURL, values: values)
        case .flussonic:
            return flussonic(channel.streamURL, request: request)
        case .xc:
            if let id = XtreamTitleID(parsing: channel.id), id.kind == .live {
                guard let xtream, let zone = xtream.timeZone else { return nil }
                return XtreamClient(credentials: xtream.credentials)
                    .timeshiftURL(streamID: id.rawID, start: request.start, durationMinutes: request.durationMinutes, timeZone: zone)
            }
            return playlistXC(channel.streamURL, request: request, values: values)
        case .unsupported:
            return nil
        }
    }

    /// False for a start after now, no length, or a start older than the kept days.
    static func accepts(_ request: CatchupRequest, days: Int?) -> Bool {
        guard request.start <= request.now, request.duration > 0 else { return false }
        if let days, days > 0, request.start < request.now.addingTimeInterval(-Double(days) * 86400) { return false }
        return true
    }

    /// `url` when it is an http or https address with a host.
    static func web(_ text: String) -> URL? {
        guard let url = URL(string: text), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
            url.host()?.isEmpty == false
        else { return nil }
        return url
    }

    /// The stream address with the expanded template after it. A template
    /// starting with "?" joins with "&" when the address has a query already.
    static func append(_ template: String, to stream: URL, values: Placeholders) -> URL? {
        guard web(stream.absoluteString) != nil, var tail = values.expand(template) else { return nil }
        if tail.hasPrefix("?"), stream.query() != nil { tail = "&" + tail.dropFirst() }
        return web(stream.absoluteString + tail)
    }

    /// Flussonic puts the start and length into the last path component.
    static func flussonic(_ stream: URL, request: CatchupRequest) -> URL? {
        guard web(stream.absoluteString) != nil, var components = URLComponents(url: stream, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let start = Int(request.start.timeIntervalSince1970)
        let length = Int(request.duration)
        var path = components.percentEncodedPath.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard let last = path.last else { return nil }
        switch last {
        case "index.m3u8", "video.m3u8", "mono.m3u8":
            path[path.count - 1] = "\(last.dropLast(5))-\(start)-\(length).m3u8"
        case "mpegts":
            path[path.count - 1] = "archive-\(start)-\(length).ts"
        default:
            return nil
        }
        components.percentEncodedPath = path.joined(separator: "/")
        return components.url
    }

    /// An M3U channel in `xc` style: the login and id come from a
    /// `/live/<user>/<pass>/<id>.<ext>` stream address, the start is
    /// written in the device's zone shifted by the correction.
    static func playlistXC(_ stream: URL, request: CatchupRequest, values: Placeholders) -> URL? {
        guard web(stream.absoluteString) != nil, var components = URLComponents(url: stream, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let parts = components.percentEncodedPath.split(separator: "/").map(String.init)
        guard parts.count == 4, parts[0] == "live", let dot = parts[3].lastIndex(of: "."), dot != parts[3].startIndex else { return nil }
        let id = parts[3][..<dot]
        let date = CatchupDateText.xtream(values.shiftedStart, in: values.zone)
        components.percentEncodedPath = "/timeshift/\(parts[1])/\(parts[2])/\(request.durationMinutes)/\(date)/\(id).ts"
        components.percentEncodedQuery = nil
        return components.url
    }
}

extension CatchupURLBuilder {
    /// The values the playlist templates can name, as `{name}` or `${name}`.
    struct Placeholders {
        let request: CatchupRequest
        let zone: TimeZone
        let correctionHours: Double

        /// The start with the correction applied, for date parts only.
        var shiftedStart: Date { request.start.addingTimeInterval(correctionHours * 3600) }

        func value(_ name: String) -> String? {
            let parts = CatchupDateText.components(shiftedStart, in: zone)
            switch name {
            case "utc", "start": return unix(request.start)
            case "utcend", "end": return unix(request.end)
            case "lutc", "now", "timestamp": return unix(request.now)
            case "duration": return String(Int(request.duration))
            case "duration:60": return String(request.durationMinutes)
            case "offset": return String(Int(request.offset))
            case "offset:60": return String(Int((request.offset / 60).rounded(.up)))
            case "Y": return String(parts.year)
            case "m": return CatchupDateText.pad(parts.month)
            case "d": return CatchupDateText.pad(parts.day)
            case "H": return CatchupDateText.pad(parts.hour)
            case "M": return CatchupDateText.pad(parts.minute)
            case "S": return CatchupDateText.pad(parts.second)
            default: return nil
            }
        }

        private func unix(_ date: Date) -> String {
            String(Int(date.timeIntervalSince1970))
        }

        /// The template with every placeholder filled, nil when it names one
        /// that is not known or a brace is left open.
        func expand(_ template: String) -> String? {
            var result = ""
            var rest = Substring(template)
            while let open = rest.firstIndex(of: "{") {
                var before = rest[..<open]
                if before.hasSuffix("$") { before = before.dropLast() }
                result += before
                let afterOpen = rest.index(after: open)
                guard let close = rest[afterOpen...].firstIndex(of: "}"), let filled = value(String(rest[afterOpen..<close])) else {
                    return nil
                }
                result += filled
                rest = rest[rest.index(after: close)...]
            }
            return result + rest
        }
    }
}
