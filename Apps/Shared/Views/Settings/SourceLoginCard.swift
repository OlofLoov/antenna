#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// The QR card beside a source's details on Apple TV while the source's
    /// login has not reached it (`TV-Settings-SignIn-QR`,
    /// apple-tv-login-from-iphone/the-apple-tv-sign-in-offers-a-qr-code).
    /// The code asks for this source only. A delivered login is checked
    /// with the server, kept in the Keychain and the source refreshed; one
    /// that does not work shows the reason and a new code. Shows nothing
    /// when the TV is not signed in to iCloud.
    struct SourceLoginCard: View {
        let source: SourceDescriptor
        /// Called once a delivered login is kept.
        let signedIn: () -> Void
        @Environment(\.modelContext) private var context
        @Environment(\.sourceRefresher) private var refresher
        @State private var receiver: LoginReceiverModel?
        @State private var failure: String?

        var body: some View {
            // A stack, not a Group: a Group with nothing in it never appears,
            // so its task would never start the receiver that makes the code.
            VStack {
                if let receiver, let link = receiver.link {
                    LoginQRCard.Television(link: link.url, status: status(receiver))
                }
            }
            .task {
                let receiver = LoginReceiverModel(.app)
                receiver.onDelivery = { payload in await keep(payload) }
                self.receiver = receiver
                receiver.ask(for: [source.id])
                #if DEBUG
                    let sender = UITestingLoginDrops.sendFromPhone(to: receiver)
                    defer { sender?.cancel() }
                #endif
                await receiver.run()
            }
            .onDisappear { receiver?.stop() }
        }

        private func status(_ receiver: LoginReceiverModel) -> LoginQRCard.Status {
            if let failure, receiver.status == .waiting { return .failed(failure) }
            return LoginQRCard.status(of: receiver, names: [source])
        }

        private func keep(_ payload: LoginPayload) async {
            guard let login = payload.logins.first(where: { $0.source == source.id }) else { return }
            AccessibilityNotification.Announcement(LoginQRCard.received).post()
            do {
                _ = try await LoginKeeper(connector: .app).keep(.init(login), for: source, in: context)
                failure = nil
                receiver?.stop()
                refresher?.refresh([source.id])
                signedIn()
            } catch .refused(let message) {
                failure = OnboardingModel.deliveredFailure(message)
            } catch {
                return
            }
        }
    }
#endif
