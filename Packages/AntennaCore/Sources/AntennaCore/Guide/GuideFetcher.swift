import Foundation

/// News about one source's guide load, for screens that show progress.
public enum GuideProgress: Sendable, Equatable {
    /// Bytes received so far; `expectedBytes` is nil when the server did not say.
    case downloading(sourceID: UUID, bytesReceived: Int64, expectedBytes: Int64?)
    /// Sent after every join that follows a completed load. `channelsWithGuide`
    /// counts channels whose guide id has any programme; `channelsTotal` counts
    /// every channel of the source; `days` counts UTC calendar days from today
    /// with a programme starting or airing at midnight; `unmatched` counts
    /// programmes no channel of the source uses.
    case loaded(sourceID: UUID, channelsWithGuide: Int, channelsTotal: Int, days: Int, unmatched: Int)
    case failed(sourceID: UUID, GuideError)

    public var sourceID: UUID {
        switch self {
        case .downloading(let id, _, _), .loaded(let id, _, _, _, _), .failed(let id, _): id
        }
    }
}

extension URLSessionConfiguration {
    /// The configuration guide downloads use: 30 s per request, 600 s per
    /// download, no URL cache and no cookies.
    public static var guide: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 600
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        return configuration
    }
}

/// Downloads one guide with `URLSession.bytes(for:)`, decodes and parses it.
struct GuideFetcher: Sendable {
    enum Outcome: Sendable {
        case loaded(SourceGuide)
        case failed(GuideError)
        /// The task was cancelled. Never reported to callers.
        case cancelled
    }

    var session: URLSession
    var limits: GuideLimits
    var directory: URL
    /// Time since an arbitrary start, for spacing progress events.
    var uptime: @Sendable () -> Duration
    var chunkSize = 65_536

    /// Sends `.downloading` after the first chunk, then at most once per
    /// 250 ms of `uptime`, then with the final count before the outcome when
    /// it differs from the last one sent. A body that crosses a limit stops
    /// within one chunk. 401 and 403 are `.unauthorized` only when `loginURL`.
    @concurrent
    func fetch(_ url: URL, sourceID: UUID, loginURL: Bool, progress: @Sendable (GuideProgress) -> Void) async -> Outcome {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        var task: URLSessionDataTask?
        var decoder: GuideDecoder?
        var expected: Int64?
        var lastSent: (bytes: Int64, at: Duration)?

        func report(force: Bool) {
            guard let decoder, decoder.bytesReceived > 0 else { return }
            let now = uptime()
            if let lastSent {
                guard lastSent.bytes != decoder.bytesReceived else { return }
                guard force || now - lastSent.at >= .milliseconds(250) else { return }
            }
            lastSent = (decoder.bytesReceived, now)
            progress(.downloading(sourceID: sourceID, bytesReceived: decoder.bytesReceived, expectedBytes: expected))
        }

        do {
            let (bytes, response) = try await session.bytes(for: request)
            task = bytes.task
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                bytes.task.cancel()
                let refused = loginURL && (http.statusCode == 401 || http.statusCode == 403)
                return .failed(refused ? .unauthorized : .httpStatus(http.statusCode))
            }
            expected = response.expectedContentLength >= 0 ? response.expectedContentLength : nil
            let sink = try GuideDecoder(limits: limits, expectedLength: expected, directory: directory, sourceID: sourceID)
            decoder = sink
            var buffer: [UInt8] = []
            buffer.reserveCapacity(chunkSize)
            for try await byte in bytes {
                buffer.append(byte)
                if buffer.count == chunkSize {
                    try sink.append(Data(buffer))
                    buffer.removeAll(keepingCapacity: true)
                    report(force: false)
                }
            }
            if !buffer.isEmpty {
                try sink.append(Data(buffer))
            }
            if Task.isCancelled { return .cancelled }
            report(force: true)
            return .loaded(try sink.finish())
        } catch let error as GuideError {
            task?.cancel()
            if Task.isCancelled { return .cancelled }
            report(force: true)
            return .failed(error)
        } catch let error as URLError {
            if Task.isCancelled || error.code == .cancelled { return .cancelled }
            return .failed(Self.map(error.code))
        } catch {
            return Task.isCancelled || error is CancellationError ? .cancelled : .failed(.network(.unknown))
        }
    }

    static func map(_ code: URLError.Code) -> GuideError {
        switch code {
        case .timedOut: .timeout
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: .offline
        default: .network(code)
        }
    }
}
