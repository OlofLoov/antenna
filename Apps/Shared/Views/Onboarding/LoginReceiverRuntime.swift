#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// Runs the QR card on onboarding's "Sign in on this Apple TV" step
    /// (apple-tv-login-from-iphone/the-apple-tv-sign-in-offers-a-qr-code):
    /// the code asks for the first eight sources still to sign in, a
    /// delivery is checked and kept like a typed login, and a new code asks
    /// for whatever is left. Leaving the step stops the code and drops its key.
    struct LoginReceiverRuntime: ViewModifier {
        let model: OnboardingModel
        @Environment(\.modelContext) private var context
        @Environment(\.scenePhase) private var scenePhase

        func body(content: Content) -> some View {
            content
                .task {
                    let receiver = LoginReceiverModel(.app)
                    receiver.onDelivery = { payload in
                        AccessibilityNotification.Announcement(LoginQRCard.received).post()
                        await model.receive(payload, into: context)
                    }
                    model.receiver = receiver
                    receiver.ask(for: model.signIns.map(\.id))
                    #if DEBUG
                        let sender = UITestingLoginDrops.sendFromPhone(to: receiver)
                        defer { sender?.cancel() }
                    #endif
                    await receiver.run()
                }
                .onChange(of: model.signIns.map(\.id)) { _, ids in
                    model.receiver?.ask(for: ids)
                }
                .onDisappear {
                    model.receiver?.stop()
                    model.receiver = nil
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active, let receiver = model.receiver { Task { await receiver.check() } }
                }
        }
    }

    extension LoginQRCard {
        /// The card's status for `receiver`, naming the sources by `names`.
        @MainActor static func status(of receiver: LoginReceiverModel, names sources: [SourceDescriptor]) -> Status {
            switch receiver.status {
            case .waiting:
                return .waiting(count: receiver.requested.count, hint: receiver.showsHint)
            case .checking(let ids):
                return .checking(ids.compactMap { id in sources.first { $0.id == id }?.name })
            case .unreadable:
                return .unreadable
            }
        }
    }
#endif
