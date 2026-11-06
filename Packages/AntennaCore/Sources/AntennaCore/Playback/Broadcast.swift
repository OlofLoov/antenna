import Foundation
import Synchronization

/// A value many subscribers watch. Each `stream()` yields the current value
/// first, then every value sent after it. Engines use one per stream method.
public final class Broadcast<Value: Sendable>: Sendable {
    private struct State {
        var value: Value
        var subscribers: [UUID: AsyncStream<Value>.Continuation] = [:]
    }

    private let state: Mutex<State>

    public init(_ initial: Value) {
        state = Mutex(State(value: initial))
    }

    deinit {
        state.withLock { $0.subscribers.values.forEach { $0.finish() } }
    }

    /// The value last sent.
    public var value: Value { state.withLock { $0.value } }

    /// A new subscription, starting with the current value.
    public func stream() -> AsyncStream<Value> {
        let (stream, continuation) = AsyncStream.makeStream(of: Value.self, bufferingPolicy: .bufferingNewest(16))
        let id = UUID()
        continuation.onTermination = { [weak self] _ in
            self?.state.withLock { _ = $0.subscribers.removeValue(forKey: id) }
        }
        state.withLock { state in
            state.subscribers[id] = continuation
            continuation.yield(state.value)
        }
        return stream
    }

    /// Stores `value` and hands it to every subscriber.
    public func send(_ value: Value) {
        state.withLock { state in
            state.value = value
            state.subscribers.values.forEach { $0.yield(value) }
        }
    }
}

extension Broadcast where Value: Equatable {
    /// Sends `value` only when it differs from the current one.
    public func sendIfChanged(_ value: Value) {
        state.withLock { state in
            guard state.value != value else { return }
            state.value = value
            state.subscribers.values.forEach { $0.yield(value) }
        }
    }
}
