#if os(tvOS)
    import AntennaCore
    import Foundation
    import os

    extension ShellModel {
        static let logger = Logger(subsystem: "se.codecrave.antenna", category: "shell")
        static let launchDeadline = Duration.seconds(10)

        struct Dependencies {
            var engine: any PlaybackEngine
            var load: @MainActor (SourceDescriptor) async throws -> Playlist
            var hasLogin: @MainActor (SourceDescriptor) -> Bool
            var recents: RecentsStore
            /// The channels each source had on this Apple TV, for the New group.
            var seen = SeenChannelsStore.scratch
            var sleep: @MainActor (Duration) async throws -> Void
            var guide: AppGuideStore?
            var languages = ChannelLanguageStore()
            /// Where Sign in on the error stores a login.
            var credentials: any CredentialStoring = CredentialStore()
            /// The connection the player watches to recover from an offline error.
            var network: NetworkWatch = .system
            /// How long the spinner shows before it names the source as slow.
            var slowDelay = Duration.seconds(10)
            /// How the ten-second count waits, when not as `sleep`.
            var watchSleep: (@MainActor (Duration) async throws -> Void)?
            /// The tiles' engines and limit when multi-view starts.
            var multiView = MultiViewModel.Dependencies()
            /// Builds Start over's catch-up addresses.
            var catchup = CatchupAddresses()
            /// True for a file source whose playlist has not synced yet.
            var waitsForICloud: @MainActor (SourceDescriptor) -> Bool = { _ in false }
            /// The movies and episodes a source's last load had on this device, nil when unknown.
            var storedTitles: @MainActor (UUID) -> TitleCounts? = { _ in nil }
            /// The logins a source's links carry, for saving the last channel
            /// for launch and tuning it again. Nil saves nothing and starts
            /// nothing early.
            var launchLogins: (@MainActor (SourceDescriptor) -> [SavedChannel.Login]?)?
        }
    }
#endif
