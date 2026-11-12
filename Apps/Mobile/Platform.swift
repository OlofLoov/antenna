// iPhone / iPad / Mac-specific code goes here (PiP, Handoff, Live Activities, Foundation Models cleanup).

import SwiftUI

/// The window root on iPhone, iPad and Mac: onboarding while there is no
/// source (first-run-onboarding capability), then "Who's watching?" when
/// there are two or more profiles (profiles capability), then the tabs.
/// A playlist file shared to Antenna or opened with it opens the import
/// sheet over whichever shows (local-m3u-file-import/bring-a-file-in).
struct PlatformRoot: View {
    @Environment(\.importInbox) private var inbox

    var body: some View {
        OnboardingGate {
            ProfileGate {
                RootView()
            }
        }
        .modifier(ImportInboxSheet(inbox: inbox))
    }
}

extension View {
    /// Puts files opened with Antenna into `inbox`, and hands it to the
    /// screens below. Attach it above the paywall, so a file shared while
    /// the paywall is up waits for the unlock.
    func receivingFiles(into inbox: ImportInbox) -> some View {
        environment(\.importInbox, inbox)
            .onOpenURL { inbox.receive($0) }
            .task {
                #if DEBUG
                    if let url = UITestingImport.openedAtLaunch() { inbox.receive(url) }
                #endif
            }
    }
}

/// Shows the import sheet for the file waiting in the inbox. A one-link
/// file's "Add the link as a source" opens the Settings add-source sheet
/// on M3U with the link filled in.
private struct ImportInboxSheet: ViewModifier {
    let inbox: ImportInbox?
    @State private var addLink: URL?

    func body(content: Content) -> some View {
        content
            .sheet(item: Binding(get: { inbox?.pending }, set: { if $0 == nil { inbox?.take() } })) { request in
                ImportSheet(
                    request,
                    actions: .init(
                        finish: { _ in inbox?.take() },
                        addLink: { link in
                            inbox?.take()
                            addLink = link
                        }))
            }
            .sheet(item: Binding(get: { addLink.map(LinkItem.init) }, set: { addLink = $0?.url })) { item in
                SettingsAddSource(fields: .init(kind: .m3u, url: item.url.absoluteString))
            }
    }

    private struct LinkItem: Identifiable {
        var url: URL
        var id: URL { url }
    }
}
