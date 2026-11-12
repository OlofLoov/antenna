import Foundation

/// One source as Live lists it while channels load.
struct LiveSource: Identifiable, Equatable, Sendable {
    enum State: Equatable, Sendable {
        case loading
        case loaded(channels: Int)
        case offline
        case failed
        case waitingForLogin

        /// True once the source finished and added nothing: loaded empty,
        /// offline, failed or waiting for its login.
        var addedNothing: Bool { self != .loading && !isLoadedWithChannels }

        var isLoadedWithChannels: Bool {
            if case .loaded(let count) = self { return count > 0 }
            return false
        }
    }

    var id: UUID
    var name: String
    var state: State
    /// A file source waiting for its playlist rather than its login
    /// (local-m3u-file-import/channels-reach-apple-tv).
    var waitsForICloud = false

    /// "Cabin: waiting for its login to sync from iCloud", or for its playlist.
    var waitingLine: String { "\(name): waiting for its \(waitsForICloud ? "playlist" : "login") to sync from iCloud" }

    /// "Cabin · waiting for login", or "· waiting for iCloud".
    var waitingTag: String { "\(name) · waiting for \(waitsForICloud ? "iCloud" : "login")" }
}
