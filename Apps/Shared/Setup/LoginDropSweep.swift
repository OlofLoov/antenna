import SwiftUI

/// Deletes deliveries nobody picked up within ten minutes, each time the
/// app becomes active
/// (apple-tv-login-from-iphone/only-the-apple-tv-that-showed-the-code-can-read-the-login).
/// Runs only when this build can use CloudKit and this device is signed in
/// to iCloud, so a build without iCloud never reaches CloudKit.
struct LoginDropSweep: ViewModifier {
    @Environment(\.scenePhase) private var phase

    func body(content: Content) -> some View {
        content.onChange(of: phase, initial: true) { _, phase in
            guard phase == .active, Self.enabled else { return }
            let drops = LoginDrops.app
            Task { await LoginDrops.sweep(drops, now: .now) }
        }
    }

    @MainActor static var enabled: Bool {
        #if DEBUG
            if UITestingLoginDrops.store != nil { return true }
            if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-ui-testing") }) { return false }
        #endif
        return CloudSync.container != nil && FileManager.default.ubiquityIdentityToken != nil
    }
}
