import AntennaCore
import Darwin
import Foundation

/// A film's bytes, read minutes ahead of the play position into a file in
/// Caches, so a slow or uneven server does not stall the picture and the
/// film never sits in memory (playback-engine/films-read-ahead-to-disk).
///
/// The file is a ring of `capacity` bytes: byte `n` of the film is stored
/// at `n % capacity`, and the bytes from `lower` to `upper` are there. A
/// thread of its own downloads from `upper` on in range requests of
/// `Limits.request` bytes, one after another, until `aheadTarget` lies ahead
/// of the play position, and starts again once less than `refillMark` is
/// left. Each `FilmReader` the engine starts a run on reads from it, so
/// a skip within the bytes held needs no network.
///
/// Reads outside the ring, as FFmpeg makes for a film's index at its end
/// when a run opens, go over a connection of their own and are kept in
/// memory up to `Limits.pinned`; the download waits meanwhile, since many
/// providers allow one connection per account. Reading on past
/// `Limits.adoptAfter` from there moves the ring to that place.
final class FilmReadAhead: @unchecked Sendable {
    struct Limits: Sendable {
        /// How far ahead of the play position the download goes.
        var ahead: TimeInterval = 180
        /// Below this much ahead the download starts again.
        var refill: TimeInterval = 90
        /// What lies ahead while the film's bit rate is unknown.
        var unknownRateAhead = 256 << 20
        /// The most the ring file takes on disk.
        var largest = 2560 << 20
        /// Below this much room no file is made and the film plays from the connection.
        var smallest = 64 << 20
        /// Free space the ring always leaves on the device.
        var keepFree = 1 << 30
        /// The most one read from the connection takes.
        var chunk = 1 << 20
        /// The most one range request asks for. URLSession may deliver a
        /// whole answer however slowly it is read, so this bounds memory.
        var request = 8 << 20
        /// Bytes read outside the ring in a row that move the ring there.
        var adoptAfter = 8 << 20
        /// Bytes read outside the ring, and the film's first bytes, kept in memory.
        var pinned = 16 << 20
        /// Bytes past the end of the ring a reader waits for rather than moving the ring.
        var forwardWait = 8 << 20
        /// Where the ring file goes, with the live buffers, so launch deletes a leftover one.
        var store = TimeshiftStore.standard
        /// Connection drops in a row with no byte between them after which the
        /// film's bytes fail, once the reader has read all that is held.
        var retries = 4
    }

    let url: URL
    let length: Int
    let capacity: Int
    let contentType: String?
    let limits: Limits
    /// The most one write takes: `Limits.chunk`, or less in a small ring.
    private let chunk: Int
    let session: URLSession
    private let store: TimeshiftStore
    private let folder: URL
    private let file: Int32
    private let condition = NSCondition()

    private var lower = 0
    private var upper = 0
    /// Moves on each jump of the ring; a write for an older one is dropped.
    private var epoch = 0
    /// Where the reader playing now is.
    private var playPosition = 0
    private var bytesPerSecond: Double?
    private var filling = true
    private var sideReads = 0
    private var failure: PlaybackFailure?
    private var closed = false
    private var connection: HTTPByteStream?
    private var pins: [(offset: Int, data: Data)] = []
    private var pinnedBytes = 0
    /// Why the last connection the download opened failed; used on the download thread only.
    private var lastRefusal: PlaybackFailure?
    /// Range requests made, for tests and the log.
    private(set) var requests = 1

    /// A read-ahead for the film `first` opened from its start, or nil when
    /// the server cannot skip, gave no length, or the device has too little
    /// free space for `limits.smallest`; the film then plays from the connection.
    static func make(
        _ first: HTTPByteStream, url: URL, session: URLSession, limits: Limits = Limits()
    ) -> FilmReadAhead? {
        let store = limits.store
        guard first.acceptsRanges, first.offset == 0, let length = first.expectedLength, length > 0 else { return nil }
        let free = (store.freeBytes() ?? 0) - limits.keepFree
        var capacity = min(limits.largest, free, length)
        guard capacity >= min(limits.smallest, length), let folder = try? store.makeSession() else { return nil }
        let path = folder.appending(path: "film").path
        let file = Darwin.open(path, O_RDWR | O_CREAT | O_TRUNC, 0o600)
        guard file >= 0 else {
            store.retire(folder)
            return nil
        }
        // Reserved up front, so the ring never runs out of space partway.
        while capacity >= min(limits.smallest, length), !Self.reserve(capacity, in: file) { capacity /= 2 }
        guard capacity >= min(limits.smallest, length) else {
            Darwin.close(file)
            store.retire(folder)
            return nil
        }
        return FilmReadAhead(
            first, url: url, length: length, capacity: capacity, session: session, store: store, folder: folder, file: file,
            limits: limits)
    }

