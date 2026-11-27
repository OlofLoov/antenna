import Foundation

/// The words Play on shows on the phone and the TV. `tv` is the TV's name as
/// the menu lists it, `device` the sender's name; both are the user's own
/// text and keep their direction in a right-to-left sentence.
public enum PlayOnText {
    /// The button with one Apple TV on the account, and each TV's line in a menu.
    public static func playOn(_ tv: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Play on \(words.source(tv))")
    }

    /// The button that opens the list of TVs.
    public static func playOnMenu(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Play on")
    }

    /// The Guide details' button for a programme on now, or one with catch-up.
    public static func watchOn(_ tv: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Watch on \(words.source(tv))")
    }

    /// A menu row's second line for a TV that answers on the network now.
    public static func readyNow(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Ready now")
    }

    /// A menu row's second line for a TV that is not reachable now.
    public static func playsWhenOpen(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Plays when Antuna opens there")
    }

    /// The menu's last row while local network access is refused.
    public static func allowLocalNetwork(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Allow local network access")
    }

    /// The phone's line once the TV started the request.
    public static func playing(on tv: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Playing on \(words.source(tv))")
    }

    /// The phone's line once a request went through iCloud.
    public static func sent(to tv: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Sent. \(words.source(tv)) offers it when Antuna opens there.")
    }

    /// The phone's line when the TV keeps the request behind its paywall or "Who's watching?".
    public static func waiting(on tv: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Sent. \(words.source(tv)) plays it once Antuna is ready there.")
    }

    /// The phone's line, and the TV's, when the source has no login on the TV.
    public static func noLogin(_ tv: String, source: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("\(words.source(tv)) isn't signed in to \(words.source(source)).")
    }

    /// The phone's line when the source has not reached the TV.
    public static func noSource(_ tv: String, source: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("\(words.source(tv)) doesn't have \(words.source(source)) yet. Try again in a minute.")
    }

    /// The phone's line when the TV has no such channel, film or episode.
    public static func notFound(_ tv: String, item: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("\(words.source(tv)) couldn't find \(words.source(item)).")
    }

    /// The phone's line when the TV asks for its passcode.
    public static func passcode(_ tv: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Enter the passcode on \(words.source(tv)).")
    }

    /// The phone's line when the TV runs an older Antuna.
    public static func updateTV(_ tv: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Update Antuna on \(words.source(tv)) to play from here.")
    }

    /// The phone's line when the TV did not answer and nothing else could carry the request.
    public static func unreachable(_ tv: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("\(words.source(tv)) didn't answer. Open Antuna there and try again.")
    }

    /// The eyebrow on the TV's banner and offer: "From Anna's iPhone".
    public static func from(_ device: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("From \(words.source(device))")
    }

    /// The phone's line for the TV's answer.
    public static func line(
        for result: PlayAnswer.Result, tv: String, item: String, sourceName: String, locale: Locale = .autoupdatingCurrent
    ) -> String {
        switch result {
        case .started: playing(on: tv, locale: locale)
        case .needsPasscode: passcode(tv, locale: locale)
        case .noLogin: noLogin(tv, source: sourceName, locale: locale)
        case .noSource: noSource(tv, source: sourceName, locale: locale)
        case .notFound: notFound(tv, item: item, locale: locale)
        case .waiting: waiting(on: tv, locale: locale)
        case .unsupportedVersion: updateTV(tv, locale: locale)
        }
    }
}
