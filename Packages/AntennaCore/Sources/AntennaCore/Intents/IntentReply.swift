import Foundation

/// Why a Siri or Shortcuts action did nothing, with the sentence it says
/// (app-intents/a-clear-reply-when-a-channel-or-title-cannot-play).
///
/// Names are kept as given and cleaned when the sentence is built, so no
/// reply and no debug description ever holds a link, a login, a port, an
/// HTTP status or an error code.
public enum IntentFailure: Error, Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    /// The device the reply asks the user to unlock.
    public enum Device: Sendable, Equatable {
        case iPhone, iPad, mac
    }

    case notUnlocked
    case noSources
    case offline
    case stillLoading
    case sourceFailed(source: String)
    case loginMissing(source: String)
    case channelSourceGone
    case titleSourceGone
    /// The channel's name when it is known; a gone channel's name usually is not.
    case channelGone(channel: String?, source: String)
    case titleGone(title: String?, source: String)
    case locked(channel: String)
    case nothingPlaying
    case alreadyFavorite(channel: String)
    case notFavorite(channel: String)
    /// The Keychain cannot be read before the first unlock after a restart.
    case needsUnlock(Device)

    /// One plain sentence.
    public var description: String {
        switch self {
        case .notUnlocked: "Antenna isn't unlocked on this device yet. Open Antenna to continue."
        case .noSources: "Antenna has no sources yet. Open Antenna to add one."
        case .offline: "You're offline. Connect to the internet and try again."
        case .stillLoading: "Antenna is still loading your library. Try again in a moment."
        case .sourceFailed(let source): "Antenna couldn't reach \(IntentText.source(source)). Try again later."
        case .loginMissing(let source): "The login for \(IntentText.source(source)) hasn't synced from iCloud to this device yet."
        case .channelSourceGone: "That channel's source is no longer in Antenna."
        case .titleSourceGone: "That title's source is no longer in Antenna."
        case .channelGone(let channel, let source):
            "\(channel.map(IntentText.channel) ?? "That channel") is no longer in \(IntentText.source(source))."
        case .titleGone(let title, let source):
            "\(title.map(IntentText.title) ?? "That title") is no longer available from \(IntentText.source(source))."
        case .locked(let channel): "\(IntentText.channel(channel)) is in a locked group. Unlock it in Antenna first."
        case .nothingPlaying: "Antenna isn't playing a channel right now. Say which channel instead."
        case .alreadyFavorite(let channel): "\(IntentText.channel(channel)) is already a favorite."
        case .notFavorite(let channel): "\(IntentText.channel(channel)) isn't a favorite."
        case .needsUnlock(let device): "Unlock your \(IntentText.name(device)) once and try again."
        }
    }

    /// The same sentence, so a log or a crash report holds nothing more.
    public var debugDescription: String { description }
}

/// The words Siri and Shortcuts say and show for Antenna's actions
/// (app-intents capability). Every name passes through here first.
public enum IntentText {
    /// What Siri asks when a channel is missing or matched nothing.
    public static let whichChannel = "Which channel?"
    /// What Siri asks when a title is missing or matched nothing.
    public static let whichTitle = "Which movie or series?"

    /// "Added <channel> to favorites."
    public static func added(_ channel: String) -> String {
        "Added \(Self.channel(channel)) to favorites."
    }

    /// "Removed <channel> from favorites."
    public static func removed(_ channel: String) -> String {
        "Removed \(Self.channel(channel)) from favorites."
    }

    /// A source's name, or "your source" when the name looks like a link
    /// or a login (app-intents/shortcuts-never-hold-a-password).
    public static func source(_ name: String) -> String {
        clean(name) ?? "your source"
    }

    /// A channel's name, or "This channel" when it looks like a link or a login.
    public static func channel(_ name: String) -> String {
        clean(name) ?? "This channel"
    }

    /// A title's name, or "This title" when it looks like a link or a login.
    public static func title(_ name: String) -> String {
        clean(name) ?? "This title"
    }

    /// A channel's second line in Shortcuts and Siri: "201 · Sport ·
    /// Cabin", leaving out what it lacks.
    public static func channelSubtitle(number: ChannelNumber?, group: String?, source: String) -> String {
        let group = group.flatMap { $0.allSatisfy(\.isWhitespace) ? nil : clean($0) }
        return [number?.description, group, Self.source(source)].compactMap(\.self).joined(separator: " · ")
    }

    /// A title's second line: "Movie · Cabin" or "Series · Cabin".
    public static func titleSubtitle(_ kind: ShelfTitle.Kind, source: String) -> String {
        "\(kind == .movie ? "Movie" : "Series") · \(Self.source(source))"
    }

    static func name(_ device: IntentFailure.Device) -> String {
        switch device {
        case .iPhone: "iPhone"
        case .iPad: "iPad"
        case .mac: "Mac"
        }
    }

    /// `name` trimmed, or nil when it is blank or holds a scheme, a login
    /// or a port: "://", "@", or a letter or dot, a colon and a digit, as
    /// in "host.tv:8080". A ratio such as "16:9" stays.
    static func clean(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("://"), !trimmed.contains("@") else { return nil }
        let characters = Array(trimmed)
        for offset in characters.indices.dropFirst().dropLast() where characters[offset] == ":" {
            let before = characters[offset - 1]
            let after = characters[offset + 1]
            if before.isLetter || before == ".", after.isASCII, after.isNumber { return nil }
        }
        return trimmed
    }
}
