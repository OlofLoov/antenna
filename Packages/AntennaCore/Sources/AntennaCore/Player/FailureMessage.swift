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
        _ failure: PlaybackFailure, source: String, device: Device, silentSeconds: Int = 8, connectionDetail: String? = nil
    ) {
        let vpn = "Check the network, or a VPN if one is on."
        switch failure {
        case .offline:
            self.init(
                title: "You're offline",
                explanation: "Connect to the internet and try again. Playback resumes on its own when the connection returns.")
        case .unreachable:
            let detail = connectionDetail.map { " (\($0))" } ?? ""
            self.init(title: "Could not reach \(source)", explanation: "The connection failed\(detail). \(vpn)")
        case .secureConnectionFailed:
            self.init(title: "Could not reach \(source)", explanation: "The secure connection failed. \(vpn)")
        case .loginNotOnDevice where device == .appleTV:
            self.init(title: "Sign in needed", explanation: "Sign in to \(source) on this Apple TV to play its channels.")
        case .loginNotOnDevice:
            self.init(
                title: "Waiting for login",
                explanation: "The login for \(source) has not reached this device from iCloud Keychain yet.")
        case .notAllowed:
            let next =
                device == .appleTV
                ? "Sign in again on this Apple TV"
                : "Check the username and password in Settings"
            self.init(
                title: "Sign-in refused",
                explanation: "\(source) rejected the login. \(next), or ask the provider whether the account has expired.")
        case .notFound:
            self.init(
                title: "Stream not found",
                explanation: "\(source) returned 404 for this channel. The channel may have moved or been removed by the provider.")
        case .serverBusy:
            self.init(title: "Provider busy", explanation: "\(source) is busy right now. Try again in a moment.")
        case .serverError:
            self.init(
                title: "Provider error",
                explanation: "\(source) returned a server error. Its server is having trouble. Try again in a moment.")
        case .refused(let status):
            self.init(title: "Stream unavailable", explanation: "\(source) returned \(status) for this channel.")
        case .timedOut:
            self.init(title: "Stream stopped", explanation: "\(source) did not send any data for \(silentSeconds) seconds.")
        case .stoppedSendingData:
            self.init(title: "Stream stopped", explanation: "\(source) stopped sending data.")
        case .unreadable:
            self.init(
                title: "Stream could not be read",
                explanation: "\(source) sent data that is not a playable stream. The address may point to a web page or an empty file.")
        case .cannotDecode(let codec):
            self.init(
                title: "Format not supported",
                explanation:
                    "This stream uses \(CodecName.display(codec)), which this device cannot play. Trying again will not help. "
                    + "Pick another channel or ask the provider for a stream in a supported format.")
        case .noDecoderFree:
            self.init(title: "Can't play another stream", explanation: "This device is already playing as many streams as it can.")
        }
    }
}

/// The other lines the player shows around waiting and failure.
public enum PlayerStatusText {
    public static let buffering = "Buffering"
    public static let tryAgain = "Try again"
    public static let signIn = "Sign in"

    /// Shown under the spinner after it has spun for ten seconds.
    public static func slowSource(_ source: String) -> String {
        "Still buffering. \(source) is sending data slowly."
    }

    /// Shown in place of the spinner while the engine reconnects.
    public static func reconnecting(attempt: Int, of total: Int) -> String {
        "Reconnecting… attempt \(attempt) of \(total)"
    }

    /// The Apple TV error's source line. `time` is the attempt's time as the
    /// screen formats it, such as "21:34".
    public static func attempted(source: String, at time: String) -> String {
        "Source: \(source) · Attempted at \(time)"
    }

    public static let changeChannelHint = "Swipe up or down for another channel. Menu opens the tab bar."
}
