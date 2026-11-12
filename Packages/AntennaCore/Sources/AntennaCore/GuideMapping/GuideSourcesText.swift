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
    /// Apple TV words where they differ.
    public var television: Bool

    public init(locale: Locale = .autoupdatingCurrent, television: Bool = false) {
        setup = SetupText(locale: locale)
        self.television = television
    }

    public static let title = "Guide sources"
    public static let addGuide = "Add guide URL"
    public static let channelsHeader = "Channels without guide"
    public static let namedHeader = "Matched by name"
    public static let removeMatch = "Remove match"
    public static let retry = "Retry now"
    public static let reenter = "Re-enter link"
    public static let pickerTitle = "Find a guide entry"
    public static let pickerPrompt = "Search the guide by channel name or id"
    public static let filterPrompt = "Filter channels"
    public static let waitingForGuide = "Waiting for the guide…"
    public static let notDownloadedPicker = "The guide has not been downloaded yet."
    public static let noMatchCaption = "Try a shorter name or the channel's tvg-id."
    public static let tooMany = "Too many mappings for this source. Remove some to add more."

    // MARK: Guide rows

    /// The row's first line.
    public func name(_ reference: GuideReference, link: GuideSettings.Link?) -> String {
        switch reference {
        case .provider: "Provider guide"
        case .playlist: "From the playlist"
        case .saved: "Guide URL"
        case .added: link?.host ?? "Guide link"
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
        case .off: return Line("Turned off", .muted)
        case .pending, .downloading(nil): return Line("Downloading")
        case .downloading(let bytes?): return Line("Downloading · \(bytes.formatted(.byteCount(style: .file).locale(setup.locale)))")
        case .reading: return Line("Reading the guide…")
        case .loaded:
            let found = coverage ?? (0, 0)
            return Line("Loaded · \(setup.count(found.channels)) of \(setup.count(channels)) channels · \(setup.days(found.days))")
        case .failed(let error):
            return failure(error, reference: row.reference, source: source)
        }
    }

    private func failure(_ error: GuideError, reference: GuideReference, source: String) -> Line {
        switch error {
        case .offline:
            return Line("Offline · retries when you're back online", .muted)
        case .credentialMissing where reference == .provider:
            return Line(television ? "Sign in to \(source) on this Apple TV" : "Waiting for login to sync from iCloud", .muted)
        case .credentialMissing:
            return Line(
                television ? "This guide link needs its login on this Apple TV" : "Waiting for this guide's login to sync from iCloud",
                .muted)
        default:
            return Line("Could not download · \(Self.reason(error))", .error)
        }
    }

    /// The short failure reason.
    public static func reason(_ error: GuideError) -> String {
        switch error {
        case .httpStatus(let status): "Server returned \(status)"
        case .timeout: "Timed out"
        case .offline, .network: "Network error"
        case .malformed, .unsupportedEncoding: "Not a guide file"
        case .empty: "No programmes in the guide"
        case .tooLarge: "Too large"
        case .unauthorized: "Login rejected"
        case .credentialMissing, .credentialUnreadable: "Could not read login"
        }
    }

    /// Guide actions for a row: Move up and down, Turn off or on, Retry now
    /// for a failed or offline row, Remove for an added link.
    public static func actions(_ row: GuideRow) -> [String] {
        var result = ["Move up", "Move down", row.enabled ? "Turn off" : "Turn on"]
        if case .failed(let error) = row.status, error != .credentialMissing { result.append(retry) }
        if row.reference.isRemovable { result.append("Remove") }
        return result
    }

    // MARK: Channels

    /// "Channels without guide · 24".
    public func header(_ count: Int?) -> String {
        count.map { "\(Self.channelsHeader) · \(setup.count($0))" } ?? Self.channelsHeader
    }

    /// "Matched by name · 3".
    public func namedHeader(_ count: Int) -> String {
        "\(Self.namedHeader) · \(setup.count(count))"
    }

    public func showAll(_ count: Int) -> String {
        "Show \(setup.count(count)) channels"
    }

    public func noChannels(source: String) -> String {
        "Channels have not loaded for \(source)"
    }

    public func everyChannel(source: String) -> String {
        "Every channel in \(source) has a guide"
    }

    /// The short label in a channel row.
    public static func label(_ reason: GuideReason) -> String {
        switch reason {
        case .playlistLoading: "Loading"
        case .noGuide: "No guide"
        case .waitingForLogin: "Waiting for login"
        case .notDownloaded: "Not downloaded yet"
        case .offline: "Offline"
        case .everyGuideFailed: "Guide failed"
        case .matchNotFound: "Mapping not found"
        case .noGuideID: "No guide id"
        case .idNotFound: "Id not found"
        case .noProgrammes: "No programmes"
        case .guideEnded: "Guide ended"
        case .hasGuide: ""
        }
    }

    // MARK: Picker

    /// "<id> · <guide> · <n> programmes".
    public func detail(_ entry: GuideEntry, guide: String) -> String {
        let count =
            switch entry.programmes {
            case 0: "no programmes"
            case 1: "1 programme"
            default: "\(setup.count(entry.programmes)) programmes"
            }
        return "\(entry.id) · \(guide) · \(count)"
    }

    public func showing(_ shown: Int, of total: Int) -> String {
        "Showing \(setup.count(shown)) of \(setup.count(total))"
    }

    public func noMatch(_ query: String) -> String {
        "No guide entry matches “\(query)”"
    }
}
