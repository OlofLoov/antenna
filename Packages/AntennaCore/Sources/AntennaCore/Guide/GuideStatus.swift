import Foundation

/// Where one guide of a source stands on this device.
public enum GuideStatus: Sendable, Equatable {
    /// Turned on, waiting for its turn or for the next refresh.
    case pending
    /// Requested; `bytes` is nil until the first chunk arrives.
    case downloading(bytes: Int64?)
    /// Every byte arrived and the guide is being read.
    case reading
    /// Loaded at this time. A later failed refresh keeps the guide and
    /// reports `.failed`, with the guide still answering.
    case loaded(Date)
    case failed(GuideError)
    /// Turned off by the user; never downloaded.
    case off

    /// True while nothing has been decided yet: pending, downloading or reading.
    public var isInFlight: Bool {
        switch self {
        case .pending, .downloading, .reading: true
        case .loaded, .failed, .off: false
        }
    }
}

/// One row of a source's guide list as screens show it.
public struct GuideRow: Sendable, Equatable {
    public var reference: GuideReference
    public var enabled: Bool
    public var status: GuideStatus
    /// The link as `redacted(_:)` shows it; nil for the provider guide and
    /// for an added link this device has no login for.
    public var address: String?
    /// True when a guide that loaded before still answers.
    public var hasGuide: Bool

    public init(reference: GuideReference, enabled: Bool, status: GuideStatus, address: String? = nil, hasGuide: Bool = false) {
        self.reference = reference
        self.enabled = enabled
        self.status = status
        self.address = address
        self.hasGuide = hasGuide
    }
}

/// A source's guides on this device, in the user's order.
public struct GuideSourceStatus: Sendable, Equatable {
    public var rows: [GuideRow]
    /// True for a playlist whose guide links have not arrived yet.
    public var playlistLoading: Bool

    public init(rows: [GuideRow] = [], playlistLoading: Bool = false) {
        self.rows = rows
        self.playlistLoading = playlistLoading
    }
}
