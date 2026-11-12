import Foundation

extension JellyfinClient {
    /// Channels asked for per page.
    public static let channelPageSize = 1000
    /// Pages asked for at most, so a list stops at 100 000 channels
    /// (jellyfin-live-tv-source/every-channel-loads-however-many-there-are).
    public static let maxPages = 100

    /// Every Live TV channel in the server's order, page by page, stopping
    /// at the reported total, a short page or `maxPages`. Rows dropped as
    /// broken or listed twice are counted in `skipped`. Stream addresses
    /// carry the key the list finished with.
    public func liveChannels() async throws -> DecodedList<Channel> {
        var signed = try await Signed(self)
        var rows: [JellyfinChannel] = []
        var seen = Set<String>()
        var skipped = 0
        for page in 0..<Self.maxPages {
            let start = page * Self.channelPageSize
            let data = try await signed.send { session in
                request(
                    path: "LiveTv/Channels",
                    query: [
                        URLQueryItem(name: "UserId", value: session.userID), URLQueryItem(name: "StartIndex", value: String(start)),
                        URLQueryItem(name: "Limit", value: String(Self.channelPageSize)),
                        URLQueryItem(name: "EnableImageTypes", value: "Primary"), URLQueryItem(name: "ImageTypeLimit", value: "1"),
                        URLQueryItem(name: "EnableUserData", value: "false"), URLQueryItem(name: "AddCurrentProgram", value: "false"),
                    ],
                    token: session.token)
            }
            let (list, total) = try Self.decodeChannels(data)
            skipped += list.skipped
            for row in list.items {
                if seen.insert(row.id).inserted { rows.append(row) } else { skipped += 1 }
            }
            let count = list.items.count + list.skipped
            if count < Self.channelPageSize { break }
            if let total, start + count >= total { break }
        }
        let token = signed.session.token
        return DecodedList(items: rows.map { channel(from: $0, token: token) }, skipped: skipped)
    }

    /// One page of `/LiveTv/Channels` and the reported `TotalRecordCount`.
    /// A row that is not an object, lacks an `Id` or a `Name`, or repeats an
    /// earlier row's id is skipped and counted. An empty body is an empty
    /// page. A web page, or an answer without an `Items` list, is a reading
    /// error.
    public static func decodeChannels(_ data: Data) throws -> (DecodedList<JellyfinChannel>, total: Int?) {
        guard !JellyfinWire.isBlank(data) else { return (DecodedList(items: [], skipped: 0), 0) }
        let (rows, total) = try JellyfinWire.items(data)
        var channels: [JellyfinChannel] = []
        channels.reserveCapacity(rows.count)
        var seen = Set<String>()
        var skipped = 0
        for row in rows {
            guard let object = row as? [String: Any], let id = JellyfinWire.string(object["Id"]), !id.isEmpty,
                let name = JellyfinWire.string(object["Name"])?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty,
                seen.insert(id).inserted
            else {
                skipped += 1
                continue
            }
            channels.append(
                JellyfinChannel(
                    id: id, name: name, number: JellyfinWire.wholeNumber(object["ChannelNumber"]),
                    isRadio: JellyfinWire.string(object["ChannelType"]) == "Radio",
                    primaryImageTag: JellyfinWire.primaryTag(object)))
        }
        return (DecodedList(items: channels, skipped: skipped), total)
    }

    /// The catalogue channel for `row`: its name, whole number, the group
    /// "Radio" for a radio channel and none otherwise, a key-free logo, no
    /// catch-up, and an id built from the server's host alone
    /// (jellyfin-live-tv-source/channels-show-their-name-number-and-logo).
    /// The guide matches it by the server's channel id.
    public func channel(from row: JellyfinChannel, token: String) -> Channel {
        Channel(
            id: "jellyfin#\(credentials.host)#\(row.id)",
            name: row.name,
            streamURL: streamURL(channelID: row.id, token: token),
            group: row.isRadio ? "Radio" : nil,
            logoURL: row.primaryImageTag.map { logoURL(channelID: row.id, tag: $0) },
            epgID: row.id,
            number: row.number)
    }

    /// `/Videos/<id>/stream?static=true&api_key=<key>`. It has no file
    /// extension, so it plays through the MPEG-TS route. It holds the key:
    /// never store or log it
    /// (jellyfin-live-tv-source/streams-play-and-logos-stay-key-free).
    public func streamURL(channelID: String, token: String) -> URL {
        url(
            path: "Videos/\(XtreamClient.percentEncode(channelID))/stream",
            query: [URLQueryItem(name: "static", value: "true"), URLQueryItem(name: "api_key", value: token)])
    }

    /// `/Items/<id>/Images/Primary?tag=<tag>`, with no key.
    public func logoURL(channelID: String, tag: String) -> URL {
        Self.imageURL(server: credentials.server, itemID: channelID, tag: tag)
    }

    static func imageURL(server: URL, itemID: String, tag: String) -> URL {
        url(
            server: server, path: "Items/\(XtreamClient.percentEncode(itemID))/Images/Primary",
            query: [URLQueryItem(name: "tag", value: tag)])
    }
}
