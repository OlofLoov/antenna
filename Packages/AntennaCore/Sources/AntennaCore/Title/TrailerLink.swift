import Foundation

/// Which trailer links the app can play itself
/// (title-detail-and-episode-picker/trailer).
public enum TrailerLink {
    /// The endings of video files and HLS playlists the players open.
    static let playable: Set<String> = ["m3u8", "mp4", "m4v", "mov"]

    /// True for an http or https link to a video file or an HLS playlist.
    /// False for a web page, YouTube included, which only a browser can show.
    public static func playsInApp(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return false }
        guard let host = url.host()?.lowercased(), !isYouTube(host) else { return false }
        return playable.contains(url.pathExtension.lowercased())
    }

    private static func isYouTube(_ host: String) -> Bool {
        host == "youtu.be" || host == "youtube.com" || host.hasSuffix(".youtube.com")
    }
}
