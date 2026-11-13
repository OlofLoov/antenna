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
    /// Each source connected in this onboarding, in the order connected,
    /// as its checklist loads (first-run-onboarding/the-checklist-shows-real-progress).
    private(set) var setups: [SourceSetup] = []
    /// True while the form is open again for another source.
    var addingAnother = false
    /// True on the form after Back from a provider with nothing to watch.
    private(set) var returnedToForm = false
    /// Xtream sources and Stalker portals still to sign in on this Apple TV, in sort order
    /// (first-run-onboarding/sign-in-again-on-an-apple-tv).
    private(set) var signIns: [SourceDescriptor] = []
    /// How a connected source loads. Set by the screen before Connect;
    /// without it a connected source starts no checklist.
    @ObservationIgnored var setupDependencies: SourceSetup.Dependencies?
    /// Sources signed in so far, which start loading after the last one.
    @ObservationIgnored private var pendingSignedIn: [SourceConnector.Connection] = []
    /// True when the sources were signed in rather than added, which the summary's eyebrow says.
    private(set) var signedIn = false
    /// The Apple TV's QR card while the details step shows (iphone-as-setup-device capability).
    var pairing: SetupPairingModel?
    /// The sign-in step's QR card (apple-tv-login-from-iphone/the-apple-tv-sign-in-offers-a-qr-code).
    var receiver: LoginReceiverModel?
    /// A login source sent from the iPhone that this Apple TV is signing in to.
    private(set) var arrival: SourceDescriptor?
    /// The fields as typed before `arrival`, restored when the user leaves the step.
    @ObservationIgnored private var typedBeforeArrival: SourceFields?

    @ObservationIgnored let connector: SourceConnector
    @ObservationIgnored private let clipboard: Clipboard?
    @ObservationIgnored private var attempt: Task<Void, Never>?

    /// `clipboard` is nil where no fill-in banner shows: Mac and Apple TV.
    init(connector: SourceConnector, clipboard: Clipboard?) {
        self.connector = connector
        self.clipboard = clipboard
    }

    /// Picks the form for `kind`.
    func choose(_ kind: SourceKind) {
        fields.kind = kind
        error = nil
    }

    /// Use Xtream on the offer under a panel link: the form becomes an Xtream
    /// login filled in from the link (source-management/the-add-form-offers-xtream-for-a-panel-link).
    func useXtream() {
        fields.useXtream()
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
                self.addingAnother = false
                self.returnedToForm = false
                self.pairing?.stop()
                self.begin(connection)
            } catch is CancellationError {
                return
            } catch {
                self.error = Self.sentence(ConnectFailure(error, host: fields.host), fields: fields)
            }
        }
        attempt = task
        await task.value
        connecting = false
        attempt = nil
    }

    /// The failure's sentence. On iPhone, iPad and Mac a Channels DVR server
    /// at home that cannot be reached also asks for local network access
    /// (first-run-onboarding/add-a-channels-dvr-server).
    static func sentence(_ failure: ConnectFailure, fields: SourceFields) -> String {
        #if os(tvOS)
            return failure.message
        #else
            guard fields.kind == .channelsDVR, failure.wantsLocalNetworkHint(host: fields.host) else { return failure.message }
            return failure.message + " " + ConnectFailure.localNetworkHint
        #endif
    }

    /// A file imported from the playlist form: it counts as connected and
    /// its checklist starts with the channels the sheet read, so nothing
    /// is fetched (local-m3u-file-import/import-during-onboarding).
    func imported(_ record: SourceRecord, playlist: Playlist) {
        guard let descriptor = record.descriptor else { return }
        let connection = SourceConnector.Connection(
            descriptor: descriptor, reply: .playlist(playlist), login: nil, inserted: true, createdCredential: nil,
            fileName: record.fileName)
        self.connection = connection
        error = nil
        addingAnother = false
        returnedToForm = false
        begin(connection)
    }

    /// Back or Menu while Connect runs: the request stops and the fields stay.
    func cancel() {
        attempt?.cancel()
    }

    /// Onboarding stays up while a connected source is in it, even though
    /// the store now holds a source, and on the form after Back from a
    /// provider with nothing, while the store catches up with the delete.
    var holdsApp: Bool { !setups.isEmpty || returnedToForm || !signIns.isEmpty || pairing?.holdsApp == true }

    /// The checklist or summary shows in place of the form.
    var showsChecklist: Bool { !setups.isEmpty && !addingAnother && signIns.isEmpty }

    /// Asks for the login of each Xtream source and Jellyfin server and the
    /// MAC of each Stalker portal in `sources`, in order, with the server or
    /// portal filled in. Playlists are skipped.
    func startSignIn(_ sources: [SourceDescriptor]) {
        guard signIns.isEmpty, setups.isEmpty else { return }
        signIns = sources.filter(\.signsInOnAppleTV)
        prepareSignIn()
    }

    private func prepareSignIn() {
        guard let next = signIns.first else { return }
        fields = SourceFields(kind: next.kind, name: next.name, url: next.url.absoluteString)
        error = nil
    }

    /// Connect on the sign-in screen: checks the login with the server and
    /// keeps it in this device's Keychain under the source's credential key,
    /// adding no source. After the last one the checklist shows.
    func signIn(into context: ModelContext) async {
        guard !connecting, let source = signIns.first else { return }
        if let problem = fields.check() {
            error = problem.message
            return
        }
        guard let login = SourceConnector.credential(for: fields) else { return }
        error = nil
        connecting = true
        defer { connecting = false }
        do {
            signedIn(try await LoginKeeper(connector: connector).keep(login, for: source, in: context))
        } catch {
            if case .refused(let message) = error { self.error = message }
        }
    }

    /// Logins sent from the iPhone (apple-tv-login-from-iphone/the-apple-tv-checks-a-login-before-keeping-it):
    /// each one for a source still to sign in is checked and kept as if
    /// typed, others are ignored. A login that does not work puts its
    /// source on screen with empty fields and the reason.
    func receive(_ payload: LoginPayload, into context: ModelContext) async {
        let wanted = payload.logins.filter { login in signIns.contains { $0.id == login.source } }
        guard !wanted.isEmpty, !connecting else { return }
        error = nil
        connecting = true
        defer { connecting = false }
        var failure: (source: SourceDescriptor, message: String)?
        for login in wanted {
            guard let source = signIns.first(where: { $0.id == login.source }) else { continue }
            do {
                signedIn(try await LoginKeeper(connector: connector).keep(.init(login), for: source, in: context))
            } catch {
                guard case .refused(let message) = error else { return }
                if failure == nil { failure = (source, message) }
            }
        }
        guard let failure, let index = signIns.firstIndex(where: { $0.id == failure.source.id }) else { return }
        signIns.insert(signIns.remove(at: index), at: 0)
        prepareSignIn()
        error = Self.deliveredFailure(failure.message)
    }

    /// The sign-in's message for a delivered login that did not work.
    static func deliveredFailure(_ message: String) -> String {
        "The login from your iPhone didn't work here. \(message)"
    }

    private func signedIn(_ connection: SourceConnector.Connection) {
        pendingSignedIn.append(connection)
        signIns.removeAll { $0.id == connection.descriptor.id }
        arrival = nil
        typedBeforeArrival = nil
        if signIns.isEmpty {
            signedIn = true
            pendingSignedIn.forEach(begin)
            pendingSignedIn = []
        } else {
            prepareSignIn()
        }
    }

    /// The names still to sign in after the one on screen.
    var signInsAfterThis: [String] { signIns.dropFirst().map(\.name) }

    /// Every connected source's lines are done or failed.
    var allFinished: Bool { !setups.isEmpty && setups.allSatisfy(\.isFinished) }

    private func begin(_ connection: SourceConnector.Connection) {
        guard let setupDependencies else { return }
        setups.removeAll { $0.id == connection.descriptor.id }
        let setup = SourceSetup(connection, dependencies: setupDependencies)
        setups.append(setup)
        setup.start()
    }

    /// Back from a provider with nothing to watch: stops its loading,
    /// removes what its Connect saved and returns to the form with the
    /// fields as typed (first-run-onboarding/a-provider-with-no-live-channels).
    func discard(_ setup: SourceSetup, in context: ModelContext) {
        setup.stop()
        connector.undo(setup.connection, in: context)
        setups.removeAll { $0.id == setup.id }
        if connection?.descriptor.id == setup.id { connection = nil }
        if setups.isEmpty { returnedToForm = true }
    }

    /// Back from the form: to the summary when sources are connected,
    /// otherwise out of the form. Stops a running Connect. Returns true when
    /// the form closes.
    func leaveForm() -> Bool {
        cancel()
        if !setups.isEmpty {
            addingAnother = false
            return false
        }
        returnedToForm = false
        return true
    }

    /// Add another source: an empty form of the same type. The sources
    /// already connected keep loading.
    func addAnother() {
        fields = SourceFields(kind: fields.kind)
        error = nil
        connection = nil
        revealsPassword = false
        addingAnother = true
    }

    /// Start watching or Browse movies: onboarding lets the app show. The
    /// guide downloads carry on in the guide store.
    func finish() {
        setups.forEach { $0.stop() }
        setups = []
        connection = nil
        addingAnother = false
        returnedToForm = false
        signedIn = false
        fields = SourceFields()
    }

    /// A source sent from the iPhone arrived while the QR card showed. A
    /// playlist goes on to loading and the typed text is discarded
    /// (iphone-as-setup-device/a-playlist-source-sent-from-the-iphone-starts-loading-on-the-tv).
    /// A login source fills in and locks Name and the server, keeps the
    /// login fields as typed, and waits for Connect
    /// (iphone-as-setup-device/a-login-source-sent-from-the-iphone-needs-only-its-login-on-the-tv).
    func received(_ source: SourceDescriptor) async {
        cancel()
        error = nil
        guard source.signsInOnAppleTV else { return await adopt(source) }
        typedBeforeArrival = fields
        fields.kind = source.kind
        fields.name = source.name
        fields.url = source.url.absoluteString
        signIns = [source]
        arrival = source
    }

    /// Downloads an arrived playlist and starts its checklist, adding no source.
    private func adopt(_ source: SourceDescriptor) async {
        connecting = true
        defer { connecting = false }
        let host = source.url.host() ?? source.url.absoluteString
        do {
            let reply = try await connector.probe(source.kind, link: source.url, username: "", password: "", host: host)
            let connection = SourceConnector.Connection(
                descriptor: source, reply: reply, login: nil, inserted: false, createdCredential: nil)
            fields = SourceFields()
            self.connection = connection
            begin(connection)
        } catch is CancellationError {
            return
        } catch {
            fields = SourceFields(kind: source.kind, name: source.name, url: source.url.absoluteString)
            self.error = ConnectFailure(error, host: host).message
        }
    }

    /// Menu from the details step: an arrived login source is let go, and
    /// Name and the server go back to what the user had typed.
    func leaveArrival() {
        guard arrival != nil else { return }
        if let typed = typedBeforeArrival {
            fields.kind = typed.kind
            fields.name = typed.name
            fields.url = typed.url
        }
        typedBeforeArrival = nil
        arrival = nil
        signIns = []
        error = nil
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
