import Foundation

/// A playable live channel from any source kind (M3U, Xtream, Stalker).
public struct Channel: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var name: String
    public var streamURL: URL
    public var group: String?
    public var logoURL: URL?
    /// XMLTV channel id (`tvg-id`) used to attach guide data.
    public var epgID: String?
    public var number: Int?
    public var hasCatchup: Bool
    /// Catch-up window in days, when the source advertises one.
    public var catchupDays: Int?
    /// How the provider wants catch-up asked for. Kept in memory only:
    /// encoding a channel leaves it out.
    public var catchupMode: CatchupMode?
    /// The playlist's catch-up template. It can hold the login, so it is
    /// kept in memory only and never logged.
    public var catchupSource: String?
    /// Hours the playlist says to shift catch-up date parts by. Kept in
    /// memory only.
    public var catchupCorrectionHours: Double?
    /// The `SourceRecord.id` this channel was loaded from. Nil until
    /// `Channel.tagged(_:sourceID:)` runs; the catalogue drops untagged channels.
    public var sourceID: UUID?
    /// 0-based index in the source's channel list, set with `sourceID`.
    public var position: Int?

    public init(
        id: String,
        name: String,
        streamURL: URL,
        group: String? = nil,
        logoURL: URL? = nil,
        epgID: String? = nil,
        number: Int? = nil,
        hasCatchup: Bool = false,
        catchupDays: Int? = nil,
        catchupMode: CatchupMode? = nil,
        catchupSource: String? = nil,
        catchupCorrectionHours: Double? = nil,
        sourceID: UUID? = nil,
        position: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.streamURL = streamURL
        self.group = group
        self.logoURL = logoURL
        self.epgID = epgID
        self.number = number
        self.hasCatchup = hasCatchup
        self.catchupDays = catchupDays
        self.catchupMode = catchupMode
        self.catchupSource = catchupSource
        self.catchupCorrectionHours = catchupCorrectionHours
        self.sourceID = sourceID
        self.position = position
    }

    /// The catch-up mode, template and correction are left out, so nothing
    /// that encodes a channel keeps them
    /// (timeshift-catch-up-and-start-over/logins-stay-private).
    enum CodingKeys: String, CodingKey {
        case id, name, streamURL, group, logoURL, epgID, number, hasCatchup, catchupDays, sourceID, position
    }
}
