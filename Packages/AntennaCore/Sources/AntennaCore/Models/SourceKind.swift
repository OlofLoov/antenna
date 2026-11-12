import Foundation

/// How a user-provided source is addressed. Credentials never live here;
/// they go in the Keychain and are referenced by `credentialKey`.
public enum SourceKind: String, Codable, Sendable, CaseIterable {
    case m3u
    case xtream
    case stalker
    /// A playlist file imported once, whose text syncs with the record
    /// (local-m3u-file-import capability). It has no link of its own.
    case m3uFile
}

public struct SourceDescriptor: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var name: String
    public var kind: SourceKind
    /// For `.m3u` the playlist URL, for `.xtream`/`.stalker` the server base
    /// URL. For `.m3uFile` an `antenna-file:` stand-in that changes with
    /// each import, so a re-import loads again.
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
