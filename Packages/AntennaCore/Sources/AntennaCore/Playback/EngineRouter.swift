import Foundation

/// Picks which engine a stream should go through.
public enum EngineRouter {
    public enum Route: Sendable, Equatable { case system, demuxer }

    public static func route(for url: URL) -> Route {
        let ext = url.pathExtension.lowercased()
        if ext == "m3u8" || ext == "mp4" || ext == "mov" || ext == "m4v" { return .system }
        if ext == "ts" || ext == "mpegts" || ext == "mkv" { return .demuxer }
        // Many providers serve TS from extension-less URLs; default to the demuxer
        // and let it hand back to AVPlayer if the first bytes look like HLS.
        return .demuxer
    }
}
