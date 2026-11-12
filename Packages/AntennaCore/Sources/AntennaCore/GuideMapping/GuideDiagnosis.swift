import Foundation

/// Why a channel has no current programme, or where its guide comes from
/// (guide-sources-and-channel-mapping/see-why-a-channel-has-no-guide).
public enum GuideReason: Sendable, Equatable {
    /// An M3U playlist has not named its guide links yet.
    case playlistLoading
    /// No guide is turned on.
    case noGuide
    /// Nothing finished, a guide waits for its login, the rest failed.
    case waitingForLogin
    /// Nothing finished and a guide is still due; `bytes` while one downloads.
    case notDownloaded(bytes: Int64?)
    /// Every guide failed offline.
    case offline
    /// Every guide failed.
    case everyGuideFailed
    /// The hand-picked entry has no programmes in any guide.
    case matchNotFound(id: String)
    /// No match and the channel has no guide id.
    case noGuideID
    /// No finished guide lists the id, and none has programmes for it.
    case idNotFound(id: String)
    /// A guide lists the id with no programmes for it.
    case noProgrammes(id: String)
    /// The id's programmes all ended before now.
    case guideEnded(id: String)
    /// The id has a programme ending after now.
    case hasGuide(id: String)

    /// True for the reasons that hold for every channel of the source.
    public var coversPlaylist: Bool {
        switch self {
        case .playlistLoading, .noGuide, .waitingForLogin, .offline, .everyGuideFailed: true
        default: false
        }
    }
}

/// Works out a channel's reason from the source's guide rows and the index,
/// checking the reasons in a fixed order; the first that holds applies.
public enum GuideDiagnosis {
    public static func reason(for channel: Channel, rows status: GuideSourceStatus, index: GuideIndex, now: Date) -> GuideReason {
        if let shared = sourceReason(status) { return shared }
        let match = index.match(for: channel)
        guard let key = index.key(for: channel) else { return .noGuideID }
        let slots = index.schedule(for: key)?.1
        if match?.origin == .user, slots == nil { return .matchNotFound(id: key.epgID) }
        guard let slots else {
            let layers = index.sources[key.sourceID]?.layers ?? []
            let listed = layers.contains { $0.guide.names[key.epgID] != nil || $0.guide.schedules[key.epgID] != nil }
            return listed ? .noProgrammes(id: key.epgID) : .idNotFound(id: key.epgID)
        }
        guard let last = slots.last, last.stop > now else { return .guideEnded(id: key.epgID) }
        return .hasGuide(id: key.epgID)
    }

    /// The reason that holds for the whole source, if any.
    public static func sourceReason(_ status: GuideSourceStatus) -> GuideReason? {
        if status.playlistLoading { return .playlistLoading }
        let enabled = status.rows.filter(\.enabled)
        if enabled.isEmpty { return .noGuide }
        if enabled.contains(where: \.hasGuide) { return nil }
        let failures = enabled.compactMap { row -> GuideError? in
            if case .failed(let error) = row.status { return error }
            return nil
        }
        let waiting = failures.contains(.credentialMissing)
        if waiting, failures.count == enabled.count { return .waitingForLogin }
        if let downloading = enabled.first(where: { $0.status.isInFlight }) {
            if case .downloading(let bytes) = downloading.status { return .notDownloaded(bytes: bytes) }
            return .notDownloaded(bytes: nil)
        }
        if failures.count == enabled.count {
            return failures.allSatisfy { $0 == .offline } ? .offline : .everyGuideFailed
        }
        return nil
    }

    /// k guides failed with an error other than offline or a missing login,
    /// and j are still due, for the suffix lines.
    public static func pending(_ status: GuideSourceStatus) -> (failed: Int, downloading: Int) {
        var failed = 0
        var downloading = 0
        for row in status.rows where row.enabled {
            switch row.status {
            case .failed(let error) where error != .offline && error != .credentialMissing: failed += 1
            case .pending, .downloading, .reading: downloading += 1
            default: break
            }
        }
        return (failed, downloading)
    }
}

extension GuideIndex {
    /// For the guide row's status line: how many of `channels` have a
    /// programme ending after `now` in that guide alone, by the key
    /// `key(for:)` gives, and the days it covers. Nil when the guide is not
    /// turned on and loaded.
    public func coverage(of reference: GuideReference, sourceID: UUID, channels: [Channel], now: Date) -> (channels: Int, days: Int)? {
        guard let layer = sources[sourceID]?.layers.first(where: { $0.reference == reference }) else { return nil }
        var count = 0
        for channel in channels {
            guard let key = key(for: channel), let last = layer.guide.schedules[key.epgID]?.last, last.stop > now else { continue }
            count += 1
        }
        return (count, layer.guide.days(from: now))
    }
}
