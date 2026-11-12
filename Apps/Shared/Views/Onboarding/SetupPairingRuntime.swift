import AntennaCore
import SwiftData
import SwiftUI

/// Runs the Apple TV's QR card while the details step is on screen
/// (iphone-as-setup-device capability). Entering the step makes a new code
/// and a new snapshot; Menu stops the check, drops the link and the Handoff
/// offer, and lets an arrived login source go. Back from sleep, the store is
/// checked at once.
struct SetupPairingRuntime: ViewModifier {
    let model: OnboardingModel
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .task {
                let pairing = SetupPairingModel(.app)
                pairing.onArrival = { source in
                    Task {
                        await model.received(source)
                        // A login that came before its source is used now.
                        if pairing.login == .checking, let login = pairing.heldLogin { await keep(login, pairing: pairing) }
                    }
                }
                pairing.onLogin = { login in
                    Task { await keep(login, pairing: pairing) }
                }
                model.pairing = pairing
                #if DEBUG
                    let sender = UITestingSetup.sendFromPhone(into: context, after: pairing)
                    defer { sender?.cancel() }
                #endif
                await pairing.run(in: context)
            }
            .onDisappear {
                model.pairing?.stop()
                model.leaveArrival()
                model.pairing = nil
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { model.pairing?.wake() }
            }
    }

    /// Checks the login sent with an arrived source; when it does not work,
    /// the TV offers to sign in here (iphone-as-setup-device/a-login-source-sent-from-the-iphone-needs-only-its-login-on-the-tv).
    private func keep(_ login: LoginPayload, pairing: SetupPairingModel) async {
        await model.receive(login, into: context)
        if model.arrival != nil { pairing.loginDidNotWork() }
    }
}

extension SetupCard {
    /// The hint's wording.
    static func text(_ hint: SetupPairingModel.Hint) -> String {
        switch hint {
        case .nothing: nothingYet
        case .unusable: cannotSetUp
        }
    }
}
