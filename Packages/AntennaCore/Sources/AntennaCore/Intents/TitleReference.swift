import Foundation

/// The text Siri and Shortcuts store for a movie or series (app-intents
/// capability): `"<source id>/<title id>"`, split at the first "/", where
/// the title id is a `vod` or `series` id such as `xtream#<host>#vod#<id>`,
/// or a playlist's `m3u.<16 hex>` movie or `m3u.series.<16 hex>` series id.
///
/// A title id holds the server's host and the provider's number, or a hash,
/// never a login or a playable address. The format never changes once shipped.
public struct TitleReference: Hashable, Sendable {
    public var sourceID: UUID
    /// The title's `ShelfTitle.id`.
    public var titleID: String

    public init(sourceID: UUID, titleID: String) {
        self.sourceID = sourceID
        self.titleID = titleID
    }

    /// The reference to `title`.
    public init(_ title: ShelfTitle) {
        self.init(sourceID: title.sourceID, titleID: title.id)
    }

    /// `"<source id>/<title id>"`, the source id in upper case.
    public var string: String {
        "\(sourceID.uuidString)/\(titleID)"
    }

    /// Movie or series, read from the title id.
    public var kind: ShelfTitle.Kind {
        if Self.isPlaylistSeries(titleID) { return .series }
        return XtreamTitleID(parsing: titleID)?.kind == .series ? .series : .movie
    }

    /// The key progress and My list use for this title.
    public var activityKey: ActivityKey {
        ActivityKey(titleID: titleID, sourceID: sourceID)
    }

    /// Nil unless `string` is a source id, a "/" and the id of a movie or a
    /// series. Live channel and episode ids are refused.
    public init?(parsing string: String) {
        guard let slash = string.firstIndex(of: "/"), let sourceID = UUID(uuidString: String(string[..<slash])) else { return nil }
        let titleID = String(string[string.index(after: slash)...])
        if Self.isPlaylistSeries(titleID) || Self.isPlaylistEntry(titleID) {
            self.init(sourceID: sourceID, titleID: titleID)
            return
        }
        guard let parsed = XtreamTitleID(parsing: titleID), parsed.kind == .vod || parsed.kind == .series else { return nil }
        self.init(sourceID: sourceID, titleID: titleID)
    }

    /// `m3u.series.` and 16 hex digits, a playlist series
    /// (m3u-playlists/playlist-titles-show-on-every-platform).
    private static func isPlaylistSeries(_ id: String) -> Bool {
        id.hasPrefix("m3u.series.") && isHex(id.dropFirst("m3u.series.".count))
    }

    /// `m3u.` and 16 hex digits, a playlist entry. A live channel or an
    /// episode has the same form, and is found by no title lookup.
    private static func isPlaylistEntry(_ id: String) -> Bool {
        id.hasPrefix("m3u.") && isHex(id.dropFirst("m3u.".count))
    }

    private static func isHex(_ digits: Substring) -> Bool {
        digits.count == 16 && digits.allSatisfy(\.isHexDigit)
    }

    /// True when `title` is the one this names.
    public func matches(_ title: ShelfTitle) -> Bool {
        title.sourceID == sourceID && title.id == titleID
    }
}
