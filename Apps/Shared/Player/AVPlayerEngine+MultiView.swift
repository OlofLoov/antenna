import AVFoundation
import AntennaCore

extension AVPlayerEngine {
    /// Mutes or unmutes the sound, leaving its level as it is.
    func setMuted(_ muted: Bool) {
        player.isMuted = muted
    }

    /// Holds `item` to `maximumVideoHeight`, as a 16:9 size, or lifts the limit.
    func applyMaximumVideoHeight(to item: AVPlayerItem) {
        guard let height = maximumVideoHeight else {
            item.preferredMaximumResolution = .zero
            return
        }
        item.preferredMaximumResolution = CGSize(width: Double(height) * 16 / 9, height: Double(height))
    }
}
