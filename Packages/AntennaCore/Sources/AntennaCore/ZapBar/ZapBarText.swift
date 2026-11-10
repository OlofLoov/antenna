import Foundation

/// How much of a programme is left, as the zap bar and the channel overlay
/// show it (tv-zap-bar-and-number-entry/what-is-on-and-what-is-next).
/// Minutes round up; under a minute, or past the end, reads "Ends now".
public enum RemainingTime {
    public static let endsNow = "Ends now"

    public static func text(until end: Date, now: Date) -> String {
        let seconds = end.timeIntervalSince(now)
        guard seconds >= 60 else { return endsNow }
        let minutes = Int((seconds / 60).rounded(.up))
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest) min left" }
        return rest == 0 ? "\(hours) h left" : "\(hours) h \(rest) min left"
    }
}

/// How far into a programme `now` is, from 0 to 1. A programme with no
/// length counts as over.
public enum ProgrammeProgress {
    public static func fraction(start: Date, end: Date, now: Date) -> Double {
        let length = end.timeIntervalSince(start)
        guard length > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(start) / length))
    }
}

/// The picture and sound badges of the zap bar
/// (tv-zap-bar-and-number-entry/picture-and-sound-quality). A badge that
/// would say nothing useful is nil.
public enum QualityBadge {
    /// "4K" from 2160 lines, "1080p" from 1080, "720p" from 720, nil below.
    public static func picture(height: Int) -> String? {
        switch height {
        case 2160...: "4K"
        case 1080...: "1080p"
        case 720...: "720p"
        default: nil
        }
    }

    /// The codec and the layout, as in "AAC 5.1", for 1, 2, 6 and 8
    /// channels. Other counts, and sound the device cannot decode, are nil.
    /// An empty codec name leaves only the layout.
    public static func sound(_ audio: PresentationInfo.Audio) -> String? {
        guard audio.isDecodable, [1, 2, 6, 8].contains(audio.channels) else { return nil }
        guard !audio.codec.isEmpty else {
            return SoundFormat.display(codec: "", channels: audio.channels).trimmingCharacters(in: .whitespaces)
        }
        return SoundFormat.display(codec: audio.codec, channels: audio.channels)
    }
}
