import Foundation

/// The title and explanation the error screen shows for a failure reason.
/// Messages are built from the reason and the source's display name only,
/// so no stream address, server name, username or password can reach them.
public struct FailureMessage: Sendable, Equatable {
    /// Where the message shows. Apple TV signs in on the device itself, so
    /// its login messages differ.
    public enum Device: Sendable, Equatable {
        case appleTV
        case other
    }

    public var title: String
    public var explanation: String

    public init(title: String, explanation: String) {
        self.title = title
        self.explanation = explanation
    }

    /// `source` is the source's display name, such as "Acme TV".
    /// `silentSeconds` is how long nothing arrived before a `.timedOut`.
    /// `connectionDetail` is a short plain cause for `.unreachable`, such as
    /// "server not found", left out of the text when nil.
    public init(
        _ failure: PlaybackFailure, source name: String, device: Device, silentSeconds: Int = 8, connectionDetail: String? = nil,
        locale: Locale = .autoupdatingCurrent
    ) {
        let words = Words(locale)
        let source = words.source(name)
        switch failure {
        case .offline:
            self.init(
                title: words("You're offline"),
                explanation: words("Connect to the internet and try again. Playback resumes on its own when the connection returns."))
        case .unreachable:
            self.init(
                title: words("Could not reach \(source)"),
                explanation: connectionDetail.map { words("The connection failed (\($0)). Check the network, or a VPN if one is on.") }
                    ?? words("The connection failed. Check the network, or a VPN if one is on."))
        case .secureConnectionFailed:
            self.init(
                title: words("Could not reach \(source)"),
                explanation: words("The secure connection failed. Check the network, or a VPN if one is on."))
        case .loginNotOnDevice where device == .appleTV:
            self.init(title: words("Sign in needed"), explanation: words("Sign in to \(source) on this Apple TV to play its channels."))
        case .loginNotOnDevice:
            self.init(
                title: words("Waiting for login"),
                explanation: words("The login for \(source) has not reached this device from iCloud Keychain yet."))
        case .notAllowed:
            self.init(
                title: words("Sign-in refused"),
                explanation: device == .appleTV
                    ? words(
                        """
                        \(source) rejected the login. Sign in again on this Apple TV, or ask the \
                        provider whether the account has expired.
                        """
                    )
                    : words(
                        """
                        \(source) rejected the login. Check the username and password in Settings, \
                        or ask the provider whether the account has expired.
                        """
                    ))
        case .notFound:
            self.init(
                title: words("Stream not found"),
                explanation: words(
                    """
                    \(source) returned 404 for this channel. The channel may have moved or \
                    been removed by the provider.
                    """))
        case .serverBusy:
            self.init(title: words("Provider busy"), explanation: words("\(source) is busy right now. Try again in a moment."))
        case .serverError:
            self.init(
                title: words("Provider error"),
                explanation: words("\(source) returned a server error. Its server is having trouble. Try again in a moment."))
        case .refused(let status):
            self.init(title: words("Stream unavailable"), explanation: words("\(source) returned \(String(status)) for this channel."))
        case .timedOut:
            self.init(title: words("Stream stopped"), explanation: words("\(source) did not send any data for \(silentSeconds) seconds."))
        case .stoppedSendingData:
            self.init(title: words("Stream stopped"), explanation: words("\(source) stopped sending data."))
        case .unreadable:
            self.init(
                title: words("Stream could not be read"),
                explanation: words(
                    "\(source) sent data that is not a playable stream. The address may point to a web page or an empty file."))
        case .cannotDecode(let codec):
            self.init(
                title: words("Format not supported"),
                explanation:
                    words(
                        """
                        This stream uses \(CodecName.display(codec)), which this device cannot \
                        play. Trying again will not help. Pick another channel or ask the provider \
                        for a stream in a supported format.
                        """
                    ))
        case .noDecoderFree:
            self.init(
                title: words("Can't play another stream"), explanation: words("This device is already playing as many streams as it can."))
        }
    }
}

/// The other lines the player shows around waiting and failure.
public enum PlayerStatusText {
    public static func buffering(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Buffering")
    }
    public static func tryAgain(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Try again")
    }
    public static func signIn(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Sign in")
    }
    /// The error's button that opens the channel list on the current group.
    public static func channels(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Channels")
    }

    /// Shown under the spinner after it has spun for ten seconds.
    public static func slowSource(_ source: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Still buffering. \(words.source(source)) is sending data slowly.")
    }

    /// Shown in place of the spinner while the engine reconnects.
    public static func reconnecting(attempt: Int, of total: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Reconnecting… attempt \(attempt) of \(total)")
    }

    /// The Apple TV error's source line. `time` is the attempt's time as the
    /// screen formats it, such as "21:34".
    public static func attempted(source: String, at time: String, locale: Locale = .autoupdatingCurrent) -> String {
        let words = Words(locale)
        return words("Source: \(words.source(source)) · Attempted at \(time)")
    }

    public static func changeChannelHint(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Swipe up or down for another channel. Menu opens the tab bar.")
    }
}
