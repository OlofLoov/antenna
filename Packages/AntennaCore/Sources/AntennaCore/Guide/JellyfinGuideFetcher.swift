import Foundation

/// Takes a Jellyfin source's guide from the server in batches of channels,
/// with no XMLTV download
/// (guide-data/guide-from-a-source-that-serves-programmes-directly).
struct JellyfinGuideFetcher: Sendable {
    /// The guide covers this many hours from now.
    static let hours = 168

    /// The outcome, and the rows skipped as broken or repeated. `progress`
    /// hears the batches done and the batch count. `names` are the
    /// channels' names by server id.
    static func fetch(
        _ client: JellyfinClient, channelIDs: [String], names: [String: String] = [:], from now: Date,
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async -> (outcome: GuideFetcher.Outcome, skipped: Int) {
        do {
            let window = DateInterval(start: now, duration: TimeInterval(hours) * 3600)
            let list = try await client.programmes(channelIDs: channelIDs, in: window, progress: progress)
            guard !list.items.isEmpty else { return (.failed(.empty), list.skipped) }
            let guide = await Task.detached { SourceGuide(list.items, names: names) }.value
            return (.loaded(guide), list.skipped)
        } catch {
            return (outcome(for: error), 0)
        }
    }

    static func outcome(for error: any Error) -> GuideFetcher.Outcome {
        if Task.isCancelled || error is CancellationError { return .cancelled }
        guard let jellyfin = error as? JellyfinClient.JellyfinError else { return .failed(.network(.unknown)) }
        switch jellyfin {
        case .transport(let code): return code == .cancelled ? .cancelled : .failed(GuideFetcher.map(code))
        case .badStatus(let status): return .failed(.httpStatus(status))
        case .unauthorized, .forbidden: return .failed(.unauthorized)
        case .decoding: return .failed(.malformed)
        case .untrustedCertificate: return .failed(.network(.serverCertificateUntrusted))
        }
    }
}
