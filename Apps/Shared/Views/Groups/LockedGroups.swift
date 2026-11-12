import AntennaCore
import SwiftUI

extension EnvironmentValues {
    /// Asks for the passcode to open a locked group the user picked in a
    /// channel list (group-management/unlock-with-the-passcode). Nil where
    /// no screen above offers the prompt.
    @Entry var unlockGroup: ((CatalogueGroup) -> Void)?
}

/// A locked group waiting for the passcode.
private struct PendingUnlock: Identifiable {
    let group: CatalogueGroup
    let name: String
    var id: String { group.storageKey }
}

/// Provides `unlockGroup` to the channel lists below and shows the
/// passcode prompt over them. `opened` gets the group once the right
/// passcode opened the locks on this device; whatever plays keeps playing.
struct UnlockGroupPrompt: ViewModifier {
    let name: (CatalogueGroup) -> String
    let opened: (CatalogueGroup) -> Void
    @State private var pending: PendingUnlock?

    func body(content: Content) -> some View {
        content
            .environment(\.unlockGroup) { group in pending = PendingUnlock(group: group, name: name(group)) }
            #if os(tvOS)
                .fullScreenCover(item: $pending) { prompt($0) }
            #else
                .sheet(item: $pending) { prompt($0) }
            #endif
    }

    private func prompt(_ request: PendingUnlock) -> some View {
        PasscodePrompt(flow: .unlock, message: "\(request.name) is locked.") { done in
            pending = nil
            if done { opened(request.group) }
        }
    }
}

/// Pauses a channel that becomes locked while it plays, from this device,
/// another device or the locks closing, and covers it with the passcode
/// prompt (group-management/a-channel-that-gets-locked-stops-playing).
/// The right passcode resumes it; closing the prompt plays the first
/// channel the user may watch, or stops when there is none.
struct LockedChannelGuard: ViewModifier {
    /// True while the channel playing now is locked.
    let isLocked: Bool
    let name: String
    let pause: () -> Void
    let resume: () -> Void
    let leave: () -> Void
    @State private var covering = false

    func body(content: Content) -> some View {
        content
            .onChange(of: isLocked, initial: true) { _, locked in
                guard locked, !covering else { return }
                pause()
                covering = true
            }
            #if os(tvOS)
                .fullScreenCover(isPresented: $covering) { prompt }
            #else
                .sheet(isPresented: $covering) { prompt.interactiveDismissDisabled() }
            #endif
    }

    private var prompt: some View {
        PasscodePrompt(flow: .unlock, message: "\(name) is locked.") { done in
            covering = false
            if done { resume() } else { leave() }
        }
    }
}
