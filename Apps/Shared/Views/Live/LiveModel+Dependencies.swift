import AntennaCore
import Foundation
import SwiftData

extension LiveModel {
    struct Dependencies {
        var engine: any PlaybackEngine
        var load: @MainActor (SourceDescriptor) async throws -> Playlist
        var hasLogin: @MainActor (SourceDescriptor) -> Bool
        /// Told about each loaded playlist so its guide downloads.
        var guide: AppGuideStore?
        /// What the rows, the now-playing line and the details read.
        var programmes: OverlayGuide
        var languages = ChannelLanguageStore()
        /// How often to look for a login that has not arrived yet.
        var loginCheck = Duration.seconds(5)
        /// How long a tap keeps the controls up while playing. UI tests
        /// raise it, since a slow runner can take longer than that to read them.
        var touchHold = ControlsTimer.touchHold
        /// The connection the player watches to recover from an offline error.
        var network: NetworkWatch = .system
        /// How long the spinner shows before it names the source as slow.
        var slowDelay = Duration.seconds(10)
        /// The current profile's recents, session and last channel. Tests and
        /// previews keep theirs apart from the app's.
        var recents = RecentsStore.scratch
        /// The channels each source had on this device, for the New group.
        var seen = SeenChannelsStore.scratch
        /// The logins a source's links carry, for saving the last channel
        /// for launch and tuning it again. Nil saves nothing and starts
        /// nothing early.
        var launchLogins: (@MainActor (SourceDescriptor) -> [SavedChannel.Login]?)?
        /// How the ten-second count waits.
        var sleep: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
        /// The lock screen and Control Center; nil uses the system's.
        var nowPlaying: NowPlayingSink?
        /// How often the lock screen catches up with the programme.
        var nowPlayingInterval = Duration.seconds(5)
        /// The Picture in Picture window; nil watches the engine's.
        var pictureInPicture: PictureInPictureHooks?
        /// Yields true while the stream plays on AirPlay; nil asks the engine.
        var airPlay: (@MainActor () -> AsyncStream<Bool>)?
        /// The tiles' engines and limit when multi-view starts on a Mac.
        var multiView = MultiViewModel.Dependencies()
        /// Builds Start over's catch-up addresses.
        var catchup = CatchupAddresses()
        /// True for a file source whose playlist has not synced yet.
        var waitsForICloud: @MainActor (SourceDescriptor) -> Bool = { _ in false }
        /// Builds the catalogue and its name index away from the main actor.
        /// Tests hold it to land builds out of order.
        var buildCatalogue: @Sendable (CatalogueInputs<PersistentIdentifier>) async -> BuiltCatalogue<PersistentIdentifier> = {
            await $0.indexed()
        }
    }
}
