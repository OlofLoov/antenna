import Foundation

/// The id of a Top Shelf tile, derived from a channel or title and never
/// stored by the app. The snapshot carries it in place of the channel or
/// title id, which can hold a link with a login (top-shelf/no-passwords-or-links-leave-the-app).
public enum TopShelfItemID {
    /// The namespace of every Top Shelf item id.
    static let namespace = UUID(
        uuid: (0x6E, 0x0C, 0x2B, 0x1A, 0x7F, 0x4D, 0x4E, 0x55, 0x9B, 0x8A, 0x3D, 0x2C, 0x1E, 0x0F, 0x9A, 0x47))

    /// A version 5 UUID over the source and the SHA-256 of the channel or
    /// title id. The same source and id always give the same item id, on
    /// every launch and device.
    public static func make(sourceID: UUID, id: String) -> UUID {
        let hidden = Digest.hex(Digest.sha256(Array(id.utf8))).lowercased()
        return UUID(version5: "\(sourceID.uuidString.lowercased())/\(hidden)", namespace: namespace)
    }

    /// The item id of a channel; nil for a channel with no source.
    public static func channel(_ channel: Channel) -> UUID? {
        channel.sourceID.map { make(sourceID: $0, id: channel.id) }
    }

    /// The item id of a movie or series.
    public static func title(_ title: ShelfTitle) -> UUID {
        make(sourceID: title.sourceID, id: title.id)
    }
}

/// What a Top Shelf tile opens: `antenna://topShelf/<item id>` for a channel
/// or title, `antenna://topShelf/empty` for the add-favorites tile.
public enum TopShelfLink: Hashable, Sendable {
    case item(UUID)
    case empty

    public static let scheme = "antenna"
    static let host = "topShelf"
    static let emptyPath = "empty"

    /// Nil for any URL that is not a well-formed shelf link, so a damaged
    /// link opens Antenna as it was (top-shelf/a-tile-that-no-longer-matches-opens-antenna-as-it-was).
    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme, url.host() == Self.host, url.query() == nil, url.fragment() == nil
        else { return nil }
        let parts = url.path().split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count == 1 else { return nil }
        let part = String(parts[0])
        if part == Self.emptyPath {
            self = .empty
        } else if let id = UUID(uuidString: part) {
            self = .item(id)
        } else {
            return nil
        }
    }

    /// The URL the tile opens.
    public var url: URL {
        let path =
            switch self {
            case .item(let id): id.uuidString.lowercased()
            case .empty: Self.emptyPath
            }
        return URL(string: "\(Self.scheme)://\(Self.host)/\(path)") ?? URL(fileURLWithPath: "/")
    }
}
