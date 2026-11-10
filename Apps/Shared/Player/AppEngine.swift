import AntennaCore
import AntennaDemux

extension PlaybackEngine {
    /// True while the picture plays, or can go on playing, in the Picture in
    /// Picture window, on Apple's player or the demuxing engine.
    @MainActor var continuesInPictureInPicture: Bool {
        #if os(iOS) || os(tvOS)
            if DemuxEngine.resolve(self)?.continuesInPictureInPicture == true { return true }
        #endif
        return AVPlayerEngine.resolve(self)?.continuesInPictureInPicture ?? false
    }
}

extension RoutedEngine {
    /// The engine every player screen uses: HLS and the files the system
    /// reads play on Apple's player, raw broadcast streams, Matroska and AVI
    /// on the demuxing engine.
    @MainActor static func app() -> RoutedEngine {
        RoutedEngine(system: AVPlayerEngine(), demuxer: DemuxEngine())
    }
}
