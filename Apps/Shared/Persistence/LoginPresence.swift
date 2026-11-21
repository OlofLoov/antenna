import Foundation
import Synchronization
import SwiftUI

/// The Keychain items this app run has found, by service and account, so
/// asking whether a source has a login does not ask the Keychain each time
/// (source-management/login-checks-are-remembered). Only answers
/// that a login is here are kept. A missing login is asked about again
/// every time, so one that iCloud Keychain delivers later is seen at once.
final class LoginPresence: Sendable {
    static let shared = LoginPresence()

    private let present = Mutex<Set<String>>([])

    func isKnown(service: String, account: String) -> Bool {
        present.withLock { $0.contains(Self.entry(service, account)) }
    }

    func remember(service: String, account: String) {
        _ = present.withLock { $0.insert(Self.entry(service, account)) }
    }

    func forget(service: String, account: String) {
        _ = present.withLock { $0.remove(Self.entry(service, account)) }
    }

    /// Forgets every login found. The app calls it when it comes back to
    /// the front, since another device may have removed a login meanwhile.
    func forgetAll() {
        present.withLock { $0.removeAll() }
    }

    private static func entry(_ service: String, _ account: String) -> String {
        service + "\u{0}" + account
    }
}

/// Forgets the logins found each time the app comes to the front, so one
/// removed on another device in the meantime counts as missing again.
struct ForgetLoginsOnActivate: ViewModifier {
    @Environment(\.scenePhase) private var phase

    func body(content: Content) -> some View {
        content.onChange(of: phase) { _, phase in
            if phase == .active { LoginPresence.shared.forgetAll() }
        }
    }
}
