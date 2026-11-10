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

extension PlaybackEngine {
    /// Moves the picture into the Picture in Picture window on whichever
    /// engine is playing, when the system allows it now. Does nothing on a Mac.
    @MainActor func startPictureInPicture() {
        #if os(iOS)
            if let demuxer = DemuxEngine.resolve(self), demuxer.continuesInPictureInPicture {
                demuxer.startPictureInPicture()
                return
            }
            AVPlayerEngine.resolve(self)?.pictureInPicture?.startPictureInPicture()
        #endif
    }
}

extension RoutedEngine {
    /// The engine every player screen uses: HLS and the files the system
    /// reads play on Apple's player, raw broadcast streams, Matroska and AVI
    /// on the demuxing engine.
    /// Both share the TV's mode on Apple TV and the picture held over a switch.
    @MainActor static func app() -> RoutedEngine {
        let display = DisplayMatcher()
        let hold = FrameHold()
        return RoutedEngine(system: AVPlayerEngine(display: display, hold: hold), demuxer: DemuxEngine(display: display, hold: hold))
    }
}
