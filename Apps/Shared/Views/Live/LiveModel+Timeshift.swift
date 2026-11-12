import AntennaCore
import Foundation

extension LiveModel {
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
