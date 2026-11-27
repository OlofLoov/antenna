import CloudKit
import Foundation
import Observation

/// Whether this device can reach the user's private CloudKit database:
/// the build has a container and CloudKit says the iCloud account is
/// available. Play on and the login-drop sweep run only then. The iCloud
/// Drive identity (`ubiquityIdentityToken`) is not asked: it is nil with
/// iCloud Drive off, and on Apple TV, while CloudKit works.
@MainActor @Observable
final class CloudAccount {
    static let shared = CloudAccount()

    /// The account's state as CloudKit last gave it; nil before the first answer or without a container.
    private(set) var status: CKAccountStatus?

    @ObservationIgnored let container: String?
    @ObservationIgnored private let check: @Sendable (String) async -> CKAccountStatus?
    @ObservationIgnored private var asked: Task<Void, Never>?
    @ObservationIgnored private var observer: (any NSObjectProtocol)?

    /// `check` asks CloudKit by default; tests pass an answer. Without a
    /// container CloudKit is never asked, since making a `CKContainer`
    /// without the entitlement stops the app.
    init(
        container: String? = CloudSync.container,
        check: @escaping @Sendable (String) async -> CKAccountStatus? = { try? await CKContainer(identifier: $0).accountStatus() }
    ) {
        self.container = container
        self.check = check
    }

    /// True when the build has a container and the account is available.
    static func available(container: String?, status: CKAccountStatus?) -> Bool {
        container != nil && status == .available
    }

    var available: Bool { Self.available(container: container, status: status) }

    /// Asks once and then again on each account change; returns whether
    /// the account is available.
    func resolve() async -> Bool {
        guard container != nil else { return false }
        if status == nil {
            if asked == nil { asked = Task { await refresh() } }
            await asked?.value
        }
        startObserving()
        return available
    }

    /// Asks CloudKit again.
    func refresh() async {
        guard let container else { return }
        status = await check(container)
    }

    private func startObserving() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }
}
