import Foundation

/// Login for one Xtream Codes panel.
///
/// `description` and `debugDescription` are the server host only, so the
/// value can be interpolated into logs without leaking the login.
public struct XtreamCredentials: Sendable, Hashable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var server: URL
    public var username: String
    public var password: String

    public init(server: URL, username: String, password: String) {
        self.server = server
        self.username = username
        self.password = password
    }

    public var description: String { server.host() ?? "" }
    public var debugDescription: String { description }
    /// Shows the host only, so `dump` does not print the login either.
    public var customMirror: Mirror { Mirror(self, children: ["host": description]) }
}

/// Xtream Codes `player_api.php` client for live, VOD and series.
///
/// Panels are loose with JSON types (ids arrive as strings or numbers), so
/// decoding is tolerant; see the `decode*` functions. Every call throws
/// `XtreamError` or `CancellationError`, never `DecodingError` or `URLError`.
/// `description` and `debugDescription` are the server host only.
public struct XtreamClient: Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public enum StreamContainer: String, Sendable { case ts, m3u8 }

    private let credentials: XtreamCredentials
    private let session: URLSession
    /// Sent on every call when set (sources-and-settings/a-user-agent-per-source).
    private let userAgent: String?

    public init(credentials: XtreamCredentials, session: URLSession = .provider, userAgent: String? = nil) {
        self.credentials = credentials
        self.session = session
        self.userAgent = userAgent
    }

    public var description: String { credentials.description }
    public var debugDescription: String { description }
    /// Shows the host only, so `dump` does not print the login either.
    public var customMirror: Mirror { Mirror(self, children: ["host": description]) }

    private var host: String { credentials.server.host() ?? "" }

    // MARK: Live endpoints

    /// Drops rows without a usable id or name and keeps the rest
    /// (xtream-vod-client/broken-category-rows-are-skipped).
    public func liveCategories() async throws -> [XtreamCategory] {
        try Self.decodeLossyList(try await fetch(action: "get_live_categories"))
    }

    /// Drops rows that are not objects, lack `name` or `stream_id`, or whose `stream_id` is not a whole
    /// number. Keeps server order and does not drop repeated ids.
    public func liveStreams(categoryID: String? = nil) async throws -> [XtreamLiveStream] {
        let data = try await fetch(action: "get_live_streams", id: categoryID.map { ("category_id", $0) })
        return try Self.decodeLossyList(data)
    }

    public func accountInfo() async throws -> XtreamAccountInfo {
        let data = XtreamBody.readable(try await fetch(action: nil))
        try Self.probeAuth(data)
        return try Self.decode(XtreamAccountInfo.self, from: data)
    }

    /// Every live channel with its category name, and the panel's time zone name from the account
    /// information, asked for once (xtream-live-source/server-time-zone). A failed account call
    /// leaves the zone nil and the channels load anyway. A failed category call leaves
    /// them without group names (xtream-live-source/channels-load-without-categories).
    /// The links are MPEG-TS. `offersHLS` says whether the account's allowed output formats let its
    /// channels play as HLS for AirPlay (xtream-live-source/the-account-says-whether-hls-is-offered).
    public func liveLoad() async throws -> XtreamLiveLoad {
        async let categories = try? liveCategories()
        async let streams = liveStreams()
        async let account = try? accountInfo()
        // Providers sometimes repeat a category id; the first name wins.
        let loaded = await categories ?? []
        let names = Dictionary(loaded.map { ($0.categoryID, $0.categoryName) }, uniquingKeysWith: { first, _ in first })
        let adult = Set(loaded.filter(\.isAdult).map(\.categoryID))
        let info = await account
        let channels = try await streams.map { stream in
            channel(
                from: stream, categoryName: stream.categoryID.flatMap { names[$0] },
                categoryIsAdult: stream.categoryID.map(adult.contains) ?? false)
        }
        return XtreamLiveLoad(
            channels: channels, timeZoneName: info?.serverInfo?.timezone,
            offersHLS: XtreamLiveFormat.offersHLS(allowedOutputFormats: info?.userInfo.allowedOutputFormats))
    }

    // MARK: VOD and series endpoints

    public func vodCategories() async throws -> [XtreamCategory] {
        try Self.decodeLossyList(try await fetch(action: "get_vod_categories"))
    }

    /// Every movie and the movie categories. A failed category call gives no
    /// categories and the movies load anyway
    /// (xtream-vod-client/broken-category-rows-are-skipped).
    public func vodLoad() async throws -> (titles: DecodedList<VODItem>, categories: [XtreamCategory]) {
        async let categories = try? vodCategories()
        async let titles = vodStreams()
        return (try await titles, await categories ?? [])
    }

    public func vodStreams(categoryID: String? = nil) async throws -> DecodedList<VODItem> {
        try Self.decodeVODList(try await fetch(action: "get_vod_streams", id: categoryID.map { ("category_id", $0) }), host: host)
    }

    public func vodInfo(streamID: Int) async throws -> VODInfo {
        try Self.decodeVODInfo(try await fetch(action: "get_vod_info", id: ("vod_id", String(streamID))), host: host)
    }

    public func seriesCategories() async throws -> [XtreamCategory] {
        try Self.decodeLossyList(try await fetch(action: "get_series_categories"))
    }

    /// Every series and the series categories, with the rule of `vodLoad()`
    /// for a failed category call.
    public func seriesLoad() async throws -> (titles: DecodedList<Series>, categories: [XtreamCategory]) {
        async let categories = try? seriesCategories()
        async let titles = series()
        return (try await titles, await categories ?? [])
    }

    public func series(categoryID: String? = nil) async throws -> DecodedList<Series> {
        try Self.decodeSeriesList(try await fetch(action: "get_series", id: categoryID.map { ("category_id", $0) }), host: host)
    }

    public func seriesInfo(seriesID: Int) async throws -> SeriesInfo {
        try Self.decodeSeriesInfo(try await fetch(action: "get_series_info", id: ("series_id", String(seriesID))), host: host)
    }

    // MARK: URL building

    /// Credentials are percent-encoded outside the RFC 3986 unreserved set in every URL this client builds.
    public func streamURL(for stream: XtreamLiveStream, container: StreamContainer = .ts) -> URL {
        url(path: ["live", credentials.username, credentials.password, "\(stream.streamID).\(container.rawValue)"])
    }

    public func xmltvURL() -> URL {
        url(path: ["xmltv.php"], query: [("username", credentials.username), ("password", credentials.password)])
    }

    /// `<server>/movie/<user>/<password>/<streamID>.<extension>`. The extension is trimmed, loses one
    /// leading dot, and is "mp4" when nil or empty.
    public func movieURL(streamID: Int, extension: String?) -> URL {
        url(path: ["movie", credentials.username, credentials.password, "\(streamID).\(Self.fileExtension(`extension`))"])
    }

    /// `<server>/series/<user>/<password>/<episodeID>.<extension>`, with the extension rule of `movieURL`.
    public func episodeURL(episodeID: Int, extension: String?) -> URL {
        url(path: ["series", credentials.username, credentials.password, "\(episodeID).\(Self.fileExtension(`extension`))"])
    }

    /// Maps an Xtream live stream onto the app's `Channel` model. The
    /// channel is adult when the stream or its category carries the flag.
    public func channel(from stream: XtreamLiveStream, categoryName: String?, categoryIsAdult: Bool = false) -> Channel {
        Channel(
            id: XtreamTitleID(host: host, kind: .live, rawID: stream.streamID).description,
            name: stream.name,
            streamURL: streamURL(for: stream),
            group: categoryName,
            logoURL: stream.streamIcon.flatMap(URL.init(string:)),
            epgID: stream.epgChannelID?.isEmpty == false ? stream.epgChannelID : nil,
            number: stream.num,
            hasCatchup: (stream.tvArchive ?? 0) > 0,
            catchupDays: stream.tvArchiveDuration,
            catchupMode: (stream.tvArchive ?? 0) > 0 ? .xc : nil,
            isAdult: stream.isAdult || categoryIsAdult
        )
    }

    /// `<server>/timeshift/<user>/<password>/<minutes>/<yyyy-MM-dd:HH-mm>/<streamID>.ts`, the start
    /// written in `timeZone`, or in UTC when it is nil. The address holds the login: never log it.
    public func timeshiftURL(streamID: Int, start: Date, durationMinutes: Int, timeZone: TimeZone?) -> URL {
        let date = CatchupDateText.xtream(start, in: timeZone ?? .gmt)
        return url(
            path: ["timeshift", credentials.username, credentials.password, String(durationMinutes)], verbatim: [date, "\(streamID).ts"])
    }

    // MARK: Internals

    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    static func percentEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }

    static func fileExtension(_ value: String?) -> String {
        var trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix(".") { trimmed.removeFirst() }
        return trimmed.isEmpty ? "mp4" : trimmed
    }

    /// The server URL with its own path kept, then each segment percent-encoded, then the query.
    /// `verbatim` segments follow the encoded ones as written; they must hold only path-safe characters.
    private func url(path segments: [String], verbatim: [String] = [], query: [(String, String)] = []) -> URL {
        guard var components = URLComponents(url: credentials.server, resolvingAgainstBaseURL: false) else {
            return credentials.server
        }
        var base = components.percentEncodedPath
        while base.hasSuffix("/") { base.removeLast() }
        components.percentEncodedPath = base + (segments.map(Self.percentEncode) + verbatim).map { "/" + $0 }.joined()
        components.percentEncodedQuery = query.isEmpty ? nil : query.map { "\($0)=\(Self.percentEncode($1))" }.joined(separator: "&")
        components.fragment = nil
        return components.url ?? credentials.server
    }

    /// One GET to `player_api.php`. Maps transport failures to `XtreamError.transport`, cancellation to
    /// `CancellationError`, 401 and 403 to `unauthorized`, and other non-2xx statuses to `badStatus`.
    private func fetch(action: String?, id: (name: String, value: String)? = nil) async throws -> Data {
        var query = [("username", credentials.username), ("password", credentials.password)]
        if let action { query.append(("action", action)) }
        if let id { query.append(id) }
        var request = URLRequest(url: url(path: ["player_api.php"], query: query))
        StreamHeaders(userAgent.map { ["User-Agent": $0] } ?? [:]).apply(to: &request)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            if Task.isCancelled { throw CancellationError() }
            throw XtreamError.transport(error.code)
        } catch {
            if Task.isCancelled || error is CancellationError { throw CancellationError() }
            throw XtreamError.transport(.unknown)
        }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw XtreamError.badStatus(-1) }
        if http.statusCode == 401 || http.statusCode == 403 { throw XtreamError.unauthorized }
        guard (200..<300).contains(http.statusCode) else { throw XtreamError.badStatus(http.statusCode) }
        return data
    }

    /// Errors from `XtreamClient`. Values carry codes and coding paths only, never URLs, credentials
    /// or response bodies.
    public enum XtreamError: Error, Sendable, Equatable {
        case badStatus(Int)
        /// The server answered 401 or 403, or 200 with `user_info.auth` equal to 0.
        case unauthorized
        /// The request failed before a response arrived. Only the code is kept, not the failing URL.
        /// A failure that is not a `URLError` arrives as `.unknown`.
        case transport(URLError.Code)
        /// The body did not decode. `path` is the dotted coding path of the failure, such as
        /// `[3].stream_id`, and "" when the body itself has the wrong shape or is not JSON.
        case decoding(path: String)
    }
}

