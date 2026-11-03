import Foundation

/// Abstraction over the two playback paths the app will carry:
///
/// - `AVPlayer` for HLS (`.m3u8`) and anything else the system can demux.
/// - A demuxing engine (FFmpeg demux → VideoToolbox decode →
///   `AVSampleBufferVideoRenderer`) for raw MPEG-TS, which `AVPlayer` cannot
///   play over HTTP. That path is what keeps HDR / Dolby Vision / Atmos on the
///   system route instead of being tone-mapped by a software renderer.
///
/// The UI only talks to this protocol, so the engine can be swapped per stream.
public protocol PlaybackEngine: AnyObject, Sendable {
    var state: PlaybackState { get async }
    func load(_ url: URL) async throws
    func play() async
    func pause() async
    func stop() async
}

public enum PlaybackState: Sendable, Equatable {
    case idle
    case loading
    case playing
    case paused
    case failed(String)
}

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
