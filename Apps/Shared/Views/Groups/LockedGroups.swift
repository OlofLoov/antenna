import AntennaCore
import SwiftUI

extension EnvironmentValues {
    /// Asks for the passcode to open a locked group the user picked in a
    /// channel list (group-management/unlock-with-the-passcode). Nil where
    /// no screen above offers the prompt.
    @Entry var unlockGroup: ((CatalogueGroup) -> Void)?
}

/// What the passcode prompt is open for.
private enum PendingUnlock: Identifiable {
    /// A locked group the user picked in a channel list.
    case group(CatalogueGroup, name: String)
    /// The channel playing, which became locked.
    case channel(name: String)

    var id: String {
        switch self {
        case .group(let group, _): group.storageKey
        case .channel: "channel"
        }
    }

    var message: String {
        switch self {
        case .group(_, let name), .channel(let name): "\(name) is locked."
        }
    }
}

/// The passcode prompt over a screen that plays channels (group-management
/// capability). It provides `unlockGroup` to the channel lists below; the
/// right passcode opens the locks on this device and `opened` gets the
/// group, while whatever plays keeps playing
/// (group-management/unlock-with-the-passcode).
///
/// It also pauses a channel that becomes locked while it plays, from this
/// device, another device or the locks closing, and covers it with the
/// prompt (group-management/a-channel-that-gets-locked-stops-playing). The
/// right passcode resumes it; closing the prompt calls `leave`, which plays
/// the first channel the user may watch or stops.
///
/// One presentation serves both, so a screen carries a single sheet or
/// cover for the passcode.
struct GroupLockPrompt: ViewModifier {
    let name: (CatalogueGroup) -> String
    let opened: (CatalogueGroup) -> Void
    /// True while the channel playing now is locked.
    let playingIsLocked: Bool
    let playingName: String
    let pause: () -> Void
    let resume: () -> Void
    let leave: () -> Void
    @State private var pending: PendingUnlock?

    func body(content: Content) -> some View {
        content
            .environment(\.unlockGroup) { group in pending = .group(group, name: name(group)) }
            .onChange(of: playingIsLocked, initial: true) { _, locked in
                guard locked, pending == nil else { return }
                pause()
                pending = .channel(name: playingName)
            }
            #if os(tvOS)
                .fullScreenCover(item: $pending) { prompt($0) }
            #else
                .sheet(item: $pending) { prompt($0).interactiveDismissDisabled() }
            #endif
    }

    private func prompt(_ request: PendingUnlock) -> some View {
        PasscodePrompt(flow: .unlock, message: request.message) { done in
            pending = nil
            switch request {
            case .group(let group, _): if done { opened(group) }
            case .channel: if done { resume() } else { leave() }
            }
        }
    }
}
