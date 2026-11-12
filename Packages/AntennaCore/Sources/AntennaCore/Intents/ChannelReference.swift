import Foundation

/// The text Siri and Shortcuts store for a channel (app-intents capability):
/// `"<source id>/<channel id>"`, split at the first "/".
///
/// Shortcuts keeps these in the user's library and syncs them through
/// iCloud, so the format never changes once shipped and parsing keeps
/// accepting every format ever shipped.
extension LastChannelKey {
    /// `"<source id>/<channel id>"`, the source id in upper case as
    /// `UUID.uuidString` writes it.
    public var string: String {
        "\(sourceID.uuidString)/\(channelID)"
    }

    /// Nil unless `string` is a source id, a "/" and a non-empty channel id
    /// that holds no stream link (app-intents/shortcuts-never-hold-a-password).
    /// The source id may be in either case.
    public init?(parsing string: String) {
        guard let slash = string.firstIndex(of: "/"), let sourceID = UUID(uuidString: String(string[..<slash])) else { return nil }
        let channelID = String(string[string.index(after: slash)...])
        guard !channelID.isEmpty, Self.canStore(channelID) else { return nil }
        self.init(sourceID: sourceID, channelID: channelID)
    }
}

extension Catalogue {
    /// The one loaded channel with `key`'s source and id, locked or not;
    /// nil when there is none or more than one. `isLocked(_:)` on its row
    /// says whether it may play.
    public func channel(for key: LastChannelKey) -> Channel? {
        row(for: key).flatMap(channel(for:))
    }

    /// The row of the one loaded channel with `key`'s source and id; nil
    /// when there is none or more than one.
    public func row(for key: LastChannelKey) -> RowKey? {
        let entries = (index.indicesByID[key.channelID] ?? []).filter { index.keys[$0].sourceID == key.sourceID }
        return entries.count == 1 ? index.keys[entries[0]] : nil
    }
}
