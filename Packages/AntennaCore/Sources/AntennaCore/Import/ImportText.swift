import Foundation

/// What the import sheet says about a file, from the change's copy tables.
/// Counts use `locale`'s grouping separator; sizes read like Finder's.
public struct ImportText: Sendable {
    public var locale: Locale

    public init(locale: Locale = .current) {
        self.locale = locale
    }

    /// A refused file's title and the line beneath it, if any.
    public struct Problem: Equatable, Sendable {
        public var title: String
        public var body: String?

        public init(title: String, body: String? = nil) {
            self.title = title
            self.body = body
        }
    }

    /// The channel list's summary rows.
    public struct Summary: Equatable, Sendable {
        /// "412 channels in 18 groups".
        public var channels: String
        /// The first eight group names, then "and <k> more".
        public var groups: String?
        /// The first header guide link's host, nil when the header names none.
        public var guideHost: String?
        /// "3 entries skipped", nil when none were.
        public var skipped: String?
    }

    /// "41.7 MB".
    public func size(_ bytes: Int) -> String {
        Int64(bytes).formatted(ByteCountFormatStyle(style: .file).locale(locale))
    }

    private func count(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }

    public func summary(_ inspected: PlaylistImport.Inspected) -> Summary {
        let playlist = inspected.playlist
        let groups = playlist.groups
        let channels = playlist.channels.count == 1 ? "1 channel" : "\(count(playlist.channels.count)) channels"
        let groupWord = groups.count == 1 ? "1 group" : "\(count(groups.count)) groups"
        var names: String?
        if !groups.isEmpty {
            names = groups.prefix(8).joined(separator: ", ")
            if groups.count > 8 { names = (names ?? "") + " and \(count(groups.count - 8)) more" }
        }
        let skipped = inspected.skipped == 1 ? "1 entry skipped" : "\(count(inspected.skipped)) entries skipped"
        return Summary(
            channels: "\(channels) in \(groupWord)", groups: names, guideHost: playlist.epgURLs.first?.host(),
            skipped: inspected.skipped > 0 ? skipped : nil)
    }

    /// Why a file cannot be imported, nil for a channel list.
    public func problem(_ outcome: PlaylistImport.Outcome, fileName: String) -> Problem? {
        let split = "Split the file, or host it and add the link as an M3U source instead."
        switch outcome {
        case .tooLarge(let bytes?):
            return Problem(title: "This file is \(size(bytes)). Antenna imports playlists up to 16 MB.", body: split)
        case .tooLarge(nil):
            return Problem(title: "This file is larger than 16 MB. Antenna imports playlists up to 16 MB.", body: split)
        case .noChannels(let sawEntries):
            return Problem(
                title: "No channels found in \(fileName).",
                body: sawEntries
                    ? "The entries in this file are not links."
                    : "Antenna reads M3U playlists: #EXTINF lines, each followed by a stream link. This file has no such pair.")
        case .linkList(let links) where links.count == 1:
            return Problem(
                title: "This file is a link, not a playlist.", body: "If it points to a playlist or a stream, add it as a source.")
        case .linkList:
            return Problem(title: "This file is a list of links, not a playlist.", body: "Add each link as its own M3U source.")
        case .hlsStream:
            return Problem(title: "This is a single stream, not a channel list.", body: "Add the channel's playlist instead.")
        case .playlist:
            return nil
        }
    }

    /// A file that could not be read at all.
    public func unreadable(fileName: String) -> Problem {
        Problem(title: "Could not read \(fileName). Make sure it is downloaded and try again.")
    }

    /// The name a file source gets when the Name field is left empty: the
    /// file name without its extension.
    public static func defaultName(fileName: String) -> String {
        let base = (fileName as NSString).deletingPathExtension
        return base.isEmpty ? fileName : base
    }

    /// "You imported <file> before as <name>".
    public static func importedBefore(fileName: String, name: String) -> String {
        "You imported \(fileName) before as \(name)"
    }
}
