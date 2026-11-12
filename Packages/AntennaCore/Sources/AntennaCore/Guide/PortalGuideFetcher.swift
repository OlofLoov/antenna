import Foundation

/// Downloads a Stalker portal's own guide with the guide's session and a
/// signed request from the source's client. When the portal turns the
/// session key down, the client renews it once and the download runs again
/// (guide-data/find-the-guide-for-each-source).
struct PortalGuideFetcher: Sendable {
    /// The guide covers this many hours ahead, the most a portal is asked for.
    static let hours = 168

    var session: URLSession
    var limits: GuideLimits

    /// The outcome, and the rows skipped as broken or with impossible times.
    func fetch(_ client: StalkerClient) async -> (outcome: GuideFetcher.Outcome, skipped: Int) {
        for attempt in 0..<2 {
            do {
                let request = try await client.epgRequest(period: Self.hours)
                let (data, response) = try await session.data(for: request, delegate: StalkerRedirects())
                try Task.checkCancellation()
                if Int64(data.count) > limits.unpackedBytes { return (.failed(.tooLarge), 0) }
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                switch try StalkerClient.decodeGuide(status: status, data: data) {
                case .rejected:
                    if attempt == 0 {
                        await client.invalidateToken()
                        continue
                    }
                    return (.failed(.unauthorized), 0)
                case .guide(let programmes, let skipped):
                    guard !programmes.isEmpty else { return (.failed(.empty), skipped) }
                    let guide = await Task.detached { SourceGuide(programmes) }.value
                    return (.loaded(guide), skipped)
                }
            } catch {
                return (Self.outcome(for: error), 0)
            }
        }
        return (.failed(.unauthorized), 0)
    }

    static func outcome(for error: any Error) -> GuideFetcher.Outcome {
        if Task.isCancelled || error is CancellationError { return .cancelled }
        switch error {
        case let stalker as StalkerError:
            switch stalker {
            case .transport(let code): return code == .cancelled ? .cancelled : .failed(GuideFetcher.map(code))
            case .serverError(let status): return .failed(.httpStatus(status))
            case .notAuthorized, .deviceRefused: return .failed(.unauthorized)
            case .noPortal, .unreadable, .notStalkerChannel, .noLink: return .failed(.malformed)
            }
        case let url as URLError:
            return url.code == .cancelled ? .cancelled : .failed(GuideFetcher.map(url.code))
        default:
            return .failed(.network(.unknown))
        }
    }
}