// MARK: - Wire models

/// A category row. `category_id` and `category_name` may each be a string or
/// a number. A row where either is missing or null does not decode, and the
/// category calls drop it.
public struct XtreamCategory: Decodable, Sendable, Hashable {
    public var categoryID: String
    public var categoryName: String
    /// The panel's `is_adult` flag on the category, which some panels send.
    public var isAdult: Bool

    enum CodingKeys: String, CodingKey { case categoryID = "category_id", categoryName = "category_name", isAdult = "is_adult" }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        categoryID = try c.decode(FlexibleString.self, forKey: .categoryID).value
        categoryName = try c.decode(FlexibleString.self, forKey: .categoryName).value
        isAdult = c.looseFlag(.isAdult)
    }
}

public struct XtreamLiveStream: Decodable, Sendable, Hashable {
    public var num: Int?
    public var name: String
    public var streamID: Int
    public var streamIcon: String?
    public var epgChannelID: String?
    public var categoryID: String?
    public var tvArchive: Int?
    public var tvArchiveDuration: Int?
    /// The stream's `is_adult` flag.
    public var isAdult: Bool

    enum CodingKeys: String, CodingKey {
        case num, name
        case streamID = "stream_id"
        case streamIcon = "stream_icon"
        case epgChannelID = "epg_channel_id"
        case categoryID = "category_id"
        case tvArchive = "tv_archive"
        case tvArchiveDuration = "tv_archive_duration"
        case isAdult = "is_adult"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        streamID = try c.decode(FlexibleInt.self, forKey: .streamID).value
        num = c.looseInt(.num)
        streamIcon = try? c.decodeIfPresent(String.self, forKey: .streamIcon)
        epgChannelID = (try? c.decodeIfPresent(FlexibleString.self, forKey: .epgChannelID))?.value
        categoryID = (try? c.decodeIfPresent(FlexibleString.self, forKey: .categoryID))?.value
        tvArchive = c.looseInt(.tvArchive)
        tvArchiveDuration = c.looseInt(.tvArchiveDuration)
        isAdult = c.looseFlag(.isAdult)
    }
}

