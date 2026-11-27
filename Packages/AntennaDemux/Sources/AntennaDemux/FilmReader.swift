import AntennaCore
import Foundation

/// One run's view of a `FilmReadAhead`: its own position, and a connection
/// of its own for reads outside the ring.
final class FilmReader: DemuxBytes, @unchecked Sendable {
    let film: FilmReadAhead
    private let lock = NSLock()
    private var cancelled = false
    private var offset = 0
    private var side: HTTPByteStream?
    private var sideAt = 0
    private var sideRun = 0
    private var sideFailure: PlaybackFailure?

    init(_ film: FilmReadAhead) {
        self.film = film
    }

    var position: Int { lock.withLock { offset } }
    var length: Int? { film.length }
    var canSeek: Bool { true }
    var contentType: String? { film.contentType }
    var failureReason: PlaybackFailure? { lock.withLock { sideFailure } ?? film.failureReason }
    private var isCancelled: Bool { lock.withLock { cancelled } }

    func read(into destination: UnsafeMutablePointer<UInt8>, count: Int) -> Int {
        let at = position
        guard !isCancelled else { return -1 }
        let pinned = film.pinned(at: at, into: destination, count: count)
        if pinned > 0 { return advance(pinned) }
        // Reading on outside the ring stays on its connection; the download
        // waits while it is open, so a read from the ring closes it first.
        if lock.withLock({ side != nil }) {
            if sideAt == at { return readOutside(at: at, into: destination, count: count) }
            closeSide()
        }
        switch film.take(at: at, into: destination, count: count, cancelled: { [self] in isCancelled }) {
        case .read(let taken):
            if at < film.limits.pinned / 2 { film.pin(destination, count: taken, at: at) }
            return advance(taken)
        case .end:
            return 0
        case .failed:
            return -1
        case .outside:
            return readOutside(at: at, into: destination, count: count)
        }
    }

    private func readOutside(at: Int, into destination: UnsafeMutablePointer<UInt8>, count: Int) -> Int {
        if side == nil || sideAt != at {
            closeSide()
            film.readingOutside(true)
            let stream = HTTPByteStream(url: film.url, session: film.session, offset: at)
            lock.withLock { side = stream }
            if isCancelled { stream.cancel() }
            guard stream.openBlocking(), stream.status == 206 else {
                lock.withLock { sideFailure = stream.failureReason ?? .stoppedSendingData }
                closeSide()
                return -1
            }
            sideAt = at
            sideRun = 0
        }
        guard let stream = lock.withLock({ side }) else { return -1 }
        let taken = stream.read(into: destination, count: count)
        guard taken > 0 else {
            lock.withLock { sideFailure = stream.failureReason }
            closeSide()
            return taken
        }
        film.pin(destination, count: taken, at: at)
        sideAt += taken
        sideRun += taken
        if sideRun >= film.limits.adoptAfter {
            closeSide()
            film.jump(to: at + taken)
        }
        return advance(taken)
    }

    private func advance(_ count: Int) -> Int {
        lock.withLock { offset += count }
        return count
    }

    private func closeSide() {
        guard
            let stream = lock.withLock({ () -> HTTPByteStream? in
                defer { side = nil }
                return side
            })
        else { return }
        stream.cancel()
        film.readingOutside(false)
    }

    func peek(_ count: Int) -> Data {
        let start = position
        var data = Data()
        let scratch = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        defer { scratch.deallocate() }
        while data.count < count {
            let taken = read(into: scratch, count: count - data.count)
            guard taken > 0 else { break }
            data.append(scratch, count: taken)
        }
        lock.withLock { offset = start }
        return data
    }

    func seek(to target: Int) -> Bool {
        guard target >= 0, target <= film.length else { return false }
        lock.withLock { offset = target }
        return true
    }

    /// Stops this reader; a blocked read returns -1. The read-ahead goes on
    /// for the next run.
    func cancel() {
        let stream = lock.withLock {
            cancelled = true
            return side
        }
        stream?.cancel()
        film.wake()
    }
}
