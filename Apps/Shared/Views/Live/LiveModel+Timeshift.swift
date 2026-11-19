import AntennaCore
import Foundation

extension LiveModel {
    /// Pauses a playing channel, plays a paused one, as the user's own pause.
    func playPause() {
        // Space and the lock screen pause no tile (multi-view/sound-follows-the-highlighted-tile).
        guard playing != nil, multiView == nil else { return }
        player.timeshift.toggle(isPaused: isPaused)
    }

    /// The options a channel opens with, its remembered languages among them.
    var languageOptions: @MainActor (Channel) -> PlaybackOptions {
        { [languages] in languages.options(for: $0) }
    }

    /// The stored source with this id.
    func descriptor(for id: UUID?) -> SourceDescriptor? {
        id.flatMap { descriptors[$0] }
    }

    /// Loads the channel playing again with a new buffer: the engine stops,
    /// which deletes the old one, and the channel tunes at live.
    func restartWithNewBuffer() {
        guard let playing else { return }
        Task {
            await engine.stop()
            load(playing)
        }
    }

    /// Tells the player which programme Start over would restart and how
    /// to ask for its catch-up.
    func wireStartOver() {
        let timeshift = player.timeshift
        timeshift.nowPlaying = { [weak self] in
            guard let self, let playing else { return nil }
            return (playing, programmes.panel(for: playing, at: .now).now)
        }
        timeshift.catchupAddress = { [weak self] channel, request in
            guard let self else { return nil }
            return await dependencies.catchup.url(for: channel, source: descriptor(for: channel.sourceID), request: request)
        }
    }
}
