import Foundation
import MediaPlayer

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// What the lock screen and Control Center show for the playing channel
/// (player-controls-and-playback-errors/the-channel-shows-on-the-lock-screen).
/// It holds names only, never a stream or logo address.
struct NowPlayingInfo: Equatable, Sendable {
    /// The programme on now, or the channel's name without one.
    var title: String
    /// "104 Sport One".
    var channelLine: String
    var isPlaying: Bool
    /// The channel's logo, once it is in the image cache.
    var artwork: Data?
}

/// Where the player sends the lock-screen details, and where play and
/// pause from the lock screen come back.
@MainActor
struct NowPlayingSink {
    /// Shows `info`, or clears the lock screen with nil.
    var publish: (NowPlayingInfo?) -> Void
    /// Turns on play and pause, with skip buttons off, and calls back on each.
    var listen: (_ play: @escaping @MainActor () -> Void, _ pause: @escaping @MainActor () -> Void) -> Void

    static let none = NowPlayingSink(publish: { _ in }, listen: { _, _ in })

    /// The system's Now Playing center and remote commands.
    static var system: NowPlayingSink {
        NowPlayingSink(
            publish: { info in
                let center = MPNowPlayingInfoCenter.default()
                guard let info else {
                    center.nowPlayingInfo = nil
                    #if os(macOS)
                        center.playbackState = .stopped
                    #endif
                    return
                }
                var fields: [String: Any] = [
                    MPMediaItemPropertyTitle: info.title,
                    MPMediaItemPropertyArtist: info.channelLine,
                    MPNowPlayingInfoPropertyIsLiveStream: true,
                    MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue,
                    MPNowPlayingInfoPropertyPlaybackRate: info.isPlaying ? 1.0 : 0.0,
                ]
                if let data = info.artwork, let artwork = NowPlayingArtwork.make(data) {
                    fields[MPMediaItemPropertyArtwork] = artwork
                }
                center.nowPlayingInfo = fields
                #if os(macOS)
                    center.playbackState = info.isPlaying ? .playing : .paused
                #endif
            },
            listen: { play, pause in
                let commands = MPRemoteCommandCenter.shared()
                for command in [
                    commands.nextTrackCommand, commands.previousTrackCommand, commands.skipForwardCommand,
                    commands.skipBackwardCommand, commands.seekForwardCommand, commands.seekBackwardCommand,
                    commands.changePlaybackPositionCommand,
                ] {
                    command.isEnabled = false
                }
                commands.playCommand.isEnabled = true
                commands.pauseCommand.isEnabled = true
                commands.togglePlayPauseCommand.isEnabled = true
                commands.playCommand.addTarget { _ in
                    MainActor.assumeIsolated { play() }
                    return .success
                }
                commands.pauseCommand.addTarget { _ in
                    MainActor.assumeIsolated { pause() }
                    return .success
                }
            })
    }
}

/// Logo bytes the image cache already holds, and the lock-screen artwork
/// made from them.
enum NowPlayingArtwork {
    /// The logo's bytes when an earlier download left them in the shared
    /// cache. Never downloads.
    static func cached(_ url: URL?) -> Data? {
        guard let url else { return nil }
        return URLCache.shared.cachedResponse(for: URLRequest(url: url))?.data
    }

    static func make(_ data: Data) -> MPMediaItemArtwork? {
        #if os(macOS)
            guard let image = NSImage(data: data) else { return nil }
        #else
            guard let image = UIImage(data: data) else { return nil }
        #endif
        return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}
