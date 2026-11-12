import AntennaCore
import Foundation
import Observation

/// The Apple TV side of a login sent from the iPhone
/// (apple-tv-login-from-iphone capability). While the sign-in shows, the
/// TV is signed in to iCloud and some source still needs a login, it holds
/// a code with a fresh key, offers it through Handoff, and looks for a
/// delivery every 3 seconds. A code works for one delivery and ten
/// minutes; then a new code and key replace it, and the old key is gone.
/// After two minutes with nothing the card shows a hint.
@MainActor @Observable
final class LoginReceiverModel {
    /// What the sign-in shows beside the fields.
    enum Card: Equatable {
        /// Not signed in to iCloud, or nothing to ask for: the keyboard card.
        case keyboard
        /// The QR card for this link.
        case code(SetupLink)
    }

    /// The card's status line.
    enum Status: Equatable {
        /// "Waiting for your iPhone".
        case waiting
        /// A delivery arrived and these sources' logins are being checked.
        case checking([UUID])
        /// A delivery arrived that this TV cannot open or read.
        case unreadable
    }

    /// What the model needs from outside, so tests can script it.
    struct Dependencies {
        var identity: any ICloudIdentity
        var drops: any LoginDropping
        var activity: any SetupActivityRecording
        var sleep: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
        var now: @MainActor () -> Date = { Date.now }
        var token: @MainActor () -> PairingToken = { PairingToken() }
        var key: @MainActor () -> LoginReceiverKey = { LoginReceiverKey() }
        var pollInterval = Duration.seconds(3)
        var hintDelay: TimeInterval = 120
    }

    private(set) var card = Card.keyboard
    private(set) var status = Status.waiting
    /// True once two minutes passed with nothing delivered.
    private(set) var showsHint = false
    /// The sources the code asks for, at most eight.
    private(set) var requested: [UUID] = []
    /// Checks and keeps the delivered logins; the card reads "checking" until it returns.
    @ObservationIgnored var onDelivery: @MainActor (LoginPayload) async -> Void = { _ in }

    @ObservationIgnored private let dependencies: Dependencies
    @ObservationIgnored private var key: LoginReceiverKey?
    @ObservationIgnored private var madeAt: Date?
    @ObservationIgnored private var shownAt: Date?
    @ObservationIgnored private var signedIn = false
    @ObservationIgnored private var stopped = false
    /// True while one look runs, so a wake from sleep does not start a second.
    @ObservationIgnored private var looking = false

    init(_ dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    /// The link while the QR card shows.
    var link: SetupLink? {
        guard !stopped, case .code(let link) = card else { return nil }
        return link
    }

    /// Asks for `sources`, the first eight, with a new code when the list changed.
    func ask(for sources: [UUID]) {
        let sources = Array(sources.prefix(SetupLink.sourceLimit))
        guard sources != requested else { return }
        requested = sources
        refresh()
    }

    /// Runs until the task is cancelled or `stop()` is called: follows the
    /// iCloud sign-in and looks for deliveries.
    func run() async {
        await start()
        let identity = dependencies.identity
        let follow = Task { [weak self] in
            for await _ in identity.changes() {
                await self?.followSignIn()
            }
        }
        defer {
            follow.cancel()
            stop()
        }
        var wait = dependencies.pollInterval
        while !Task.isCancelled, !stopped {
            do {
                try await dependencies.sleep(wait)
            } catch {
                return
            }
            wait = await check() ?? dependencies.pollInterval
        }
    }

    /// Reads the iCloud state and shows the card. Tests call it and
    /// `check()` in place of `run()`.
    func start() async {
        stopped = false
        await followSignIn()
    }

    /// The user left the sign-in: the code stops working and its key is dropped.
    func stop() {
        stopped = true
        hide()
    }

    /// Shows a code when signed in to iCloud and hides it when signed out.
    func followSignIn() async {
        signedIn = await dependencies.identity.isSignedIn()
        guard !stopped else { return }
        switch (signedIn, card) {
        case (true, .keyboard): refresh()
        case (false, .code): hide()
        default: break
        }
    }

    /// One look for a delivery. Replaces a code ten minutes old, and
    /// returns a longer wait when iCloud asked for one.
    @discardableResult
    func check() async -> Duration? {
        guard !stopped, !looking, case .code(let link) = card, let key, let madeAt else { return nil }
        looking = true
        defer { looking = false }
        let now = dependencies.now()
        if now.timeIntervalSince(madeAt) >= LoginDrops.lifetime {
            refresh()
            return nil
        }
        let drop: LoginDrop?
        do {
            drop = try await dependencies.drops.fetch(token: link.token)
        } catch .busy(let seconds) {
            return .seconds(seconds ?? 0) + dependencies.pollInterval
        } catch {
            return nil
        }
        guard self.link == link else { return nil }
        guard case .waiting(let sealed) = drop else {
            if let shownAt, now.timeIntervalSince(shownAt) >= dependencies.hintDelay { showsHint = true }
            return nil
        }
        try? await dependencies.drops.pickUp(token: link.token)
        self.key = nil
        let payload: LoginPayload
        do {
            payload = try LoginSeal.open(sealed, with: key, token: link.token)
        } catch {
            status = .unreadable
            refresh()
            return nil
        }
        status = .checking(payload.logins.map(\.source).filter(requested.contains))
        showsHint = false
        await onDelivery(payload)
        status = .waiting
        if self.link == link { refresh() }
        return nil
    }

    /// A new code when there is something to ask for, the keyboard card otherwise.
    private func refresh() {
        guard !stopped, signedIn, !requested.isEmpty else { return hide() }
        let key = dependencies.key()
        let link = SetupLink(token: dependencies.token(), key: key.publicKey, sources: requested)
        self.key = key
        madeAt = dependencies.now()
        if shownAt == nil { shownAt = madeAt }
        card = .code(link)
        dependencies.activity.begin(link)
    }

    private func hide() {
        dependencies.activity.end()
        card = .keyboard
        key = nil
        madeAt = nil
        shownAt = nil
        showsHint = false
        if case .checking = status { return }
        status = .waiting
    }
}

extension LoginReceiverModel.Dependencies {
    /// CloudKit and Handoff, or the scripted ones in a Debug build launched for UI tests.
    @MainActor static var app: Self {
        #if DEBUG
            if let scripted = UITestingLoginDrops.receiverDependencies() { return scripted }
        #endif
        return .init(identity: CloudKitIdentity(), drops: CloudKitLoginDrops(), activity: HandoffSetupActivity())
    }
}
