import Foundation

/// The Guide sources screen's words, from the change's agreed copy
/// (guide-sources-and-channel-mapping capability). Counts use the locale's
/// grouping.
public struct GuideSourcesText: Sendable {
    public enum Style: Sendable, Equatable {
        case normal, muted, error
    }

    public struct Line: Sendable, Equatable {
        public var text: String
        public var style: Style

        public init(_ text: String, _ style: Style = .normal) {
            self.text = text
            self.style = style
        }
    }

    public var setup: SetupText
    var words: Words { setup.words }
    /// Apple TV words where they differ.
    public var television: Bool

    public init(locale: Locale = .autoupdatingCurrent, television: Bool = false) {
        setup = SetupText(locale: locale)
        self.television = television
    }

    public var title: String { words("Guide sources") }
    public var addGuide: String { words("Add guide URL") }
    public var channelsHeader: String { words("Channels without guide") }
    public var namedHeader: String { words("Matched by name") }
    public var removeMatch: String { words("Remove match") }
    public var retry: String { words("Retry now") }
    public var reenter: String { words("Re-enter link") }
    public var pickerTitle: String { words("Find a guide entry") }
    public var pickerPrompt: String { words("Search the guide by channel name or id") }
    public var filterPrompt: String { words("Filter channels") }
    public var waitingForGuide: String { words("Waiting for the guide…") }
    public var notDownloadedPicker: String { words("The guide has not been downloaded yet.") }
    public var noMatchCaption: String { words("Try a shorter name or the channel's tvg-id.") }
    public var tooMany: String { words("Too many mappings for this source. Remove some to add more.") }

    // MARK: Guide rows

    /// The row's first line.
    public func name(_ reference: GuideReference, link: GuideSettings.Link?) -> String {
        switch reference {
        case .provider: words("Provider guide")
        case .playlist: words("From the playlist")
        case .saved: words("Guide URL")
        case .added: link?.host ?? words("Guide link")
        }
    }

    /// The row's second line: the redacted link, or "host/…" for an added
    /// link whose parts are in the Keychain. None for the provider guide.
    public func address(_ row: GuideRow, link: GuideSettings.Link?) -> String? {
        switch row.reference {
        case .provider: nil
        case .playlist, .saved: row.address
        case .added: link.map { $0.plain == nil ? GuideLinkInput.shortName($0) : row.address ?? GuideLinkInput.shortName($0) }
        }
    }

    /// The status line. `coverage` gives the channels with a programme ahead
    /// in this guide and the days it covers, for a loaded guide.
    public func status(_ row: GuideRow, coverage: (channels: Int, days: Int)?, channels: Int, source: String) -> Line {
        switch row.status {
        case .off: return Line(words("Turned off"), .muted)
        case .pending, .downloading(nil): return Line(words("Downloading"))
        case .downloading(let bytes?): return Line(words("Downloading · \(bytes.formatted(.byteCount(style: .file).locale(setup.locale)))"))
        case .reading: return Line(words("Reading the guide…"))
        case .loaded:
            let found = coverage ?? (0, 0)
            return Line(words("Loaded · \(found.channels) of \(channels) channels · \(found.days) days"))
        case .failed(let error):
            return failure(error, reference: row.reference, source: source)
        }
    }

    private func failure(_ error: GuideError, reference: GuideReference, source: String) -> Line {
        switch error {
        case .offline:
            return Line(words("Offline · retries when you're back online"), .muted)
        case .credentialMissing where reference == .provider:
            return Line(
                television ? words("Sign in to \(words.source(source)) on this Apple TV") : words("Waiting for login to sync from iCloud"),
                .muted)
        case .credentialMissing:
            return Line(
                television
                    ? words("This guide link needs its login on this Apple TV")
                    : words("Waiting for this guide's login to sync from iCloud"),
                .muted)
        default:
            return Line(words("Could not download · \(reason(error))"), .error)
        }
    }

    /// The short failure reason.
    public func reason(_ error: GuideError) -> String {
        switch error {
        case .httpStatus(let status): words("Server returned \(String(status))")
        case .timeout: words("Timed out")
        case .offline, .network: words("Network error")
        case .malformed, .unsupportedEncoding: words("Not a guide file")
        case .empty: words("No programmes in the guide")
        case .tooLarge: words("Too large")
        case .unauthorized: words("Login rejected")
        case .credentialMissing, .credentialUnreadable: words("Could not read login")
        }
    }

    /// Guide actions for a row: Move up and down, Turn off or on, Retry now
    /// for a failed or offline row, Remove for an added link.
    public func actions(_ row: GuideRow) -> [String] {
        var result = [words("Move up"), words("Move down"), row.enabled ? words("Turn off") : words("Turn on")]
        if case .failed(let error) = row.status, error != .credentialMissing { result.append(retry) }
        if row.reference.isRemovable { result.append(words("Remove")) }
        return result
    }

    // MARK: Channels

    /// "Channels without guide · 24".
    public func header(_ count: Int?) -> String {
        count.map { words("Channels without guide · \($0)") } ?? channelsHeader
    }

    /// "Matched by name · 3".
    public func namedHeader(_ count: Int) -> String {
        words("Matched by name · \(count)")
    }

    public func showAll(_ count: Int) -> String {
        words("Show \(count) channels")
    }

    public func noChannels(source: String) -> String {
        words("Channels have not loaded for \(words.source(source))")
    }

    public func everyChannel(source: String) -> String {
        words("Every channel in \(words.source(source)) has a guide")
    }

    /// The short label in a channel row.
    public func label(_ reason: GuideReason) -> String {
        switch reason {
        case .playlistLoading: words("Loading")
        case .noGuide: words("No guide")
        case .waitingForLogin: words("Waiting for login")
        case .notDownloaded: words("Not downloaded yet")
        case .offline: words("Offline")
        case .everyGuideFailed: words("Guide failed")
        case .matchNotFound: words("Mapping not found")
        case .noGuideID: words("No guide id")
        case .idNotFound: words("Id not found")
        case .noProgrammes: words("No programmes")
        case .guideEnded: words("Guide ended")
        case .hasGuide: ""
        }
    }

    // MARK: Picker

    /// "<id> · <guide> · <n> programmes".
    public func detail(_ entry: GuideEntry, guide: String) -> String {
        let count =
            switch entry.programmes {
            case 0: words("no programmes")
            case 1: words("1 programme")
            default: words("\(entry.programmes) programmes")
            }
        return "\(entry.id) · \(guide) · \(count)"
    }

    public func showing(_ shown: Int, of total: Int) -> String {
        words("Showing \(shown) of \(total)")
    }

    public func noMatch(_ query: String) -> String {
        words("No guide entry matches “\(query)”")
    }
}
