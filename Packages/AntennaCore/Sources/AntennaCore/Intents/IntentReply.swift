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
    public var description: String { description(.autoupdatingCurrent) }

    public func description(_ locale: Locale) -> String {
        let words = Words(locale)
        let source = { (name: String) in IntentText.source(name, locale: locale) }
        let channel = { (name: String) in IntentText.channel(name, locale: locale) }
        let title = { (name: String) in IntentText.title(name, locale: locale) }
        return switch self {
        case .notUnlocked: words("Antenna isn't unlocked on this device yet. Open Antenna to continue.")
        case .noSources: words("Antenna has no sources yet. Open Antenna to add one.")
        case .offline: words("You're offline. Connect to the internet and try again.")
        case .stillLoading: words("Antenna is still loading your library. Try again in a moment.")
        case .sourceFailed(let name): words("Antenna couldn't reach \(source(name)). Try again later.")
        case .loginMissing(let name): words("The login for \(source(name)) hasn't synced from iCloud to this device yet.")
        case .channelSourceGone: words("That channel's source is no longer in Antenna.")
        case .titleSourceGone: words("That title's source is no longer in Antenna.")
        case .channelGone(let name?, let from): words("\(channel(name)) is no longer in \(source(from)).")
        case .channelGone(nil, let from): words("That channel is no longer in \(source(from)).")
        case .titleGone(let name?, let from): words("\(title(name)) is no longer available from \(source(from)).")
        case .titleGone(nil, let from): words("That title is no longer available from \(source(from)).")
        case .locked(let name): words("\(channel(name)) is in a locked group. Unlock it in Antenna first.")
        case .nothingPlaying: words("Antenna isn't playing a channel right now. Say which channel instead.")
        case .alreadyFavorite(let name): words("\(channel(name)) is already a favorite.")
        case .notFavorite(let name): words("\(channel(name)) isn't a favorite.")
        case .needsUnlock(let device): words("Unlock your \(IntentText.name(device)) once and try again.")
        }
    }

    /// The same sentence, so a log or a crash report holds nothing more.
    public var debugDescription: String { description }
}

/// The words Siri and Shortcuts say and show for Antenna's actions
/// (app-intents capability). Every name passes through here first.
public enum IntentText {
    /// What Siri asks when a channel is missing or matched nothing.
    public static func whichChannel(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Which channel?")
    }
    /// What Siri asks when a title is missing or matched nothing.
    public static func whichTitle(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Which movie or series?")
    }

    /// "Added <channel> to favorites."
    public static func added(_ channel: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Added \(Self.channel(channel, locale: locale)) to favorites.")
    }

    /// "Removed <channel> from favorites."
    public static func removed(_ channel: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Removed \(Self.channel(channel, locale: locale)) from favorites.")
    }

    /// A source's name, or "your source" when the name looks like a link
    /// or a login (app-intents/shortcuts-never-hold-a-password).
    public static func source(_ name: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return clean(name) ?? words("your source")
    }

    /// A channel's name, or "This channel" when it looks like a link or a login.
    public static func channel(_ name: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return clean(name) ?? words("This channel")
    }

    /// A title's name, or "This title" when it looks like a link or a login.
    public static func title(_ name: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return clean(name) ?? words("This title")
    }

    /// A channel's second line in Shortcuts and Siri: "201 · Sport ·
    /// Cabin", leaving out what it lacks.
    public static func channelSubtitle(
        number: ChannelNumber?, group: String?, source: String, locale: Locale = .autoupdatingCurrent
    ) -> String {
        let group = group.flatMap { $0.allSatisfy(\.isWhitespace) ? nil : clean($0) }
        return [number?.text(locale), group, Self.source(source, locale: locale)].compactMap(\.self).joined(separator: " · ")
    }

    /// A title's second line: "Movie · Cabin" or "Series · Cabin".
    public static func titleSubtitle(_ kind: ShelfTitle.Kind, source: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        let source = Self.source(source, locale: locale)
        return kind == .movie ? words("Movie · \(source)") : words("Series · \(source)")
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
