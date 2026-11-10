import Foundation

extension CodecName {
    /// How a codec name an engine reports reads on screen. "h264" and "avc1"
    /// read "H.264", "hevc", "hvc1" and "hev1" read "HEVC", and so on. A
    /// codec with no entry is upper-cased.
    public static func display(_ codec: String) -> String {
        switch codec.lowercased() {
        case "h264", "avc1", "avc3": "H.264"
        case "hevc", "hvc1", "hev1", "h265": "HEVC"
        case "mpeg2video", "mp2v": "MPEG-2"
        case "aac", "mp4a": "AAC"
        case "ac3", "ac-3": "AC-3"
        case "eac3", "ec-3": "E-AC-3"
        case "mpeg4", "mp4v": "MPEG-4"
        case "dolby vision", "dvh1", "dvhe": "Dolby Vision"
        default: codec.uppercased()
        }
    }
}

/// How a sound format reads, codec then channel layout, as in
/// "AAC Stereo" or "AC-3 5.1".
public enum SoundFormat {
    public static func display(codec: String, channels: Int) -> String {
        let layout: String? =
            switch channels {
            case 1: "Mono"
            case 2: "Stereo"
            case 6: "5.1"
            case 8: "7.1"
            case ...0: nil
            default: "\(channels) channels"
            }
        return [CodecName.display(codec), layout].compactMap(\.self).joined(separator: " ")
    }
}

/// The one-line description of what is playing, such as
/// "MPEG-TS · H.264 1080p · AAC 5.1 · Antenna player". It is built from the
/// engine's reports and never from the stream address.
public enum StreamLine {
    public static let notAvailable = "Stream details not available yet"

    /// `container` is the stream's container as it should read, such as
    /// "MPEG-TS" or "HLS", nil when not known. `presentation` is nil until
    /// the first frame, and the line then reads `notAvailable`.
    public static func text(container: String?, presentation: PresentationInfo?, route: EngineRouter.Route) -> String {
        guard let presentation else { return notAvailable }
        var parts: [String] = []
        if let container { parts.append(container) }
        if let video = presentation.video {
            let scan = video.isInterlaced ? "i" : "p"
            parts.append("\(CodecName.display(video.codec)) \(video.height)\(scan)")
        }
        if let audio = presentation.audio {
            parts.append(SoundFormat.display(codec: audio.codec, channels: audio.channels))
        }
        parts.append(playerName(route))
        return parts.joined(separator: " · ")
    }

    /// The name of the path that plays the stream.
    public static func playerName(_ route: EngineRouter.Route) -> String {
        switch route {
        case .demuxer: "Antenna player"
        case .system: "Apple player"
        }
    }
}
