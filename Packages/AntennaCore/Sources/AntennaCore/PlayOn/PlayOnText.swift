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
        Words(locale)("Plays if opened within a minute")
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

    /// The bar's first line for three seconds after the TV stopped.
    public static func stopped(on tv: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Stopped on \(words.source(tv))")
    }

    /// The title page's Resume while connected.
    public static func resumeOn(_ tv: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Resume on \(words.source(tv))")
    }

    /// The connected sheet's button that moves what the TV plays to this device.
    public static func playHere(_ kind: PlayDeviceInfo.Kind, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        switch kind {
        case .pad: return words("Play on this iPad")
        case .mac: return words("Play on this Mac")
        case .phone, .tv: return words("Play on this iPhone")
        }
    }

    /// What the TV plays, as the bar's second line: the channel or title,
    /// then the programme or episode.
    public static func statusLine(_ status: PlayStatus, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words.line([words.source(status.title)] + (status.subtitle.map { [words.source($0)] } ?? []))
    }

    /// The phone's line once a request went through iCloud, where it waits a minute.
    public static func sent(to tv: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Sent. \(words.source(tv)) plays it if Antuna opens there within a minute.")
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

    /// The eyebrow on the TV's banners: "From Anna's iPhone".
    public static func from(_ device: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("From \(words.source(device))")
    }

    /// The phone's line when it has no network and nothing was sent
    /// (play-on-apple-tv/waits-in-icloud-when-the-tv-is-not-reachable).
    public static func offline(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("You're offline. Nothing was sent.")
    }

    /// The TV's countdown line, "Starts in 5", with the whole seconds left
    /// (play-on-apple-tv/the-tv-counts-down-a-waiting-request).
    public static func startsIn(_ seconds: Int, locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Starts in \(seconds)")
    }

    /// The phone's line once Cancel took the request back
    /// (play-on-apple-tv/the-phone-can-take-a-request-back).
    public static func canceled(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Canceled.")
    }

    /// The phone's line when Cancel came too late: the TV has the request
    /// and the phone could not reach it, or it plays already.
    public static func alreadyHas(_ tv: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("\(words.source(tv)) already has it.")
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
        case .canceled: canceled(locale)
        }
    }
}
