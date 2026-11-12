import AntennaCore
import AntennaDemux

/// How a multi-view tile's engine plays, set on both of the app's engines
/// so it holds whichever one plays the tile's stream.
struct TilePlayback: Equatable {
    /// HLS picks no picture taller than this; nil for no limit.
    var maximumVideoHeight: Int?
    /// The TV's frame rate and dynamic range follow the stream.
    var appliesDisplayCriteria: Bool

    /// A tile in the grid: 1080p at most, and the TV's mode left alone
    /// (multi-view/start-multi-view-on-apple-tv).
    static let tile = TilePlayback(maximumVideoHeight: 1080, appliesDisplayCriteria: false)
    /// The single player, as before multi-view and after it ends.
    static let single = TilePlayback(maximumVideoHeight: nil, appliesDisplayCriteria: true)
}

extension PlaybackEngine {
    /// Mutes or unmutes both of the app's engines at once, leaving the
    /// level as it is. It holds for every stream until set again, so a
    /// tile muted before its first load starts muted.
    @MainActor func setMuted(_ muted: Bool) {
        AVPlayerEngine.resolve(self)?.setMuted(muted)
        DemuxEngine.resolve(self)?.setMuted(muted)
    }

    /// True while either engine is muted.
    @MainActor var isMuted: Bool {
        AVPlayerEngine.resolve(self)?.player.isMuted == true || DemuxEngine.resolve(self)?.isMuted == true
    }

    /// Plays as a multi-view tile or as the single player again.
    @MainActor func setPlayback(_ playback: TilePlayback) {
        AVPlayerEngine.resolve(self)?.maximumVideoHeight = playback.maximumVideoHeight
        DemuxEngine.resolve(self)?.display.appliesDisplayCriteria = playback.appliesDisplayCriteria
    }

    /// What `setPlayback` last set, read from the engines.
    @MainActor var playback: TilePlayback {
        TilePlayback(
            maximumVideoHeight: AVPlayerEngine.resolve(self)?.maximumVideoHeight,
            appliesDisplayCriteria: DemuxEngine.resolve(self)?.display.appliesDisplayCriteria ?? true)
    }

    /// Fails a busy server or a server error at once instead of trying
    /// again, while another tile plays from the same source
    /// (multi-view/a-tile-that-fails-says-why).
    @MainActor func setRefusalsFinal(_ final: Bool) {
        AVPlayerEngine.resolve(self)?.refusalsAreFinal = final
        DemuxEngine.resolve(self)?.refusalsAreFinal = final
    }
}
