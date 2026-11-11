import AntennaCore
import Foundation
import Observation
import SwiftData

/// The add-source form's state (first-run-onboarding capability): the
/// fields, Connect and its error, and the clipboard offer. The fields keep
/// their values when Connect fails or is cancelled.
@MainActor @Observable
final class OnboardingModel {
    typealias ClipboardOffer = OnboardingForm.ClipboardOffer

    var fields = SourceFields()
    /// Whether the password field shows what is typed.
    var revealsPassword = false
    private(set) var error: String?
    private(set) var connecting = false
    private(set) var clipboardOffer = ClipboardOffer.hidden
    /// The last successful Connect.
    private(set) var connection: SourceConnector.Connection?

    @ObservationIgnored let connector: SourceConnector
    @ObservationIgnored private let clipboard: Clipboard?
    @ObservationIgnored private var attempt: Task<Void, Never>?

    /// `clipboard` is nil where no fill-in banner shows: Mac and Apple TV.
    init(connector: SourceConnector, clipboard: Clipboard?) {
        self.connector = connector
        self.clipboard = clipboard
    }

    /// Picks the form for `kind`. Stalker cannot be picked.
    func choose(_ kind: SourceKind) {
        guard kind != .stalker else { return }
        fields.kind = kind
        error = nil
    }

    /// Checks the fields, then connects and saves. A second call while one
    /// runs sends nothing. Returns once the attempt ends; `connection` is
    /// set when it worked and `error` when it did not.
    func connect(into context: ModelContext) async {
        guard !connecting else { return }
        if let problem = fields.check() {
            error = problem.message
            return
        }
        error = nil
        connecting = true
        let fields = fields
        let task = Task { [connector] in
            do {
                let connection = try await connector.connect(fields, into: context)
                self.connection = connection
            } catch is CancellationError {
                return
            } catch {
                self.error = ConnectFailure(error, host: fields.host).message
            }
        }
        attempt = task
        await task.value
        connecting = false
        attempt = nil
    }

    /// Back or Menu while Connect runs: the request stops and the fields stay.
    func cancel() {
        attempt?.cancel()
    }

    /// Forgets the last connection, as Back from the checklist does.
    func clearConnection() {
        connection = nil
    }

    /// Asks the system whether the clipboard holds a probable link, which
    /// does not read it (first-run-onboarding/fill-the-form-from-a-copied-link).
    func lookForLink() async {
        guard let clipboard, clipboardOffer == .hidden else { return }
        if await clipboard.hasLink() { clipboardOffer = .link }
    }

    /// Fill in: reads the clipboard now, and only now, and fills the form
    /// from the link, or says there is none.
    func fillIn() {
        guard let clipboard else { return }
        guard let text = clipboard.read(), let link = CopiedLink(text) else {
            clipboardOffer = .noLink
            return
        }
        fields.fill(from: link)
        error = nil
        clipboardOffer = .hidden
    }
}

/// The system clipboard as onboarding uses it: `hasLink` must not read the
/// contents, so iOS shows no paste prompt until Fill in calls `read`.
struct Clipboard {
    var hasLink: @MainActor () async -> Bool
    var read: @MainActor () -> String?
}

#if os(iOS)
    import UIKit

    extension Clipboard {
        /// The general pasteboard, asked for a probable web link by pattern detection.
        @MainActor static var system: Clipboard? {
            #if DEBUG
                if let scripted = UITestingOnboarding.clipboard() { return scripted }
            #endif
            return Clipboard(
                hasLink: {
                    let found = try? await UIPasteboard.general.detectedPatterns(for: [\.probableWebURL])
                    return found?.isEmpty == false
                },
                read: { UIPasteboard.general.url?.absoluteString ?? UIPasteboard.general.string })
        }
    }
#else
    extension Clipboard {
        /// No banner on Mac or Apple TV.
        @MainActor static var system: Clipboard? { nil }
    }
#endif
