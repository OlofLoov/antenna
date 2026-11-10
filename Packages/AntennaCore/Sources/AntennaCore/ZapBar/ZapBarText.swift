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

/// The rest of the zap bar's words (tv-zap-bar-and-number-entry capability).
public enum ZapBarText {
    public static let guideUnavailable = "Guide unavailable"
    public static let browseHint = "Press to browse channels"

    /// The programme on now, or the guide grid's wording in its place:
    /// "Loading guide…" while it loads, "Guide unavailable" after it failed,
    /// "No programme information" otherwise
    /// (tv-zap-bar-and-number-entry/what-is-on-and-what-is-next).
    public static func line(state: GuideLoadingState, current: Programme?, now: Date) -> GuideLine {
        let line = GuideLine(state: state, current: current, now: now)
        if case .message = line, case .failed = state { return .message(guideUnavailable) }
        return line
    }

    /// "Sport · 4 of 42", from the list's name and the 1-based position in it
    /// (tv-zap-bar-and-number-entry/which-channel-this-is).
    public static func position(list: String, index: Int, count: Int) -> String {
        "\(list) · \(index) of \(count)"
    }

    /// The badges for the stream's state and format: LIVE, then the picture
    /// size and the sound, only while it plays; none while it loads, buffers
    /// or after a failure (tv-zap-bar-and-number-entry/picture-and-sound-quality).
    public static func badges(state: PlaybackState, presentation: PresentationInfo?) -> [String] {
        guard state == .playing else { return [] }
        let picture = presentation?.video.flatMap { QualityBadge.picture(height: $0.height) }
        let sound = presentation?.audio.flatMap(QualityBadge.sound)
        return ["LIVE"] + [picture, sound].compactMap(\.self)
    }
}

extension Channel {
    /// The zap bar's footer before the browse hint: "Catch-up 7 days",
    /// "Catch-up 1 day", "Catch-up" without a count, nil without catch-up
    /// (tv-zap-bar-and-number-entry/catch-up-hint).
    public var catchUpFooter: String? {
        if let days = catchupDays, days > 0 { return "Catch-up \(days) \(days == 1 ? "day" : "days")" }
        return hasCatchup ? "Catch-up" : nil
    }
}
