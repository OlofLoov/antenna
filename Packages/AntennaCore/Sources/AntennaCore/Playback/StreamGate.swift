import Synchronization

/// Whether this device may open a stream now. While a phone is connected to
/// an Apple TV it closes the gate, and every engine that checks it refuses
/// to load (play-on-apple-tv/the-phone-opens-no-stream-while-connected),
/// so a screen that forgets to send its play to the TV still opens nothing.
public final class StreamGate: Sendable {
    private let closed = Mutex(false)
    /// How many loads the gate turned away, for tests.
    private let refusals = Mutex(0)

    public init() {}

    /// True while streams may not open.
    public var isClosed: Bool { closed.withLock { $0 } }

    public func close() { closed.withLock { $0 = true } }
    public func open() { closed.withLock { $0 = false } }

    /// How many loads were refused since the gate was made.
    public var refused: Int { refusals.withLock { $0 } }

    /// True when a load may go ahead; counts a refusal otherwise.
    public func admits() -> Bool {
        guard isClosed else { return true }
        refusals.withLock { $0 += 1 }
        return false
    }
}