public struct XtreamAccountInfo: Decodable, Sendable {
    public struct UserInfo: Decodable, Sendable {
        public var username: String?
        public var status: String?
        public var expDate: String?
        public var maxConnections: String?
        /// `user_info.auth` when it decodes to an integer, else nil. 0 never reaches callers:
        /// the client throws `XtreamError.unauthorized` instead.
        public var auth: Int?
        /// `user_info.allowed_output_formats` as sent, such as `["m3u8", "ts", "rtmp"]`. Nil when
        /// the panel sends none or neither a list nor text; text is split at commas.
        public var allowedOutputFormats: [String]?
        enum CodingKeys: String, CodingKey {
            case username, status, auth
            case expDate = "exp_date"
            case maxConnections = "max_connections"
            case allowedOutputFormats = "allowed_output_formats"
        }
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            username = try c.decodeIfPresent(String.self, forKey: .username)
            status = try c.decodeIfPresent(String.self, forKey: .status)
            expDate = try c.decodeIfPresent(FlexibleString.self, forKey: .expDate)?.value
            maxConnections = try c.decodeIfPresent(FlexibleString.self, forKey: .maxConnections)?.value
            auth = c.looseInt(.auth)
            if let list = try? c.decodeIfPresent([FlexibleString].self, forKey: .allowedOutputFormats) {
                allowedOutputFormats = list.map(\.value)
            } else if let text = try? c.decodeIfPresent(String.self, forKey: .allowedOutputFormats) {
                allowedOutputFormats = text.split(separator: ",").map(String.init)
            }
        }
    }
    /// `server_info`, nil when the panel sends none or it is not an object.
    public struct ServerInfo: Decodable, Sendable {
        /// The panel's time zone name, such as "Europe/Stockholm", as sent.
        public var timezone: String?
        enum CodingKeys: String, CodingKey { case timezone }
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            timezone = try? c.decodeIfPresent(String.self, forKey: .timezone)
        }
    }
    public var userInfo: UserInfo
    public var serverInfo: ServerInfo?
    enum CodingKeys: String, CodingKey {
        case userInfo = "user_info"
        case serverInfo = "server_info"
    }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userInfo = try c.decode(UserInfo.self, forKey: .userInfo)
        serverInfo = try? c.decodeIfPresent(ServerInfo.self, forKey: .serverInfo)
    }
}

/// Decodes a JSON number or numeric string into `Int` when its value is a whole number in range,
/// so `55`, `55.0`, `"55"` and `"55.0"` give 55. Anything else, `"55.7"` included, throws.
public struct FlexibleInt: Decodable, Sendable, Hashable {
    public var value: Int
    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { value = i; return }
        if let d = try? c.decode(Double.self), let i = Loose.int(d) { value = i; return }
        let s = try c.decode(String.self)
        guard let i = Loose.int(s) else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Not an int: \(s)")
        }
        value = i
    }
}

/// Decodes a value that may be a JSON number or string into `String`.
public struct FlexibleString: Decodable, Sendable, Hashable {
    public var value: String
    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s; return }
        if let i = try? c.decode(Int.self) { value = String(i); return }
        value = String(try c.decode(Double.self))
    }
}
