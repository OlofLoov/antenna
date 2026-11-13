import Foundation

/// Picks which engine a stream goes through.
public enum EngineRouter {
    public enum Route: Sendable, Equatable { case system, demuxer }

    /// Extensions Apple's player reads: HLS and ordinary audio and video files.
    public static let systemExtensions: Set<String> = ["m3u8", "mp4", "mov", "m4v", "mp3", "aac", "m4a"]

    /// HLS and ordinary files go to Apple's player. Raw broadcast streams,
    /// Matroska, AVI, addresses with no extension and anything unknown go to
    /// the demuxer, which hands an address that turns out to be HLS back to
    /// Apple's player. Apple's player hands an address whose bytes turn out
    /// to be MPEG-TS, Matroska or AVI to the demuxer.
    public static func route(for url: URL) -> Route {
        systemExtensions.contains(url.pathExtension.lowercased()) ? .system : .demuxer
    }
}

/// Thrown by an engine whose stream turned out to be one the other engine
/// should play. `RoutedEngine` catches it and loads the same address on
/// the other engine.
public enum EngineHandoff: Error, Sendable, Equatable {
    /// HLS at a raw-looking address.
    case toSystemPlayer
    /// MPEG-TS, Matroska or AVI at an address that names a file Apple's
    /// player reads, such as an episode listed as `.mp4` that is really `.mkv`.
    case toDemuxer
}

/// What the first bytes of a stream look like.
public enum StreamSniff: Sendable, Equatable {
    case hls
    case mpegTS
    /// Matroska or WebM, from the EBML header.
    case matroska
    /// A RIFF AVI file.
    case avi
    case html
    case other

    /// True for the containers only the demuxer reads.
    public var needsDemuxer: Bool {
        self == .mpegTS || self == .matroska || self == .avi
    }

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
        } else if bytes.starts(with: [0x1A, 0x45, 0xDF, 0xA3]) {
            self = .matroska
        } else if bytes.count >= 12, bytes.starts(with: Array("RIFF".utf8)), Array(bytes[8..<12]) == Array("AVI ".utf8) {
            self = .avi
        } else if text.hasPrefix("<!doctype html") || text.hasPrefix("<html") || text.hasPrefix("<head") {
            self = .html
        } else {
            self = .other
        }
    }
}
