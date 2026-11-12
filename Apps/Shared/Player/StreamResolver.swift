import AntennaCore
import Foundation

/// The address the engine opens for a channel. A Stalker channel keeps a
/// portal reference until it is tuned, and each tune asks the portal for a
/// fresh address (stalker-portal-source/tuning-gets-a-fresh-stream-address).
/// Every other channel plays its stream address as stored.
enum StreamResolver {
    /// Throws a `PlaybackFailure` when a portal channel cannot be resolved,
    /// so the player shows its failure state and never opens the reference.
    /// The resolved address holds a short-lived key: never store or log it.
    static func address(for channel: Channel, clients: StalkerClients = .shared) async throws -> URL {
        guard StalkerClient.isReference(channel.streamURL) else { return channel.streamURL }
        guard let source = channel.sourceID, let client = clients.client(sourceID: source) else {
            throw PlaybackFailure.loginNotOnDevice
        }
        do {
            return try await client.playableURL(for: channel)
        } catch let error as StalkerError {
            throw PlaybackFailure(error)
        }
    }
}

extension PlaybackFailure {
    /// The player's reason for a portal that did not hand out an address.
    init(_ error: StalkerError) {
        switch error {
        case .transport(let code): self = PlaybackFailure(URLError(code))
        case .serverError(let status): self = PlaybackFailure(httpStatus: status) ?? .serverError
        case .notAuthorized, .deviceRefused: self = .notAllowed
        case .noPortal, .unreadable, .notStalkerChannel, .noLink: self = .unreadable
        }
    }
}
