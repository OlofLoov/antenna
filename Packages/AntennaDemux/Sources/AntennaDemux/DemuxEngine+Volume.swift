import AVFoundation

extension DemuxEngine {
    /// Sets the sound level, 0 to 1, and mutes or unmutes it. It holds for
    /// every stream this engine plays until set again.
    public func setVolume(_ volume: Float, muted: Bool) {
        audioRenderer.volume = min(1, max(0, volume))
        audioRenderer.isMuted = muted
    }

    /// Mutes or unmutes the sound, leaving its level as it is.
    public func setMuted(_ muted: Bool) {
        audioRenderer.isMuted = muted
    }

    public var isMuted: Bool { audioRenderer.isMuted }
}
