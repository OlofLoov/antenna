import Foundation

/// How a user-provided source is addressed. Credentials never live here;
/// they go in the Keychain and are referenced by `credentialKey`.
public enum SourceKind: String, Codable, Sendable, CaseIterable {
    case m3u
    case xtream
    case stalker
}

public struct SourceDescriptor: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var name: String
    public var kind: SourceKind
    /// For `.m3u` the playlist URL, for `.xtream`/`.stalker` the server base URL.
    public var url: URL
    public var epgURL: URL?
    /// Keychain lookup key for username/password or MAC.
    public var credentialKey: String?

    public init(
        id: UUID = UUID(),
        name: String,
        kind: SourceKind,
        url: URL,
        epgURL: URL? = nil,
        credentialKey: String? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.url = url
        self.epgURL = epgURL
        self.credentialKey = credentialKey
    }
}
