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

    /// The languages of the tracks `tracks` has selected. Forced subtitles
    /// count as off: the starting rule brings them back on its own.
    public init(_ tracks: TrackList) {
        audio = tracks.audio.first { $0.id == tracks.selectedAudio }?.languageCode
        subtitle = tracks.subtitles.first { $0.id == tracks.selectedSubtitle && !$0.isForced }?.languageCode
    }
}

/// When a stream's subtitles start (playback-engine/subtitles-start-by-the-subtitle-setting).
public enum SubtitleMode: String, Sendable, CaseIterable, Codable {
    /// Off. Forced subtitles in the user's language still show.
    case off
    /// On in the user's language when the sound is not in one of the user's languages.
    case auto
    /// On in the user's first language the stream has, whatever the sound.
    case always
}

/// Which audio and subtitle tracks a stream starts with
/// (playback-engine/audio-and-subtitle-languages,
/// playback-engine/subtitles-start-by-the-subtitle-setting,
/// playback-engine/forced-subtitles-in-your-language-show).
///
/// A pick remembered for the channel wins while the stream still has those
/// tracks. Otherwise sound is in the first preferred audio language the
/// stream has, else its default, else its first. Subtitles follow the
/// subtitle mode: Auto starts them in the first preferred subtitle language
/// the stream has when the chosen sound is in none of those languages,
/// Always starts them whatever the sound, Off leaves them off. With no full
/// subtitles on, a forced track in the first preferred language that has
/// one shows.
public enum TrackChoice {
    /// The audio and subtitle track ids to start with.
    public static func initial(
        audio: [MediaTrack], subtitles: [MediaTrack], options: PlaybackOptions
    ) -> (audio: MediaTrack.ID?, subtitle: MediaTrack.ID?) {
        let sound = self.audio(audio, preferred: options.preferredAudioLanguages, remembered: options.remembered)
        let spoken = audio.first { $0.id == sound }?.languageCode
        let subtitle = subtitle(
            subtitles, preferred: options.preferredSubtitleLanguages, mode: options.subtitleMode, sound: spoken,
            remembered: options.remembered)
        return (sound, subtitle)
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

    static func subtitle(
        _ tracks: [MediaTrack], preferred: [String], mode: SubtitleMode, sound: String?, remembered: LanguagePick?
    ) -> MediaTrack.ID? {
        let full = tracks.filter { !$0.isForced }
        if let remembered {
            // Subtitles turned off on this channel stay off; a remembered
            // language the stream no longer has falls back to the mode.
            guard let code = remembered.subtitle else { return forced(tracks, preferred: preferred) }
            if let track = full.first(where: { sameLanguage($0.languageCode, code) }) { return track.id }
        }
        // Sound with no language counts as understood.
        let understood = sound.flatMap(base).map { spoken in preferred.contains { base($0) == spoken } } ?? true
        switch mode {
        case .off: break
        case .auto where understood: break
        case .auto, .always:
            if let track = first(of: full, in: preferred) { return track.id }
        }
        return forced(tracks, preferred: preferred)
    }

    /// The forced track in the first of `preferred` that has one.
    private static func forced(_ tracks: [MediaTrack], preferred: [String]) -> MediaTrack.ID? {
        first(of: tracks.filter(\.isForced), in: preferred)?.id
    }

    private static func first(of tracks: [MediaTrack], in preferred: [String]) -> MediaTrack? {
        for code in preferred {
            if let track = tracks.first(where: { sameLanguage($0.languageCode, code) }) { return track }
        }
        return nil
    }

    // MARK: The subtitles switch

    /// True when full subtitles are on; forced ones alone read as off
    /// (player-controls-and-playback-errors/turn-subtitles-on-or-off-in-one-step).
    public static func fullSubtitlesOn(_ tracks: TrackList) -> Bool {
        tracks.subtitles.contains { $0.id == tracks.selectedSubtitle && !$0.isForced }
    }

    /// What one press of the subtitles switch selects: nil when full
    /// subtitles are on, otherwise the first of `preferred` the stream has
    /// in full subtitles, else its first full track, else nil.
    public static func switched(_ tracks: TrackList, preferred: [String]) -> MediaTrack.ID? {
        guard !fullSubtitlesOn(tracks) else { return nil }
        let full = tracks.subtitles.filter { !$0.isForced }
        return (first(of: full, in: preferred) ?? full.first)?.id
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
