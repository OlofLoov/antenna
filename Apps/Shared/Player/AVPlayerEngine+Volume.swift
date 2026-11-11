import AVFoundation
import AntennaCore

extension AVPlayerEngine {
    /// Sets the sound level, 0 to 1, and mutes or unmutes it, for every
    /// stream this engine plays until set again.
    func setVolume(_ volume: Float, muted: Bool) {
        player.volume = min(1, max(0, volume))
        player.isMuted = muted
    }

    /// Yields true while the picture plays on an AirPlay device, first the
    /// current answer, then each change.
    func externalPlayback() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let observation = player.observe(\.isExternalPlaybackActive, options: [.initial, .new]) { player, _ in
                continuation.yield(player.isExternalPlaybackActive)
            }
            continuation.onTermination = { _ in observation.invalidate() }
        }
    }
}
