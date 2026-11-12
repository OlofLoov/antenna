import Foundation

/// What the guide needs to know about a source, mapped by the app from its
/// stored record. `url` may hold a login (an M3U link with a password in its
/// query), so it is never logged, persisted or used in a file name.
public struct GuideSourceDescriptor: Sendable, Equatable {
    public var sourceID: UUID
    public var kind: SourceKind
    public var url: URL
    public var epgURL: URL?
    public var credentialKey: String?
    public var sortOrder: Int
    /// The user's guide order, on and off flags, added links and matches.
    public var settings: GuideSettings

    public init(
        sourceID: UUID, kind: SourceKind, url: URL, epgURL: URL? = nil, credentialKey: String? = nil, sortOrder: Int = 0,
        settings: GuideSettings = .empty
    ) {
        self.sourceID = sourceID
        self.kind = kind
        self.url = url
        self.epgURL = epgURL
        self.credentialKey = credentialKey
        self.sortOrder = sortOrder
        self.settings = settings
    }
}

/// The result of reading a source's login, so a login that has not synced yet
/// can be told apart from one the Keychain cannot read.
public enum GuideCredentialLookup: Sendable {
    case found(username: String, password: String)
    case missing
    case unreadable
}
