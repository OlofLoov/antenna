import Foundation

/// The audio language and subtitles last picked on one channel
/// (playback-engine/audio-and-subtitle-languages).
public struct LanguagePick: Sendable, Equatable, Codable {
    /// The language code of the sound picked, as the stream gave it.
    public var audio: String?
    /// The language code of the subtitles picked, nil when they were turned off.
    public var subtitle: String?

    public init(audio: String?, subtitle: String?) {
        self.audio = audio
        self.subtitle = subtitle
    }

    /// The languages of the tracks `tracks` has selected.
    public init(_ tracks: TrackList) {
        audio = tracks.audio.first { $0.id == tracks.selectedAudio }?.languageCode
        subtitle = tracks.subtitles.first { $0.id == tracks.selectedSubtitle }?.languageCode
    }
}

/// Which audio and subtitle tracks a stream starts with
/// (playback-engine/audio-and-subtitle-languages).
///
/// A pick remembered for the channel wins while the stream still has those
/// tracks. Otherwise the user's preferred languages decide in order: sound in
/// the first preferred language the stream has, else the stream's default
/// sound, else its first; subtitles in the first preferred subtitle language
/// it has, else none.
public enum TrackChoice {
    /// The audio and subtitle track ids to start with.
    public static func initial(
        audio: [MediaTrack], subtitles: [MediaTrack], options: PlaybackOptions
    ) -> (audio: MediaTrack.ID?, subtitle: MediaTrack.ID?) {
        (
            self.audio(audio, preferred: options.preferredAudioLanguages, remembered: options.remembered),
            subtitle(subtitles, preferred: options.preferredSubtitleLanguages, remembered: options.remembered)
        )
    }

    static func audio(_ tracks: [MediaTrack], preferred: [String], remembered: LanguagePick?) -> MediaTrack.ID? {
        if let code = remembered?.audio, let track = tracks.first(where: { sameLanguage($0.languageCode, code) }) {
            return track.id
        }
        for code in preferred {
            if let track = tracks.first(where: { sameLanguage($0.languageCode, code) }) { return track.id }
        }
        return (tracks.first(where: \.isDefault) ?? tracks.first)?.id
    }

    static func subtitle(_ tracks: [MediaTrack], preferred: [String], remembered: LanguagePick?) -> MediaTrack.ID? {
        if let remembered {
            // Subtitles turned off on this channel stay off; a remembered
            // language the stream no longer has falls back to preference.
            guard let code = remembered.subtitle else { return nil }
            if let track = tracks.first(where: { sameLanguage($0.languageCode, code) }) { return track.id }
        }
        for code in preferred {
            if let track = tracks.first(where: { sameLanguage($0.languageCode, code) }) { return track.id }
        }
        return nil
    }

    /// True when two language codes name the same language: "en", "eng" and
    /// "en-GB" match, as do "de", "deu" and "ger".
    public static func sameLanguage(_ code: String?, _ other: String) -> Bool {
        guard let code, let left = base(code), let right = base(other) else { return false }
        return left == right
    }

    /// The two-letter code for a language code, or the code itself lowercased
    /// when it has none.
    static func base(_ code: String) -> String? {
        let primary = code.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map { $0.lowercased() } ?? ""
        guard !primary.isEmpty, primary != "und" else { return nil }
        if let terminology = bibliographic[primary] { return terminology }
        if primary.count == 3, let short = Locale.LanguageCode(primary).identifier(.alpha2) { return short }
        return primary
    }

    /// ISO 639-2 bibliographic codes, which broadcasters use, mapped to two letters.
    private static let bibliographic: [String: String] = [
        "alb": "sq", "arm": "hy", "baq": "eu", "bur": "my", "chi": "zh", "cze": "cs", "dut": "nl", "fre": "fr",
        "geo": "ka", "ger": "de", "gre": "el", "ice": "is", "mac": "mk", "mao": "mi", "may": "ms", "per": "fa",
        "rum": "ro", "slo": "sk", "tib": "bo", "wel": "cy",
    ]
}

/// The language pick of each channel on this device, newest last, at most
/// `limit` channels with the oldest dropped. Keys are channel identifiers,
/// never stream addresses.
public struct LanguageMemory: Sendable, Equatable, Codable {
    public struct Entry: Sendable, Equatable, Codable {
        public var channel: String
        public var pick: LanguagePick
    }

    public static let limit = 500

    public private(set) var entries: [Entry] = []

    public init() {}

    public func pick(for channel: String) -> LanguagePick? {
        entries.last { $0.channel == channel }?.pick
    }

    /// Keeps `pick` for `channel` as the newest entry.
    public mutating func remember(_ pick: LanguagePick, for channel: String) {
        entries.removeAll { $0.channel == channel }
        entries.append(Entry(channel: channel, pick: pick))
        if entries.count > Self.limit { entries.removeFirst(entries.count - Self.limit) }
    }
}
