import AntennaCore
import Foundation
import Network
import os

/// Whether the device has an internet connection, as the system reports it.
struct NetworkWatch: Sendable {
    /// Yields true while a connection is available, first the current
    /// answer, then each change.
    var updates: @Sendable () -> AsyncStream<Bool>

    /// The system's path monitor.
    static var system: NetworkWatch {
        NetworkWatch {
            AsyncStream { continuation in
                let monitor = NWPathMonitor()
                monitor.pathUpdateHandler = { path in continuation.yield(path.status == .satisfied) }
                continuation.onTermination = { _ in monitor.cancel() }
                monitor.start(queue: DispatchQueue(label: "se.codecrave.antenna.network"))
            }
        }
    }

    /// Always connected; nothing ever changes.
    static var online: NetworkWatch {
        NetworkWatch {
            AsyncStream { continuation in continuation.yield(true) }
        }
    }
}

/// Where the player writes what happened. Lines name states and failure
/// reasons only, never a stream address, server, username or password
/// (player-controls-and-playback-errors/error-messages-for-each-reason).
struct PlayerLog: Sendable {
    var write: @Sendable (String) -> Void

    static let logger = Logger(subsystem: "se.codecrave.antenna", category: "player")

    static var system: PlayerLog {
        PlayerLog { line in logger.info("\(line, privacy: .public)") }
    }
}

extension FailureMessage.Device {
    /// The device the app runs on.
    static var current: Self {
        #if os(tvOS)
            .appleTV
        #else
            .other
        #endif
    }
}

extension PlaybackFailure {
    /// The reason's name for a log line, with nothing from the stream.
    var logName: String {
        switch self {
        case .offline: "offline"
        case .unreachable: "unreachable"
        case .secureConnectionFailed: "secureConnectionFailed"
        case .loginNotOnDevice: "loginNotOnDevice"
        case .notAllowed: "notAllowed"
        case .notFound: "notFound"
        case .serverBusy: "serverBusy"
        case .serverError: "serverError"
        case .refused(let status): "refused(\(status))"
        case .timedOut: "timedOut"
        case .stoppedSendingData: "stoppedSendingData"
        case .unreadable: "unreadable"
        case .cannotDecode: "cannotDecode"
        case .noDecoderFree: "noDecoderFree"
        }
    }
}