    private init(
        _ first: HTTPByteStream, url: URL, length: Int, capacity: Int, session: URLSession, store: TimeshiftStore, folder: URL,
        file: Int32, limits: Limits
    ) {
        self.url = url
        self.length = length
        self.capacity = capacity
        self.session = session
        self.store = store
        self.folder = folder
        self.file = file
        self.limits = limits
        chunk = max(4096, min(limits.chunk, capacity / 8))
        contentType = first.contentType
        connection = first
        let thread = Thread { [self] in download(from: first) }
        thread.name = "se.codecrave.antenna.film"
        thread.qualityOfService = .userInitiated
        thread.start()
    }

    private static func reserve(_ bytes: Int, in file: Int32) -> Bool {
        var store = fstore_t(
            fst_flags: UInt32(F_ALLOCATEALL), fst_posmode: Int32(F_PEOFPOSMODE), fst_offset: 0, fst_length: off_t(bytes),
            fst_bytesalloc: 0)
        return fcntl(file, F_PREALLOCATE, &store) != -1 && ftruncate(file, off_t(bytes)) == 0
    }

    /// A reader for a new run, from the film's start.
    func reader() -> FilmReader {
        FilmReader(self)
    }

    /// Sets how far ahead the download goes from the film's bit rate: its
    /// length over its duration.
    func setDuration(_ seconds: Double) {
        guard seconds > 0 else { return }
        condition.withLock { bytesPerSecond = Double(length) / seconds }
        condition.broadcast()
    }

    /// False once the download failed for good; the engine starts over with a new one.
    var isUsable: Bool {
        condition.withLock { failure == nil && !closed }
    }

    var failureReason: PlaybackFailure? {
        condition.withLock { failure }
    }

    /// Bytes held ahead of the play position.
    var heldAhead: Int {
        condition.withLock { max(0, upper - playPosition) }
    }

    /// The film's bytes held in the ring.
    var held: Range<Int> {
        condition.withLock { lower..<upper }
    }

    /// Stops the download and deletes the file once its thread ends.
    func discard() {
        let open = condition.withLock {
            closed = true
            condition.broadcast()
            return connection
        }
        open?.cancel()
    }

    // MARK: Ahead

    /// Bytes the download keeps ahead of the play position. Call with the lock held.
    private var aheadTarget: Int {
        let wanted = bytesPerSecond.map { Int($0 * limits.ahead) } ?? limits.unknownRateAhead
        return max(chunk, min(wanted, capacity - capacity / 8 - 2 * chunk))
    }

    /// Below this many bytes ahead the download starts again. Call with the lock held.
    private var refillMark: Int {
        let wanted = bytesPerSecond.map { Int($0 * limits.refill) } ?? aheadTarget / 2
        return min(wanted, aheadTarget / 2)
    }

    /// Whether the download has work: it closes its connection when not.
    /// Call with the lock held.
    private var wantsBytes: Bool {
        guard !closed, failure == nil, upper < length, sideReads == 0 else { return false }
        let ahead = upper - playPosition
        if filling, ahead >= aheadTarget { filling = false }
        if !filling, ahead < refillMark { filling = true }
        return filling
    }

    private func download(from first: HTTPByteStream) {
        let scratch = UnsafeMutablePointer<UInt8>.allocate(capacity: chunk)
        defer {
            scratch.deallocate()
            Darwin.close(file)
            store.retire(folder)
        }
        var stream: HTTPByteStream? = first
        var streamEpoch = 0
        var streamAt = 0
        var streamEnd = min(length, limits.request)
        var drops = 0
        while true {
            condition.lock()
            while !closed, !wantsBytes {
                if let open = stream {
                    stream = nil
                    connection = nil
                    condition.unlock()
                    open.cancel()
                    condition.lock()
                    continue
                }
                condition.wait()
            }
            guard !closed else {
                condition.unlock()
                break
            }
            let mine = epoch
            let at = upper
            // A ring that holds the whole film never writes over what it holds.
            let room = capacity < length ? capacity - (upper - playPosition) - chunk : length - upper
            let wanted = min(chunk, room, length - upper)
            condition.unlock()
            guard wanted > 0 else {
                condition.withLock { _ = condition.wait(until: Date(timeIntervalSinceNow: 0.1)) }
                continue
            }
            if stream == nil || streamEpoch != mine || streamAt != at || streamAt >= streamEnd {
                stream?.cancel()
                streamEnd = min(length, at + limits.request)
                stream = connect(at: at, end: streamEnd)
                streamEpoch = mine
                streamAt = at
            }
            let taken = stream.map { $0.read(into: scratch, count: min(wanted, streamEnd - streamAt)) } ?? -1
            guard taken > 0 else {
                let reason = stream?.failureReason ?? lastRefusal
                stream?.cancel()
                stream = nil
                // Closed for a jump, a read outside the ring or the end: not a drop.
                if condition.withLock({ epoch != mine || closed || sideReads > 0 }) { continue }
                drops += 1
                // While minutes are held the server gets more tries; the film
                // fails only once the reader has caught up.
                let caughtUp = condition.withLock { upper - playPosition < chunk }
                if drops > limits.retries, caughtUp {
                    fail(reason ?? .stoppedSendingData)
                } else {
                    Thread.sleep(forTimeInterval: min(4, 0.25 * Double(1 << min(drops, 4))))
                }
                continue
            }
            guard write(scratch, count: taken, at: at) else {
                fail(.unreadable)
                continue
            }
            drops = 0
            streamAt += taken
            condition.withLock {
                if epoch == mine, upper == at {
                    upper += taken
                    lower = max(lower, upper - capacity)
                }
                condition.broadcast()
            }
        }
        stream?.cancel()
    }

