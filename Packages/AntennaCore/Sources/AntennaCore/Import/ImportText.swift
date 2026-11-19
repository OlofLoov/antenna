import Foundation

/// What the import sheet says about a file, from the change's copy tables.
/// Counts use `locale`'s grouping separator; sizes read like Finder's.
public struct ImportText: Sendable {
    public var locale: Locale

    var words: Words { Words(locale) }

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

        public init(channels: String, groups: String? = nil, guideHost: String? = nil, skipped: String? = nil) {
            self.channels = channels
            self.groups = groups
            self.guideHost = guideHost
            self.skipped = skipped
        }
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
        var names: String?
        if !groups.isEmpty {
            names = groups.prefix(8).joined(separator: ", ")
            if groups.count > 8 { names = words("\(names ?? "") and \(groups.count - 8) more") }
        }
        let skipped = words("\(inspected.skipped) entries skipped")
        return Summary(
            channels: words("\(playlist.channels.count) channels in \(groups.count) groups"), groups: names,
            guideHost: playlist.epgURLs.first?.host(),
            skipped: inspected.skipped > 0 ? skipped : nil)
    }

    /// Why a file cannot be imported, nil for a channel list.
    public func problem(_ outcome: PlaylistImport.Outcome, fileName: String) -> Problem? {
        let split = words("Split the file, or host it and add the link as an M3U source instead.")
        switch outcome {
        case .tooLarge(let bytes?):
            return Problem(title: words("This file is \(size(bytes)). Antenna imports playlists up to 16 MB."), body: split)
        case .tooLarge(nil):
            return Problem(title: words("This file is larger than 16 MB. Antenna imports playlists up to 16 MB."), body: split)
        case .noChannels(let sawEntries):
            return Problem(
                title: words("No channels found in \(words.source(fileName))."),
                body: sawEntries
                    ? words("The entries in this file are not links.")
                    : words("Antenna reads M3U playlists: #EXTINF lines, each followed by a stream link. This file has no such pair."))
        case .linkList(let links) where links.count == 1:
            return Problem(
                title: words("This file is a link, not a playlist."),
                body: words("If it points to a playlist or a stream, add it as a source."))
        case .linkList:
            return Problem(
                title: words("This file is a list of links, not a playlist."), body: words("Add each link as its own M3U source."))
        case .hlsStream:
            return Problem(title: words("This is a single stream, not a channel list."), body: words("Add the channel's playlist instead."))
        case .playlist:
            return nil
        }
    }

    /// A file that could not be read at all.
    public func unreadable(fileName: String) -> Problem {
        Problem(title: words("Could not read \(words.source(fileName)). Make sure it is downloaded and try again."))
    }

    /// The name a file source gets when the Name field is left empty: the
    /// file name without its extension.
    public static func defaultName(fileName: String) -> String {
        let base = (fileName as NSString).deletingPathExtension
        return base.isEmpty ? fileName : base
    }

    /// "You imported <file> before as <name>".
    public static func importedBefore(fileName: String, name: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("You imported \(words.source(fileName)) before as \(words.source(name))")
    }
}
