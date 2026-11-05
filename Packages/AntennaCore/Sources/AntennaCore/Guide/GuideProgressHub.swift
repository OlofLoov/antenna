import Foundation

/// Fans guide progress out to every listener and remembers the latest event
/// per source, so a listener that arrives late hears it first. Each source
/// has a generation; an event sent under an older one is dropped, which is
/// how a cancelled or removed load goes quiet.
final class GuideProgressHub: @unchecked Sendable {
    private let lock = NSLock()
    private var listeners: [UUID: AsyncStream<GuideProgress>.Continuation] = [:]
    private var latest: [UUID: (order: Int, event: GuideProgress)] = [:]
    private var generations: [UUID: Int] = [:]

    /// A new stream that first yields the latest event of each source, in
    /// `sortOrder` then source id, then every event as it is sent.
    func stream() -> AsyncStream<GuideProgress> {
        let (stream, continuation) = AsyncStream.makeStream(of: GuideProgress.self)
        let id = UUID()
        lock.withLock {
            let replay = latest.sorted { ($0.value.order, $0.key.uuidString) < ($1.value.order, $1.key.uuidString) }
            for entry in replay { continuation.yield(entry.value.event) }
            listeners[id] = continuation
        }
        continuation.onTermination = { [weak self] _ in
            self?.lock.withLock { _ = self?.listeners.removeValue(forKey: id) }
        }
        return stream
    }

    func generation(of sourceID: UUID) -> Int {
        lock.withLock { generations[sourceID] ?? 0 }
    }

    /// Starts a new generation for the source and returns it.
    func bump(_ sourceID: UUID) -> Int {
        lock.withLock {
            generations[sourceID, default: 0] += 1
            return generations[sourceID] ?? 0
        }
    }

    /// Sends `event` unless `generation` is given and is not the source's
    /// current one, or `unlessRepeated` is set and the source's latest event
    /// is the same.
    func emit(_ event: GuideProgress, order: Int, generation: Int? = nil, unlessRepeated: Bool = false) {
        lock.withLock {
            let id = event.sourceID
            if let generation, generation != (generations[id] ?? 0) { return }
            if unlessRepeated, latest[id]?.event == event { return }
            latest[id] = (order, event)
            for listener in listeners.values { listener.yield(event) }
        }
    }

    /// Drops the source's latest event and silences anything still running for it.
    func forget(_ sourceID: UUID) {
        lock.withLock {
            latest[sourceID] = nil
            generations[sourceID, default: 0] += 1
        }
    }
}
