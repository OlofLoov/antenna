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
                    Task { await model.received(source) }
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
