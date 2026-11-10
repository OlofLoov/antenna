import AntennaCore
import Foundation

/// The body of one HTTP response, handed to FFmpeg's read thread as it
/// arrives. Fetched through `PlaybackNetwork`'s ephemeral session, so
/// nothing about the address is cached, and refusals map to the same
/// `PlaybackFailure` reasons as Apple's player.
///
/// `open()` waits for the response headers. `read(into:count:)` blocks the
/// calling thread until bytes arrive, the body ends or the stream is
/// cancelled; call it only from the demuxing thread, never from the main
/// actor. At most `bufferLimit` bytes are held; past that the download
/// pauses until FFmpeg catches up.
public final class HTTPByteStream: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    /// Bytes held before the download pauses.
    public static let bufferLimit = 4 * 1024 * 1024

    private let url: URL
    private let session: URLSession
    private let condition = NSCondition()
    private var task: URLSessionDataTask?
    private var buffer = Data()
    private var finished = false
    private var cancelled = false
    private var suspended = false
    private var failure: PlaybackFailure?
    private var response: HTTPURLResponse?
    private var responseWaiter: CheckedContinuation<Void, any Error>?

    /// The total body length when the server sent one; nil for live streams.
    public private(set) var expectedLength: Int?

    public init(url: URL, session: URLSession = PlaybackNetwork.makeSession()) {
        self.url = url
        self.session = session
    }

    /// Starts the request and returns once the headers arrive. Throws the
    /// failure reason for a refusal or a network error.
    public func open() async throws {
        try StreamAddress.check(url)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                condition.lock()
                responseWaiter = continuation
                let task = session.dataTask(with: url)
                task.delegate = self
                self.task = task
                condition.unlock()
                task.resume()
            }
        } onCancel: {
            cancel()
        }
    }

    /// Copies up to `count` bytes into `destination`. Returns the number
    /// copied, 0 at the end of the body, or -1 when the stream failed or
    /// was cancelled; `failureReason` then says why.
    public func read(into destination: UnsafeMutablePointer<UInt8>, count: Int) -> Int {
        condition.lock()
        defer { condition.unlock() }
        while buffer.isEmpty, !finished, !cancelled {
            condition.wait()
        }
        if cancelled { return -1 }
        if buffer.isEmpty { return failure == nil ? 0 : -1 }
        let taken = min(count, buffer.count)
        buffer.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            destination.update(from: base.assumingMemoryBound(to: UInt8.self), count: taken)
        }
        buffer.removeFirst(taken)
        if suspended, buffer.count < Self.bufferLimit / 2 {
            suspended = false
            task?.resume()
        }
        return taken
    }

    /// Up to `count` bytes from the start of what is buffered, without
    /// taking them. Blocks until that many arrived or the body ended.
    public func peek(_ count: Int) -> Data {
        condition.lock()
        defer { condition.unlock() }
        while buffer.count < count, !finished, !cancelled {
            condition.wait()
        }
        return Data(buffer.prefix(count))
    }

    /// Why the stream ended early, if it did.
    public var failureReason: PlaybackFailure? {
        condition.lock()
        defer { condition.unlock() }
        return failure
    }

    /// Stops the download and wakes a blocked `read`, which returns -1.
    public func cancel() {
        condition.lock()
        cancelled = true
        let task = self.task
        let waiter = responseWaiter
        responseWaiter = nil
        condition.broadcast()
        condition.unlock()
        task?.cancel()
        waiter?.resume(throwing: CancellationError())
    }

    // MARK: URLSessionDataDelegate

    public func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        let http = response as? HTTPURLResponse
        let refusal = http.flatMap { PlaybackFailure(httpStatus: $0.statusCode) }
        condition.lock()
        self.response = http
        if response.expectedContentLength > 0 { expectedLength = Int(response.expectedContentLength) }
        if let refusal { failure = refusal }
        let waiter = responseWaiter
        responseWaiter = nil
        condition.unlock()
        if let refusal {
            waiter?.resume(throwing: refusal)
            completionHandler(.cancel)
            return
        }
        waiter?.resume()
        completionHandler(.allow)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        condition.lock()
        buffer.append(data)
        if buffer.count >= Self.bufferLimit, !suspended {
            suspended = true
            dataTask.suspend()
        }
        condition.broadcast()
        condition.unlock()
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        condition.lock()
        finished = true
        let host = url.host()
        if let urlError = error as? URLError, urlError.code != .cancelled, failure == nil {
            failure = response == nil ? PlaybackFailure(urlError, host: host) : .stoppedSendingData
        }
        let waiter = responseWaiter
        responseWaiter = nil
        let reason = failure
        condition.broadcast()
        condition.unlock()
        if let waiter {
            waiter.resume(throwing: reason ?? PlaybackFailure.unreadable)
        }
    }
}
