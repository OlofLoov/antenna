import AntennaCore
import SwiftUI

/// Runs Play on for the window (play-on-apple-tv capability). On iPhone,
/// iPad and Mac it provides `playDestination`, keeps the device list fresh
/// while the scene is active and shows what each send did. On Apple TV it
/// listens for requests while the scene is active and provides the inbox
/// the shell takes them from. Runs only when this build can use CloudKit and
/// the device is signed in to iCloud
/// (play-on-apple-tv/waits-in-icloud-when-the-tv-is-not-reachable, not signed in).
struct PlayOnRuntime: ViewModifier {
    @Environment(\.scenePhase) private var phase
    #if os(tvOS)
        @State private var inbox = PlayRequestInbox()
        @State private var receiver: PlayOnReceiver?
    #else
        @State private var destination: PlayDestination?
    #endif

    func body(content: Content) -> some View {
        #if os(tvOS)
            content
                .environment(inbox)
                #if DEBUG
                    .overlay(alignment: .bottomLeading) { if UITestingPlayOn.scenario != nil { UITestingPlayOn.Probe() } }
                    .task { await UITestingPlayOn.deliver(into: inbox) }
                #endif
                .onChange(of: phase, initial: true) { _, phase in
                    if receiver == nil, let make = PlayOnSetup.receiver { receiver = make(inbox) }
                    guard let receiver else { return }
                    if phase == .active {
                        Task { await receiver.activate() }
                    } else if phase == .background {
                        receiver.deactivate()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .playRequestsChanged)) { _ in
                    Task { await receiver?.pickUp() }
                }
        #else
            content
                .environment(\.playDestination, destination)
                .modifier(PlayOnNotices(destination: destination))
                #if DEBUG
                    .overlay(alignment: .bottomLeading) { UITestingPlayOn.Probe(destination: destination) }
                #endif
                .onChange(of: phase, initial: true) { _, phase in
                    if destination == nil { destination = PlayOnSetup.destination?() }
                    guard let destination else { return }
                    if phase == .active {
                        Task { await destination.activate() }
                    } else if phase == .background {
                        destination.deactivate()
                    }
                }
        #endif
    }
}

/// Builds the app's Play on parts, or the scripted ones a Debug build's UI
/// tests ask for; nil when Play on cannot run here.
@MainActor
enum PlayOnSetup {
    static var enabled: Bool {
        #if DEBUG
            if UITestingPlayOn.scenario != nil { return true }
            if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-ui-testing") }) { return false }
        #endif
        return CloudSync.container != nil && FileManager.default.ubiquityIdentityToken != nil
    }

    #if os(tvOS)
        static var receiver: ((PlayRequestInbox) -> PlayOnReceiver)? {
            guard enabled else { return nil }
            #if DEBUG
                if let scripted = UITestingPlayOn.receiver { return scripted }
            #endif
            return { inbox in
                let queue = CloudKitPlayRequests()
                return PlayOnReceiver(
                    inbox: inbox, device: .launching(), devices: CloudKitPlayDevices(), queue: queue,
                    subscribe: { try? await queue.subscribe() })
            }
        }
    #else
        static var destination: (() -> PlayDestination)? {
            guard enabled else { return nil }
            #if DEBUG
                if let scripted = UITestingPlayOn.destination { return scripted }
            #endif
            return {
                let device = PlayOnDevice.launching()
                return PlayDestination(
                    .init(
                        devices: CloudKitPlayDevices(), browser: PlayOnBrowser(), sender: NetworkPlaySender(device: device), device: device,
                        queue: CloudKitPlayRequests())
                )
            }
        }
    #endif
}

#if !os(tvOS)
    /// What a send did: a short line at the top for a TV that started or
    /// keeps the request (`playOn.sent`), an alert for one that cannot play
    /// it (`playOn.error`) (play-on-apple-tv/the-phone-says-why-the-tv-cannot-play).
    struct PlayOnNotices: ViewModifier {
        let destination: PlayDestination?

        func body(content: Content) -> some View {
            content
                .overlay(alignment: .top) {
                    if let notice = destination?.notice, notice.kind == .sent {
                        PlayOnToast(text: notice.text)
                            .padding(.top, 8)
                            .transition(.opacity)
                            .task(id: notice.id) {
                                try? await Task.sleep(for: .seconds(3))
                                if destination?.notice?.id == notice.id { destination?.notice = nil }
                            }
                    }
                }
                .alert(
                    destination?.notice?.text ?? "", isPresented: errorShown, presenting: destination?.notice
                ) { _ in
                    Button("OK") { destination?.notice = nil }
                        .accessibilityIdentifier("playOn.error.ok")
                }
        }

        private var errorShown: Binding<Bool> {
            Binding(
                get: { destination?.notice?.kind == .error },
                set: { shown in if !shown { destination?.notice = nil } })
        }
    }
#endif