    /// A connection for the bytes from `offset` to `end`, or nil when it failed.
    private func connect(at offset: Int, end: Int) -> HTTPByteStream? {
        let stream = HTTPByteStream(url: url, session: session, offset: offset, end: end)
        let go = condition.withLock {
            guard !closed else { return false }
            connection = stream
            requests += 1
            return true
        }
        guard go, stream.openBlocking(), stream.status == 206 || offset == 0 else {
            lastRefusal = stream.failureReason
            stream.cancel()
            return nil
        }
        lastRefusal = nil
        return stream
    }

    private func fail(_ reason: PlaybackFailure) {
        condition.withLock {
            if failure == nil { failure = reason }
            condition.broadcast()
        }
    }

    private func write(_ bytes: UnsafeMutablePointer<UInt8>, count: Int, at offset: Int) -> Bool {
        var done = 0
        while done < count {
            let slot = (offset + done) % capacity
            let part = min(count - done, capacity - slot)
            let written = pwrite(file, bytes.advanced(by: done), part, off_t(slot))
            guard written > 0 else { return false }
            done += written
        }
        return true
    }
}

extension FilmReadAhead {
    // MARK: Reading

    enum Take {
        case read(Int)
        case outside
        case end
        case failed
    }

    /// Copies bytes from `offset` out of the ring, waiting when they are
    /// about to arrive. `.outside` when they are not in the ring or near its end.
    func take(at offset: Int, into destination: UnsafeMutablePointer<UInt8>, count: Int, cancelled: () -> Bool) -> Take {
        condition.lock()
        defer { condition.unlock() }
        if offset >= length { return .end }
        guard offset >= safeLower, offset <= upper + limits.forwardWait else { return .outside }
        playPosition = offset
        condition.broadcast()
        while offset >= upper, failure == nil, !closed, !cancelled() {
            condition.wait()
        }
        guard offset < upper, offset >= safeLower else {
            return failure != nil || closed ? .failed : cancelled() ? .failed : .outside
        }
        let slot = offset % capacity
        let wanted = min(count, upper - offset, capacity - slot)
        let got = pread(file, destination, wanted, off_t(slot))
        guard got > 0 else { return .failed }
        return .read(got)
    }

    /// The oldest byte a reader may take. A write in progress may be
    /// replacing up to a chunk past `lower`. Call with the lock held.
    private var safeLower: Int {
        capacity < length ? max(lower, upper + chunk - capacity) : lower
    }

    /// Moves the ring to start at `offset`, as when a reader settled outside it.
    func jump(to offset: Int) {
        let open = condition.withLock {
            epoch += 1
            lower = offset
            upper = offset
            playPosition = offset
            filling = true
            condition.broadcast()
            return connection
        }
        open?.cancel()
    }

    /// Pauses the download while a reader reads outside the ring, and lets it go on after.
    func readingOutside(_ outside: Bool) {
        let open = condition.withLock {
            sideReads += outside ? 1 : -1
            condition.broadcast()
            return sideReads > 0 ? connection : nil
        }
        open?.cancel()
    }

    // MARK: Pinned bytes

    /// Keeps a copy of bytes read outside the ring, or of the film's first
    /// bytes, while there is room.
    func pin(_ bytes: UnsafeMutablePointer<UInt8>, count: Int, at offset: Int) {
        condition.withLock {
            guard pinnedBytes + count <= limits.pinned, !pins.contains(where: { $0.offset == offset && $0.data.count >= count })
            else { return }
            pins.append((offset, Data(bytes: bytes, count: count)))
            pinnedBytes += count
        }
    }

    /// Copies pinned bytes from `offset`, or returns 0 when none are kept.
    func pinned(at offset: Int, into destination: UnsafeMutablePointer<UInt8>, count: Int) -> Int {
        condition.withLock {
            guard let pin = pins.first(where: { $0.offset <= offset && offset < $0.offset + $0.data.count }) else { return 0 }
            let start = offset - pin.offset
            let taken = min(count, pin.data.count - start)
            pin.data.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return }
                destination.update(from: base.advanced(by: start).assumingMemoryBound(to: UInt8.self), count: taken)
            }
            return taken
        }
    }

    /// Wakes readers waiting for bytes, so a cancelled one returns.
    func wake() {
        condition.withLock { condition.broadcast() }
    }
}
