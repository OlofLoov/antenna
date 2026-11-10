import Foundation

/// What the engine is doing.
public enum PlaybackState: Sendable, Equatable {
    case idle
    /// Opening a stream, including tune retries, until the first frame.
    case loading
    case playing
    case paused
    /// Played, now waiting for data without a new connection yet.
    case buffering
    /// Lost the stream after it played and is connecting again. `attempt`
    /// counts from 1 up to `of`.
    case reconnecting(attempt: Int, of: Int)
    /// A film reached its end. Nothing more is fetched until `play`.
    case ended
    case failed(PlaybackFailure)
}

/// Why a stream cannot play. The same cause gives the same reason on every
/// engine, and no reason carries the stream address.
public enum PlaybackFailure: Error, Sendable, Hashable {
    /// No internet connection.
    case offline
    /// The server could not be reached, including a refused local network prompt.
    case unreachable
    case secureConnectionFailed
    /// The source's login is not in this device's Keychain yet.
    case loginNotOnDevice
    /// 401 or 403.
    case notAllowed
    /// 404.
    case notFound
    /// 429.
    case serverBusy
    /// 5xx.
    case serverError
    /// Any other HTTP refusal, with its status code.
    case refused(status: Int)
    case timedOut
    /// The stream played, then the server stopped sending.
    case stoppedSendingData
    /// The address or the bytes behind it are not a stream this app can read.
    case unreadable
    /// The stream is in a format this device cannot decode, named by codec.
    case cannotDecode(codec: String)
    /// Every hardware decoder is in use.
    case noDecoderFree
}

/// Thrown by `seek(to:)` when the stream cannot skip.
public enum SeekRefusal: Error, Sendable, Equatable {
    case live
    case notSeekable
}

/// How a stream should open.
public struct PlaybackOptions: Sendable, Equatable {
    /// Where a film starts. Ignored for live TV, for films that cannot skip
    /// and when it is past the end.
    public var startPosition: Duration?
    /// Overrides whether the stream counts as live. Nil lets the stream decide;
    /// catch-up passes false.
    public var isLive: Bool?
    /// Language codes in the user's order, for example `["sv", "en"]`.
    public var preferredAudioLanguages: [String]
    public var preferredSubtitleLanguages: [String]

    public init(
        startPosition: Duration? = nil, isLive: Bool? = nil, preferredAudioLanguages: [String] = [],
        preferredSubtitleLanguages: [String] = []
    ) {
        self.startPosition = startPosition
        self.isLive = isLive
        self.preferredAudioLanguages = preferredAudioLanguages
        self.preferredSubtitleLanguages = preferredSubtitleLanguages
    }
}

/// What an engine can do on this device.
public struct EngineCapabilities: Sendable, Equatable {
    public var supportsPictureInPicture: Bool

    public init(supportsPictureInPicture: Bool) {
        self.supportsPictureInPicture = supportsPictureInPicture
    }
}

/// The picture and sound format of what is on screen.
public struct PresentationInfo: Sendable, Equatable {
    public struct Video: Sendable, Equatable {
        public var width: Int
        public var height: Int
        public var frameRate: Double?
        public var dynamicRange: DynamicRange
        /// A short codec name such as "h264" or "hevc".
        public var codec: String
        /// True when the stream is interlaced. `frameRate` is then the rate
        /// it is shown at after deinterlacing, one picture per field.
        public var isInterlaced: Bool

        public init(
            width: Int, height: Int, frameRate: Double?, dynamicRange: DynamicRange, codec: String, isInterlaced: Bool = false
        ) {
            self.width = width
            self.height = height
            self.frameRate = frameRate
            self.dynamicRange = dynamicRange
            self.codec = codec
            self.isInterlaced = isInterlaced
        }
    }

    public struct Audio: Sendable, Equatable {
        /// A short codec name such as "aac", "ac3" or "eac3".
        public var codec: String
        public var channels: Int
        /// False when the device cannot decode this sound and plays without it.
        public var isDecodable: Bool

        public init(codec: String, channels: Int, isDecodable: Bool) {
            self.codec = codec
            self.channels = channels
            self.isDecodable = isDecodable
        }
    }

    public enum DynamicRange: Sendable, Equatable {
        case sdr, hdr10, hlg, dolbyVision
    }

    /// Nil for a stream with no picture, such as radio.
    public var video: Video?
    public var audio: Audio?

    public init(video: Video?, audio: Audio?) {
        self.video = video
        self.audio = audio
    }
}

/// One audio or subtitle track.
public struct MediaTrack: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Equatable { case audio, subtitle }

    /// "audio-n" or "subtitle-n", counted from 0 in stream order.
    public var id: String
    public var kind: Kind
    /// The language code the stream gives, as written, for example "en", "swe" or "pt-BR".
    public var languageCode: String?
    /// The provider's own name for the track, passed on as written.
    public var name: String?
    /// True for the track the stream marks as its default.
    public var isDefault: Bool

    public init(id: String, kind: Kind, languageCode: String?, name: String?, isDefault: Bool) {
        self.id = id
        self.kind = kind
        self.languageCode = languageCode
        self.name = name
        self.isDefault = isDefault
    }
}

/// The audio and subtitle tracks of the stream on screen and which ones play.
public struct TrackList: Sendable, Equatable {
    public var audio: [MediaTrack]
    public var subtitles: [MediaTrack]
    public var selectedAudio: MediaTrack.ID?
    /// Nil when subtitles are off.
    public var selectedSubtitle: MediaTrack.ID?

    public static let empty = TrackList(audio: [], subtitles: [], selectedAudio: nil, selectedSubtitle: nil)

    public init(audio: [MediaTrack], subtitles: [MediaTrack], selectedAudio: MediaTrack.ID?, selectedSubtitle: MediaTrack.ID?) {
        self.audio = audio
        self.subtitles = subtitles
        self.selectedAudio = selectedAudio
        self.selectedSubtitle = selectedSubtitle
    }
}

/// Where playback is.
public struct PlaybackPosition: Sendable, Equatable {
    public var time: Duration
    /// Nil for live TV and for streams whose length is not known.
    public var duration: Duration?
    public var isLive: Bool

    public static let zero = PlaybackPosition(time: .zero, duration: nil, isLive: false)

    public init(time: Duration, duration: Duration?, isLive: Bool) {
        self.time = time
        self.duration = duration
        self.isLive = isLive
    }
}

/// One subtitle line to draw.
public struct SubtitleCue: Sendable, Equatable {
    public var text: String

    public init(text: String) {
        self.text = text
    }
}
