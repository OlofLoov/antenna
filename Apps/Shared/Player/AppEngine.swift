import AntennaCore
import AntennaDemux

extension RoutedEngine {
    /// The engine every player screen uses: HLS and the files the system
    /// reads play on Apple's player, raw broadcast streams, Matroska and AVI
    /// on the demuxing engine.
    @MainActor static func app() -> RoutedEngine {
        RoutedEngine(system: AVPlayerEngine(), demuxer: DemuxEngine())
    }
}
