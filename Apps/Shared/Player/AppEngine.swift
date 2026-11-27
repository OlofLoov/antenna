import AntennaCore
import AntennaDemux

extension PlaybackEngine {
    /// True while the picture plays, or can go on playing, in the Picture in
    /// Picture window, on Apple's player or the demuxing engine.
    @MainActor var continuesInPictureInPicture: Bool {
        #if os(iOS) || os(tvOS) || os(macOS)
            if DemuxEngine.resolve(self)?.continuesInPictureInPicture == true { return true }
        #endif
        return AVPlayerEngine.resolve(self)?.continuesInPictureInPicture ?? false
    }
}

extension PlaybackEngine {
    /// Moves the picture into the Picture in Picture window on whichever
    /// engine is playing, when the system allows it now. Does nothing on Apple TV.
    @MainActor func startPictureInPicture() {
        #if os(iOS) || os(macOS)
            if let demuxer = DemuxEngine.resolve(self), demuxer.continuesInPictureInPicture {
                demuxer.startPictureInPicture()
                return
            }
            AVPlayerEngine.resolve(self)?.pictureInPicture?.startPictureInPicture()
        #endif
    }
}

extension PlaybackEngine {
    /// Sets the sound level and mute on both of the app's engines, so it
    /// holds whichever one plays the next stream.
    @MainActor func setVolume(_ volume: Float, muted: Bool) {
        AVPlayerEngine.resolve(self)?.setVolume(volume, muted: muted)
        DemuxEngine.resolve(self)?.setVolume(volume, muted: muted)
    }

    /// Yields true while Apple's player sends the stream to AirPlay. An
    /// engine without Apple's player yields false once.
    @MainActor func airPlayActivity() -> AsyncStream<Bool> {
        guard let system = AVPlayerEngine.resolve(self) else {
            return AsyncStream { $0.yield(false) }
        }
        return system.externalPlayback()
    }
}

extension RoutedEngine {
    /// The engine every player screen uses: HLS and the files the system
    /// reads play on Apple's player, raw broadcast streams, Matroska and AVI
    /// on the demuxing engine.
    /// Both share the TV's mode on Apple TV and the picture held over a switch.
    /// Each one joins `OpenEngines`, so Play on can stop them all.
    @MainActor static func app() -> RoutedEngine {
        let display = DisplayMatcher()
        let hold = FrameHold()
        let engine = RoutedEngine(
            system: AVPlayerEngine(display: display, hold: hold), demuxer: DemuxEngine(display: display, hold: hold), gate: .app)
        OpenEngines.shared.add(engine)
        return engine
    }
}

extension StreamGate {
    /// The gate every app engine checks; closed while this phone, iPad or
    /// Mac is connected to an Apple TV
    /// (play-on-apple-tv/the-phone-opens-no-stream-while-connected).
    static let app = StreamGate()
}

extension PlaybackEngine {
    /// Closes the Picture in Picture window on whichever engine has one open.
    @MainActor func stopPictureInPicture() {
        #if os(iOS) || os(macOS)
            AVPlayerEngine.resolve(self)?.pictureInPicture?.stopPictureInPicture()
            DemuxEngine.resolve(self)?.stopPictureInPicture()
        #endif
    }
}

/// Every engine the app made, held weakly, so one call can close every
/// stream this device has open
/// (play-on-apple-tv/starts-at-once-on-the-same-network, the phone was
/// playing the same thing).
@MainActor
final class OpenEngines {
    static let shared = OpenEngines()

    private struct Held {
        weak var engine: (any PlaybackEngine)?
    }

    private var held: [Held] = []

    func add(_ engine: any PlaybackEngine) {
        held.removeAll { $0.engine == nil }
        held.append(Held(engine: engine))
    }

    /// The engines still alive.
    var engines: [any PlaybackEngine] {
        held.compactMap(\.engine)
    }

    /// Closes Picture in Picture, then stops every engine, not pauses, so
    /// each HTTP connection and demuxer closes. Returns once each reports
    /// it has stopped.
    func stopAll() async {
        let engines = engines
        for engine in engines { engine.stopPictureInPicture() }
        for engine in engines { await engine.stop() }
    }
}
