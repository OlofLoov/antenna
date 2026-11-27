import AVFoundation
import AVKit
import AntennaCore

extension AVPlayerEngine {
    /// Opens `url` on Apple's player, paused and with no video output, so the
    /// Mac's AirPlay list has a player to route while the demuxer plays on;
    /// nil closes it (playback-engine/a-channel-goes-to-airplay-as-hls). Does
    /// nothing while this engine plays a stream of its own.
    func prepareForAirPlay(_ url: URL?) {
        guard stream == nil else { return }
        guard let url else {
            if player.currentItem != nil, player.rate == 0 { player.replaceCurrentItem(with: nil) }
            return
        }
        var options: [String: Any] = [AVURLAssetHTTPCookiesKey: [HTTPCookie]()]
        options.merge(Self.headerOptions(StreamHeaderBook.shared.headers(for: url))) { _, header in header }
        player.pause()
        player.replaceCurrentItem(with: AVPlayerItem(asset: AVURLAsset(url: url, options: options)))
    }

    #if os(macOS)
        /// Lets the Mac's AirPlay list route this engine's player.
        func attach(to picker: AVRoutePickerView) {
            if picker.player !== player { picker.player = player }
        }
    #endif
}

extension PlaybackEngine {
    /// Prepares `url` for the AirPlay list on the app's Apple player, or closes it with nil.
    @MainActor func prepareForAirPlay(_ url: URL?) {
        AVPlayerEngine.resolve(self)?.prepareForAirPlay(url)
    }

    #if os(macOS)
        /// Lets the Mac's AirPlay list route the app's Apple player.
        @MainActor func attachAirPlayList(_ picker: AVRoutePickerView) {
            AVPlayerEngine.resolve(self)?.attach(to: picker)
        }
    #endif
}

/// Whether the sound goes to an AirPlay device.
enum AirPlayRouteWatch {
    /// Yields true while the sound route is an AirPlay device, first the
    /// current answer, then each change. iPhone and iPad only; elsewhere it
    /// yields nothing, as the Mac's AirPlay list routes one player instead
    /// and Apple TV sends no picture to AirPlay.
    @MainActor static func system() -> AsyncStream<Bool> {
        #if os(iOS)
            AsyncStream { continuation in
                continuation.yield(isAirPlay())
                nonisolated(unsafe) let token = NotificationCenter.default.addObserver(
                    forName: AVAudioSession.routeChangeNotification, object: AVAudioSession.sharedInstance(), queue: .main
                ) { _ in continuation.yield(isAirPlay()) }
                continuation.onTermination = { _ in NotificationCenter.default.removeObserver(token) }
            }
        #else
            AsyncStream { $0.finish() }
        #endif
    }

    #if os(iOS)
        /// True while the sound route's outputs include an AirPlay device.
        nonisolated private static func isAirPlay() -> Bool {
            AVAudioSession.sharedInstance().currentRoute.outputs.contains { $0.portType == .airPlay }
        }
    #endif
}
