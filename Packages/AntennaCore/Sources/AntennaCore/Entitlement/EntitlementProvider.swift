import Foundation

/// The one place a screen asks whether the app is unlocked.
public protocol EntitlementProvider: Sendable {
    /// The verdict now, answered without waiting on the network.
    func current() async -> Entitlement
    /// A new stream that yields each later change, starting with the next
    /// one. It does not repeat the current verdict.
    func updates() async -> AsyncStream<Entitlement>
}

/// A provider with a set verdict, for onboarding, the shell, previews and
/// UI tests. `set(_:)` changes it and tells every open stream.
public actor FixedEntitlementProvider: EntitlementProvider {
    private var entitlement: Entitlement
    private var listeners: [UUID: AsyncStream<Entitlement>.Continuation] = [:]

    public init(_ entitlement: Entitlement) {
        self.entitlement = entitlement
    }

    public func current() -> Entitlement { entitlement }

    public func updates() -> AsyncStream<Entitlement> {
        let (stream, continuation) = AsyncStream.makeStream(of: Entitlement.self)
        let id = UUID()
        listeners[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.drop(id) }
        }
        return stream
    }

    public func set(_ entitlement: Entitlement) {
        guard entitlement != self.entitlement else { return }
        self.entitlement = entitlement
        for listener in listeners.values { listener.yield(entitlement) }
    }

    private func drop(_ id: UUID) {
        listeners[id] = nil
    }
}
