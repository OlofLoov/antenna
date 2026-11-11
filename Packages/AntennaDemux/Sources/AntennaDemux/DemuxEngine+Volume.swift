import AVFoundation

extension DemuxEngine {
    /// Sets the sound level, 0 to 1, and mutes or unmutes it. It holds for
    /// every stream this engine plays until set again.
    public func setVolume(_ volume: Float, muted: Bool) {
        audioRenderer.volume = min(1, max(0, volume))
        audioRenderer.isMuted = muted
    }
}
