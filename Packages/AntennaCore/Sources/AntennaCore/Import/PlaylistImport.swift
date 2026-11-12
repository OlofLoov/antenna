import Foundation

/// Checks a playlist file before it is imported, and turns stored file text
/// back into channels (local-m3u-file-import capability). The import sheet
/// and the loader share one parser and one filter, so Live lists exactly
/// the channels the summary counted.
public enum PlaylistImport {
    /// The largest file Antenna imports: 16 MB, about 50 000 entries.
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

    /// UTF-8, with a leading byte-order mark dropped and each invalid byte
    /// replaced by U+FFFD; UTF-16 when the file starts with its mark.
    public static func decode(_ data: Data) -> String {
        let bytes = [UInt8](data)
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { return String(decoding: bytes.dropFirst(3), as: UTF8.self) }
        if bytes.starts(with: [0xFF, 0xFE]) { return utf16(bytes.dropFirst(2), littleEndian: true) }
        if bytes.starts(with: [0xFE, 0xFF]) { return utf16(bytes.dropFirst(2), littleEndian: false) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func utf16(_ bytes: ArraySlice<UInt8>, littleEndian: Bool) -> String {
        var units: [UInt16] = []
        units.reserveCapacity(bytes.count / 2)
        var index = bytes.startIndex
        while index + 1 < bytes.endIndex {
            let first = UInt16(bytes[index])
            let second = UInt16(bytes[index + 1])
            units.append(littleEndian ? first | second << 8 : first << 8 | second)
            index += 2
        }
        return String(decoding: units, as: UTF16.self)
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
    /// from `stored`, the text as synced. Ids therefore never hold a login,
    /// and survive a re-import that keeps the placeholder token.
    public static func playlist(stored: String, restored: String) -> Playlist {
        let real = channels(from: restored).playlist
        guard stored != restored else { return real }
        let synced = channels(from: stored).playlist
        guard synced.channels.count == real.channels.count else { return real }
        var result = real
        for index in result.channels.indices {
            result.channels[index].id = synced.channels[index].id
        }
        return result
    }
}
