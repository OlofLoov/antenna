import Foundation

/// Identifies one channel's guide: the source it came from and its XMLTV id.
/// Channels of one source with the same id share programmes and state.
public struct GuideKey: Hashable, Sendable {
    public let sourceID: UUID
    /// The XMLTV id with whitespace and newlines trimmed from both ends.
    public let epgID: String

    public init(sourceID: UUID, epgID: String) {
        self.sourceID = sourceID
        self.epgID = epgID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The channel's key, or nil when it has no `sourceID` or its `epgID` is
    /// nil or blank. `Channel.id` and `Channel.streamURL` are never part of it.
    public init?(channel: Channel) {
        guard let sourceID = channel.sourceID, let epgID = channel.epgID else { return nil }
        let key = GuideKey(sourceID: sourceID, epgID: epgID)
        guard !key.epgID.isEmpty else { return nil }
        self = key
    }
}

/// Why a guide did not load. Values carry codes only, never a URL, a login
/// or a response body.
public enum GuideError: Error, Sendable, Equatable {
    /// The server answered with this non-2xx status.
    case httpStatus(Int)
    case timeout
    /// No connection: `.notConnectedToInternet`, `.networkConnectionLost` or `.dataNotAllowed`.
    case offline
    /// Any other transport failure, reduced to its code.
    case network(URLError.Code)
    /// A damaged gzip stream or a document the XMLTV parser rejects.
    case malformed
    /// A document with no programmes, an empty body included.
    case empty
    /// A body that is neither XML nor gzip.
    case unsupportedEncoding
    /// The body crossed a `GuideLimits` limit.
    case tooLarge
    /// The Xtream login has not reached this device.
    case credentialMissing
    /// The Keychain could not read the Xtream login.
    case credentialUnreadable
    /// The provider refused the Xtream login with 401 or 403.
    case unauthorized
}

/// What a screen shows for a channel's guide.
public enum GuideLoadingState: Sendable, Equatable {
    /// No guide has completed for the source yet, and one is due or running.
    case loading
    /// The source's guide has programmes for this channel.
    case loaded
    /// The source's guide has completed, with nothing for this channel.
    case noData
    /// The source has no guide link, its login is missing, or it was removed.
    case unavailable
    /// The first load failed. Later failures are reported only as progress.
    case failed(GuideError)
}
