import Foundation

/// Which of a source's guides is meant. Never holds a link, so it can name
/// a guide in settings, caches and identifiers.
public enum GuideReference: Hashable, Sendable {
    /// The source's own guide: the Xtream provider's, the Stalker portal's,
    /// or the Jellyfin or Channels DVR server's.
    case provider
    /// The guide link saved with the source.
    case saved
    /// The n-th guide link the playlist header names, from 0.
    case playlist(Int)
    /// A link the user added, by its id.
    case added(String)

    /// "provider", "saved", "playlist.<n>" or "added.<id>".
    public var storageKey: String {
        switch self {
        case .provider: "provider"
        case .saved: "saved"
        case .playlist(let position): "playlist.\(position)"
        case .added(let id): "added.\(id)"
        }
    }

    public init?(storageKey: String) {
        switch storageKey {
        case "provider": self = .provider
        case "saved": self = .saved
        default:
            if storageKey.hasPrefix("playlist."), let position = Int(storageKey.dropFirst("playlist.".count)), position >= 0 {
                self = .playlist(position)
            } else if storageKey.hasPrefix("added."), storageKey.count > "added.".count {
                self = .added(String(storageKey.dropFirst("added.".count)))
            } else {
                return nil
            }
        }
    }

    /// Only links the user added can be removed; the others can be turned off.
    public var isRemovable: Bool {
        if case .added = self { return true }
        return false
    }
}

/// One guide in a source's list, in the user's order.
public struct GuideListEntry: Sendable, Equatable {
    public var reference: GuideReference
    public var enabled: Bool
    /// The link, for a guide that downloads one. Nil for the provider guide,
    /// whose address needs the login, and for an added link whose login is
    /// in the Keychain. May hold a login: never log, store or show it except
    /// through `redacted(_:)`.
    public var url: URL?

    public init(reference: GuideReference, enabled: Bool, url: URL? = nil) {
        self.reference = reference
        self.enabled = enabled
        self.url = url
    }
}

/// Works out a source's guides from what it knows, sending nothing over the
/// network (guide-data/find-the-guide-for-each-source).
public enum GuideList {
    /// True for the kinds that bring a guide of their own.
    public static func hasProviderGuide(_ kind: SourceKind) -> Bool {
        switch kind {
        case .xtream, .stalker, .jellyfin, .channelsDVR: true
        case .m3u, .m3uFile: false
        }
    }

    /// The source's guides: by default the playlist's header links, the saved
    /// link, the provider guide, then added links oldest first, each link
    /// once. `settings.order` moves the guides it names to the top in its
    /// order. The provider guide starts turned off when a link was saved.
    /// `addedLinks` gives the whole link of an added guide whose link is in
    /// the Keychain, when this device has it. `panelGuide` is the Xtream
    /// panel's guide of a playlist added from a panel link: it is the
    /// playlist's provider guide, turned on only when there is no saved link
    /// and no header link (guide-data/a-panel-playlist-falls-back-to-the-panel-s-guide).
    public static func resolve(
        kind: SourceKind, savedURL: URL?, playlistLinks: [URL], settings: GuideSettings, addedLinks: [String: URL] = [:],
        panelGuide: URL? = nil
    ) -> [GuideListEntry] {
        var seen = Set<String>()
        var defaults: [GuideListEntry] = []
        func add(_ reference: GuideReference, url: URL?, enabled: Bool = true) {
            if let url {
                guard seen.insert(url.absoluteString).inserted else { return }
            }
            defaults.append(GuideListEntry(reference: reference, enabled: enabled, url: url))
        }
        for (position, link) in playlistLinks.enumerated() {
            add(.playlist(position), url: link)
        }
        if let savedURL { add(.saved, url: savedURL) }
        if hasProviderGuide(kind) {
            add(.provider, url: nil, enabled: savedURL == nil)
        } else if kind == .m3u, let panelGuide {
            add(.provider, url: panelGuide, enabled: savedURL == nil && playlistLinks.isEmpty)
        }
        for (id, link) in settings.activeLinks {
            add(.added(id), url: link.plain ?? addedLinks[id])
        }

        var position: [String: Int] = [:]
        for (place, key) in zip(settings.order.indices, settings.order) where position[key] == nil {
            position[key] = place
        }
        let ordered = defaults.enumerated().sorted { lhs, rhs in
            let left = position[lhs.element.reference.storageKey] ?? Int.max
            let right = position[rhs.element.reference.storageKey] ?? Int.max
            return (left, lhs.offset) < (right, rhs.offset)
        }
        return ordered.map { _, entry in
            var entry = entry
            if let flag = settings.flags[entry.reference.storageKey] { entry.enabled = flag.enabled }
            return entry
        }
    }
}
