import Foundation

/// Minimal Xtream Codes `player_api.php` client.
///
/// Xtream servers are notoriously loose with JSON types (ids arrive as strings
/// or numbers depending on panel), hence the `Flexible*` wrappers.
public struct XtreamCredentials: Sendable, Hashable {
    public var server: URL
    public var username: String
    public var password: String

    public init(server: URL, username: String, password: String) {
        self.server = server
        self.username = username
        self.password = password
    }
}

public struct XtreamClient: Sendable {
    public enum StreamContainer: String, Sendable { case ts, m3u8 }

    private let credentials: XtreamCredentials
    private let session: URLSession

    public init(credentials: XtreamCredentials, session: URLSession = .shared) {
        self.credentials = credentials
        self.session = session
    }

    // MARK: Endpoints

    public func liveCategories() async throws -> [XtreamCategory] {
        try await get(action: "get_live_categories")
    }

    public func liveStreams(categoryID: String? = nil) async throws -> [XtreamLiveStream] {
        var items = [URLQueryItem]()
        if let categoryID { items.append(.init(name: "category_id", value: categoryID)) }
        return try await get(action: "get_live_streams", extra: items)
    }

    public func accountInfo() async throws -> XtreamAccountInfo {
        try await get(action: nil)
    }

    // MARK: URL building

    public func streamURL(for stream: XtreamLiveStream, container: StreamContainer = .ts) -> URL {
        credentials.server
            .appending(path: "live")
            .appending(path: credentials.username)
            .appending(path: credentials.password)
            .appending(path: "\(stream.streamID).\(container.rawValue)")
    }

    public func xmltvURL() -> URL {
        var comps = URLComponents(url: credentials.server.appending(path: "xmltv.php"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "username", value: credentials.username),
            .init(name: "password", value: credentials.password),
        ]
        return comps.url!
    }

    /// Maps an Xtream live stream onto the app's `Channel` model.
    public func channel(from stream: XtreamLiveStream, categoryName: String?) -> Channel {
        Channel(
            id: "xtream#\(credentials.server.host() ?? "")#\(stream.streamID)",
            name: stream.name,
            streamURL: streamURL(for: stream),
            group: categoryName,
            logoURL: stream.streamIcon.flatMap(URL.init(string:)),
            epgID: stream.epgChannelID?.isEmpty == false ? stream.epgChannelID : nil,
            number: stream.num,
            hasCatchup: (stream.tvArchive ?? 0) > 0,
            catchupDays: stream.tvArchiveDuration
        )
    }

    // MARK: Internals

    private func get<T: Decodable>(action: String?, extra: [URLQueryItem] = []) async throws -> T {
        var comps = URLComponents(url: credentials.server.appending(path: "player_api.php"), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [
            .init(name: "username", value: credentials.username),
            .init(name: "password", value: credentials.password),
        ]
        if let action { items.append(.init(name: "action", value: action)) }
        comps.queryItems = items + extra
        let (data, response) = try await session.data(from: comps.url!)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw XtreamError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    public enum XtreamError: Error, Sendable {
        case badStatus(Int)
    }
}

// MARK: - Wire models

public struct XtreamCategory: Decodable, Sendable, Hashable {
    public var categoryID: String
    public var categoryName: String

    enum CodingKeys: String, CodingKey { case categoryID = "category_id", categoryName = "category_name" }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        categoryID = try c.decode(FlexibleString.self, forKey: .categoryID).value
        categoryName = try c.decode(String.self, forKey: .categoryName)
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

    enum CodingKeys: String, CodingKey {
        case num, name
        case streamID = "stream_id"
        case streamIcon = "stream_icon"
        case epgChannelID = "epg_channel_id"
        case categoryID = "category_id"
        case tvArchive = "tv_archive"
        case tvArchiveDuration = "tv_archive_duration"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        num = try c.decodeIfPresent(FlexibleInt.self, forKey: .num)?.value
        name = try c.decode(String.self, forKey: .name)
        streamID = try c.decode(FlexibleInt.self, forKey: .streamID).value
        streamIcon = try c.decodeIfPresent(String.self, forKey: .streamIcon)
        epgChannelID = try c.decodeIfPresent(String.self, forKey: .epgChannelID)
        categoryID = try c.decodeIfPresent(FlexibleString.self, forKey: .categoryID)?.value
        tvArchive = try c.decodeIfPresent(FlexibleInt.self, forKey: .tvArchive)?.value
        tvArchiveDuration = try c.decodeIfPresent(FlexibleInt.self, forKey: .tvArchiveDuration)?.value
    }
}

public struct XtreamAccountInfo: Decodable, Sendable {
    public struct UserInfo: Decodable, Sendable {
        public var username: String?
        public var status: String?
        public var expDate: String?
        public var maxConnections: String?
        enum CodingKeys: String, CodingKey {
            case username, status
            case expDate = "exp_date"
            case maxConnections = "max_connections"
        }
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            username = try c.decodeIfPresent(String.self, forKey: .username)
            status = try c.decodeIfPresent(String.self, forKey: .status)
            expDate = try c.decodeIfPresent(FlexibleString.self, forKey: .expDate)?.value
            maxConnections = try c.decodeIfPresent(FlexibleString.self, forKey: .maxConnections)?.value
        }
    }
    public var userInfo: UserInfo
    enum CodingKeys: String, CodingKey { case userInfo = "user_info" }
}

/// Decodes a value that may be a JSON number or string into `Int`.
public struct FlexibleInt: Decodable, Sendable, Hashable {
    public var value: Int
    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { value = i; return }
        if let d = try? c.decode(Double.self) { value = Int(d); return }
        let s = try c.decode(String.self)
        guard let i = Int(s) ?? Double(s).map(Int.init) else {
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
