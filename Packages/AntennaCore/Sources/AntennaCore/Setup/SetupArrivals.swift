import Foundation

/// Decides which source counts as sent from the iPhone while the Apple TV
/// shows its QR card (iphone-as-setup-device/a-playlist-source-sent-from-the-iphone-starts-loading-on-the-tv).
/// Sources present when the card appeared never count, nor sources created
/// more than `window` before it appeared, nor sources without an address.
public struct SetupArrivals: Sendable {
    /// One stored source as the TV sees it, with its kind as stored, so a
    /// kind this build does not know is not mistaken for a playlist.
    public struct Candidate: Sendable, Equatable {
        public var id: UUID
        public var kind: String
        public var hasAddress: Bool
        public var createdAt: Date

        public init(id: UUID, kind: String, hasAddress: Bool, createdAt: Date) {
            self.id = id
            self.kind = kind
            self.hasAddress = hasAddress
            self.createdAt = createdAt
        }
    }

    /// A source the card can use.
    public enum Arrival: Sendable, Equatable {
        /// A playlist link: the TV goes on to loading it.
        case playlist(UUID)
        /// An Xtream source, Stalker portal or Jellyfin server: the TV asks for
        /// the login or MAC address, which did not sync.
        case login(UUID, SourceKind)
    }

    /// How far before the card appeared a source may have been created,
    /// allowing for clock drift between the devices.
    public static let window: TimeInterval = 300

    private let present: Set<UUID>
    private let earliest: Date
    /// True once a new source arrived that the card cannot set up.
    public private(set) var sawUnusable = false

    /// `present` holds the ids stored when the card appeared at `shownAt`.
    public init(present: Set<UUID>, shownAt: Date) {
        self.present = present
        self.earliest = shownAt.addingTimeInterval(-Self.window)
    }

    /// The first new usable source among `candidates`, by creation time.
    /// Notes a new source of a kind the card cannot set up.
    public mutating func check(_ candidates: [Candidate]) -> Arrival? {
        let new = candidates.filter { !present.contains($0.id) && $0.createdAt >= earliest && $0.hasAddress }
            .sorted { $0.createdAt < $1.createdAt }
        for candidate in new {
            guard let kind = SourceKind(rawValue: candidate.kind) else {
                sawUnusable = true
                continue
            }
            switch kind {
            case .m3u: return .playlist(candidate.id)
            case .xtream, .stalker, .jellyfin: return .login(candidate.id, kind)
            case .m3uFile: sawUnusable = true
            }
        }
        return nil
    }
}
