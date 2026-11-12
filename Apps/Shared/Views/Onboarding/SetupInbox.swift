#if !os(tvOS)
    import AntennaCore
    import Foundation
    import SwiftUI

    /// Setup links from an Apple TV wait here, outside the paywall, until
    /// the app can show the "Set up Apple TV" sheet
    /// (iphone-as-setup-device/scanning-opens-the-setup-form-on-the-iphone).
    /// It lives in memory only, so a link from before a relaunch is gone.
    /// The code is never logged or stored.
    @MainActor @Observable
    final class SetupInbox {
        /// What a link asks the iPhone to open.
        struct Request: Identifiable, Equatable {
            enum Kind: Equatable {
                /// "Set up Apple TV" for this link.
                case setup(SetupLink)
                /// A link from a newer Antenna: the plain form with a line asking to update.
                case newer
                /// A setup link that does not parse: the plain form, no banner, no error.
                case damaged
            }

            let id = UUID()
            var kind: Kind
        }

        private(set) var pending: Request?
        /// Codes used in this launch, which open nothing again.
        @ObservationIgnored private var used: Set<PairingToken> = []

        /// Onboarding's welcome screen stays under the sheet until it closes.
        var holdsApp: Bool { pending != nil }

        /// A link opened with Antenna. Returns false when it is not a setup link at all.
        @discardableResult
        func receive(_ url: URL) -> Bool {
            let kind: Request.Kind
            do {
                kind = .setup(try SetupLink(url: url))
            } catch .notASetupLink {
                return false
            } catch .unsupportedVersion {
                kind = .newer
            } catch {
                kind = .damaged
            }
            open(kind)
            return true
        }

        /// The Handoff offer, holding the code in its user info.
        func receive(handoff info: [AnyHashable: Any]?) {
            guard let link = SetupLink(userInfo: info) else { return }
            open(.setup(link))
        }

        /// Marks the code on screen as used; Continue calls it.
        func use(_ link: SetupLink) {
            used.insert(link.token)
        }

        /// The sheet closed. Cancel before Connect forgets the code, so it can open again.
        func take() {
            pending = nil
        }

        /// A code already used opens nothing, and another link while the
        /// sheet is open is dropped.
        private func open(_ kind: Request.Kind) {
            guard pending == nil else { return }
            if case .setup(let link) = kind, used.contains(link.token) { return }
            pending = Request(kind: kind)
        }
    }

    extension EnvironmentValues {
        /// The app's inbox for setup links. Nil in previews.
        @Entry var setupInbox: SetupInbox?
    }

    extension View {
        /// Puts setup links and Handoff offers into `inbox`. Attach it above
        /// the paywall, so a link that arrives while the paywall is up waits
        /// for the unlock.
        func receivingSetupLinks(into inbox: SetupInbox) -> some View {
            environment(\.setupInbox, inbox)
                .onOpenURL { inbox.receive($0) }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL { inbox.receive(url) }
                }
                .onContinueUserActivity(SetupLink.activityType) { activity in
                    inbox.receive(handoff: activity.userInfo)
                }
                .task {
                    #if DEBUG
                        if let url = UITestingSetup.linkAtLaunch() { inbox.receive(url) }
                    #endif
                }
        }
    }

    /// Shows the "Set up Apple TV" sheet for the link waiting in the inbox.
    struct SetupInboxSheet: ViewModifier {
        let inbox: SetupInbox?

        func body(content: Content) -> some View {
            content
                .sheet(item: Binding(get: { inbox?.pending }, set: { if $0 == nil { inbox?.take() } })) { request in
                    SetupFromTVScreen(request: request, use: { inbox?.use($0) }, close: { inbox?.take() })
                }
        }
    }
#endif
