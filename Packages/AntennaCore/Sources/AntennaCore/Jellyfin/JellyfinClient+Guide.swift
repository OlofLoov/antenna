import Foundation

extension JellyfinClient {
    /// Channels per guide request.
    public static let guideBatchSize = 50
    /// Programmes asked for per page of one batch.
    public static let guidePageSize = 10_000

    /// Every programme that overlaps `window` for `channelIDs`, the server's
    /// channel ids, one already on air included
    /// (jellyfin-live-tv-source/the-guide-covers-the-coming-week). Channels
    /// go in batches of `guideBatchSize`, and each batch's pages are
    /// followed. `progress` hears the batches done and the batch count
    /// after each batch. No channels sends nothing. A programme listed
    /// twice is skipped and counted.
    public func programmes(
        channelIDs: [String], in window: DateInterval, progress: @Sendable (_ done: Int, _ total: Int) -> Void = { _, _ in }
    ) async throws -> DecodedList<Programme> {
        guard !channelIDs.isEmpty else { return DecodedList(items: [], skipped: 0) }
        var signed = try await Signed(self)
        let batches = stride(from: 0, to: channelIDs.count, by: Self.guideBatchSize).map {
            Array(channelIDs[$0..<min($0 + Self.guideBatchSize, channelIDs.count)])
        }
        var items: [Programme] = []
        var seen = Set<String>()
        var skipped = 0
        for (number, batch) in batches.enumerated() {
            for page in 0..<Self.maxPages {
                let start = page * Self.guidePageSize
                let data = try await signed.send { session in
                    try programmesRequest(batch, window: window, start: start, session: session)
                }
                let read = try Self.decodeProgrammePage(data, server: credentials.server)
                skipped += read.list.skipped
                for row in read.list.items {
                    if let id = row.id, !seen.insert(id).inserted {
                        skipped += 1
                    } else {
                        items.append(row.programme)
                    }
                }
                let count = read.list.items.count + read.list.skipped
                if count < Self.guidePageSize { break }
                if let total = read.total, start + count >= total { break }
            }
            progress(number + 1, batches.count)
        }
        return DecodedList(items: items, skipped: skipped)
    }

    /// `POST /LiveTv/Programs` for one batch, asking for programmes that end
    /// after the window starts and start before it ends.
    func programmesRequest(_ channelIDs: [String], window: DateInterval, start: Int, session: JellyfinSession) throws -> URLRequest {
        var request = request(path: "LiveTv/Programs", token: session.token)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "ChannelIds": channelIDs, "UserId": session.userID,
            "MinEndDate": window.start.formatted(.iso8601), "MaxStartDate": window.end.formatted(.iso8601),
            "StartIndex": start, "Limit": Self.guidePageSize, "Fields": ["Overview", "Genres"],
            "EnableImageTypes": ["Primary"], "ImageTypeLimit": 1, "EnableUserData": false, "EnableTotalRecordCount": true,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return request
    }

    /// One page of `/LiveTv/Programs`. Each programme's channel id is the
    /// server's channel id, which is the catalogue channel's guide id. A row
    /// without a channel or a title, with an unreadable date, or that ends
    /// before it starts is skipped and counted. An empty body is an empty
    /// list; a web page or an answer without an `Items` list is a reading
    /// error. The picture comes from `server` and holds no key.
    public static func decodeProgrammes(_ data: Data, server: URL) throws -> DecodedList<Programme> {
        let read = try decodeProgrammePage(data, server: server)
        return DecodedList(items: read.list.items.map(\.programme), skipped: read.list.skipped)
    }

    struct ProgrammeRow: Sendable, Hashable {
        var programme: Programme
        /// The programme's own id, used to drop one listed twice.
        var id: String?
    }

    static func decodeProgrammePage(_ data: Data, server: URL) throws -> (list: DecodedList<ProgrammeRow>, total: Int?) {
        guard !JellyfinWire.isBlank(data) else { return (DecodedList(items: [], skipped: 0), 0) }
        let (rows, total) = try JellyfinWire.items(data)
        var programmes: [ProgrammeRow] = []
        programmes.reserveCapacity(rows.count)
        var skipped = 0
        for row in rows {
            guard let object = row as? [String: Any],
                let channel = JellyfinWire.string(object["ChannelId"]), !channel.isEmpty,
                let title = JellyfinWire.string(object["Name"]), !title.isEmpty,
                let start = (object["StartDate"] as? String).flatMap(JellyfinWire.date),
                let stop = (object["EndDate"] as? String).flatMap(JellyfinWire.date), start < stop
            else {
                skipped += 1
                continue
            }
            let id = JellyfinWire.string(object["Id"]).flatMap { $0.isEmpty ? nil : $0 }
            let icon = id.flatMap { id in JellyfinWire.primaryTag(object).map { imageURL(server: server, itemID: id, tag: $0) } }
            let programme = Programme(
                channelID: channel, start: start, stop: stop, title: title,
                subtitle: JellyfinWire.text(object["EpisodeTitle"]), summary: JellyfinWire.text(object["Overview"]),
                category: (object["Genres"] as? [Any])?.lazy.compactMap { JellyfinWire.text($0) }.first, iconURL: icon)
            programmes.append(ProgrammeRow(programme: programme, id: id))
        }
        return (DecodedList(items: programmes, skipped: skipped), total)
    }
}
