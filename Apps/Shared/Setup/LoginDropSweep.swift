import SwiftUI

/// Deletes deliveries nobody picked up within ten minutes, each time the
/// app becomes active
/// (apple-tv-login-from-iphone/only-the-apple-tv-that-showed-the-code-can-read-the-login).
/// Runs only when this build has a CloudKit container and CloudKit says the
/// iCloud account is available, so a build without iCloud never reaches CloudKit.
struct LoginDropSweep: ViewModifier {
    @Environment(\.scenePhase) private var phase

    func body(content: Content) -> some View {
        content.onChange(of: phase, initial: true) { _, phase in
            guard phase == .active else { return }
            Task {
                guard await Self.enabled() else { return }
                await LoginDrops.sweep(LoginDrops.app, now: .now)
            }
        }
    }

    @MainActor static func enabled(_ account: CloudAccount = .shared) async -> Bool {
        #if DEBUG
            if UITestingLoginDrops.store != nil { return true }
            if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-ui-testing") }) { return false }
        #endif
        return await account.resolve()
    }
}
