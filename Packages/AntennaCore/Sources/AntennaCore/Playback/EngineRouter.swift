import Foundation

/// Picks which engine a stream goes through.
public enum EngineRouter {
    public enum Route: Sendable, Equatable { case system, demuxer }

    /// Extensions Apple's player reads: HLS and ordinary audio and video files.
    public static let systemExtensions: Set<String> = ["m3u8", "mp4", "mov", "m4v", "mp3", "aac", "m4a"]

    /// HLS and ordinary files go to Apple's player. Raw broadcast streams,
    /// Matroska, AVI, addresses with no extension and anything unknown go to
    /// the demuxer, which hands an address that turns out to be HLS back to
    /// Apple's player.
    public static func route(for url: URL) -> Route {
        systemExtensions.contains(url.pathExtension.lowercased()) ? .system : .demuxer
    }
}

/// Thrown by a demuxing engine whose stream turned out to be one Apple's
/// player should play, such as HLS at a raw-looking address. `RoutedEngine`
/// catches it and loads the same address on the system engine.
public enum EngineHandoff: Error, Sendable, Equatable {
    case toSystemPlayer
}

/// What the first bytes of a stream look like.
public enum StreamSniff: Sendable, Equatable {
    case hls
    case mpegTS
    case html
    case other

    /// Reads the start of a response body.
    public init(_ head: Data) {
        let bytes = [UInt8](head.prefix(512))
        var start = 0
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { start = 3 }
        while start < bytes.count, [0x20, 0x09, 0x0A, 0x0D].contains(bytes[start]) { start += 1 }
        let text = String(decoding: bytes[start...], as: UTF8.self).lowercased()
        if text.hasPrefix("#extm3u") {
            self = .hls
        } else if head.count > 188, head[head.startIndex] == 0x47, head[head.startIndex + 188] == 0x47 {
            self = .mpegTS
        } else if text.hasPrefix("<!doctype html") || text.hasPrefix("<html") || text.hasPrefix("<head") {
            self = .html
        } else {
            self = .other
        }
    }
}
