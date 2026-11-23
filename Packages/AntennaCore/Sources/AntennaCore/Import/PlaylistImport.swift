import Foundation

/// Checks a playlist file before it is imported, and turns stored file text
/// back into channels (local-m3u-file-import capability). The import sheet
/// and the loader share one parser and one filter, so Live lists exactly
/// the channels the summary counted.
public enum PlaylistImport {
    /// The largest file Antuna imports: 16 MB, about 50 000 entries.
    public static let maximumBytes = 16_000_000

    /// What a file holds, decided by its contents and never by its name.
    public enum Outcome: Equatable, Sendable {
        /// More than `maximumBytes`; `bytes` is nil when the size was not known.
        case tooLarge(bytes: Int?)
        /// One HLS stream rather than a channel list.
        case hlsStream
        /// Plain links, one per line, in file order.
        case linkList([URL])
        /// Nothing that plays. `sawEntries` is true only when the file had
        /// `#EXTINF` entries whose links all lacked a scheme.
        case noChannels(sawEntries: Bool)
        case playlist(Inspected)
    }

    /// A file that holds channels: its decoded text, what it lists and how
    /// many entries were left out because their link has no scheme.
    public struct Inspected: Equatable, Sendable {
        public var text: String
        public var playlist: Playlist
        public var skipped: Int

        public init(text: String, playlist: Playlist, skipped: Int) {
            self.text = text
            self.playlist = playlist
            self.skipped = skipped
        }
    }

    /// Runs the checks in order (too large, decode, single stream, link
    /// list, channel list); the first that applies decides.
    public static func inspect(_ data: Data) -> Outcome {
        if isTooLarge(data.count) { return .tooLarge(bytes: data.count) }
        let text = decode(data)
        var sawExtInf = false
        var links: [URL] = []
        var onlyLinks = true
        for raw in text.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if hlsTags.contains(where: line.hasPrefix) { return .hlsStream }
            if line.hasPrefix("#EXTINF") { sawExtInf = true }
            if line.hasPrefix("#") || !onlyLinks { continue }
            if let url = webLink(line) {
                links.append(url)
            } else {
                onlyLinks = false
            }
        }
        if !sawExtInf, onlyLinks, !links.isEmpty { return .linkList(links) }
        let (playlist, skipped) = channels(from: text)
        if playlist.channels.isEmpty { return .noChannels(sawEntries: skipped > 0) }
        return .playlist(Inspected(text: text, playlist: playlist, skipped: skipped))
    }

    /// True above `maximumBytes`; a file of exactly that size is imported.
    public static func isTooLarge(_ bytes: Int) -> Bool {
        bytes > maximumBytes
    }

    /// `line` as an absolute `http` or `https` link with a host.
    private static func webLink(_ line: String) -> URL? {
        guard let url = URL(string: line), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        return url.host() == nil ? nil : url
    }

    /// Tags that only a single HLS stream carries.
    static let hlsTags = ["#EXT-X-TARGETDURATION", "#EXT-X-MEDIA-SEQUENCE", "#EXT-X-STREAM-INF"]

    /// The file's text, read as `TextEncoding.text` reads it.
    public static func decode(_ data: Data) -> String {
        TextEncoding.text(data)
    }

    /// The channels in `text` whose link has a scheme, and how many entries
    /// were skipped for having none.
    public static func channels(from text: String) -> (playlist: Playlist, skipped: Int) {
        var playlist = M3UParser().parse(text)
        let count = playlist.channels.count
        playlist.channels.removeAll { $0.streamURL.scheme == nil }
        return (playlist, count - playlist.channels.count)
    }

    /// The channels of a stored file: links, logos and guide links from
    /// `restored`, the text with its logins put back, and each channel's id
    /// and earlier id from `stored`, the text as synced, which is the text
    /// earlier versions built file ids from
    /// (m3u-playlists/earlier-ids-map-to-the-new-ones).
    public static func playlist(stored: String, restored: String) -> Playlist {
        let real = channels(from: restored).playlist
        guard stored != restored else { return real }
        let synced = channels(from: stored).playlist
        guard synced.channels.count == real.channels.count else { return real }
        var result = real
        for index in result.channels.indices {
            result.channels[index].id = synced.channels[index].id
        }
        result.formerIDs = synced.formerIDs
        return result
    }
}
