import AntennaCore
import Foundation

/// The bytes FFmpeg reads: one `HTTPByteStream` at a time, reopened at a
/// new offset when FFmpeg seeks, which films in Matroska, AVI and MP4 need
/// to find their index and to skip
/// (playback-engine/films-start-where-you-left-off-skip-and-end).
///
/// Seeking works when the first answer said the server takes byte ranges
/// and gave the length. A jump of up to 256 KB forward reads through
/// instead of reopening. `read`, `seek` and `peek` block, so call them from
/// the demuxing thread; `cancel` from anywhere.
final class SeekableSource: @unchecked Sendable {
    private let url: URL
    private let session: URLSession
    private let lock = NSLock()
    private var stream: HTTPByteStream
    private var cancelled = false
    private(set) var position = 0
    /// The length of the whole resource, when the server said.
    let length: Int?
    /// True when the server takes byte ranges and gave the length.
    let canSeek: Bool

    /// Starts from `stream`, already open at the beginning.
    init(_ stream: HTTPByteStream, url: URL, session: URLSession) {
        self.stream = stream
        self.url = url
        self.session = session
        length = stream.expectedLength
        canSeek = stream.acceptsRanges && stream.expectedLength != nil
    }

    private var current: HTTPByteStream { lock.withLock { stream } }

    func read(into destination: UnsafeMutablePointer<UInt8>, count: Int) -> Int {
        let taken = current.read(into: destination, count: count)
        if taken > 0 { position += taken }
        return taken
    }

    func peek(_ count: Int) -> Data {
        current.peek(count)
    }

    var failureReason: PlaybackFailure? {
        current.failureReason
    }

    /// Moves to byte `target`. Returns false when the server cannot skip,
    /// ignored the range, or the new request failed.
    func seek(to target: Int) -> Bool {
        guard target != position else { return true }
        guard canSeek, target >= 0, length.map({ target <= $0 }) ?? true else { return false }
        if target > position, target - position <= 256 * 1024 {
            return skip(target - position)
        }
        let next = HTTPByteStream(url: url, session: session, offset: target)
        let opened = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var failed = false
        Task {
            do { try await next.open() } catch { failed = true }
            opened.signal()
        }
        opened.wait()
        guard !failed, next.status == 206 || target == 0 else {
            next.cancel()
            return false
        }
        let old = lock.withLock {
            defer { stream = next }
            return stream
        }
        old.cancel()
        if lock.withLock({ cancelled }) { next.cancel() }
        position = target
        return true
    }

    /// Reads and drops `count` bytes.
    private func skip(_ count: Int) -> Bool {
        var left = count
        let scratch = UnsafeMutablePointer<UInt8>.allocate(capacity: 64 * 1024)
        defer { scratch.deallocate() }
        while left > 0 {
            let taken = read(into: scratch, count: min(left, 64 * 1024))
            guard taken > 0 else { return false }
            left -= taken
        }
        return true
    }

    /// Stops reading; a blocked `read` returns -1.
    func cancel() {
        let stream = lock.withLock {
            cancelled = true
            return self.stream
        }
        stream.cancel()
    }
}
