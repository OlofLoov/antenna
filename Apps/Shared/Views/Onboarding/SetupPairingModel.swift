import AntennaCore
import CloudKit
import Foundation
import Observation
import SwiftData

/// The Apple TV side of setting up from an iPhone (iphone-as-setup-device
/// capability). While the details step shows and the TV is signed in to
/// iCloud it holds a setup link with a fresh code, offers it through
/// Handoff, checks the store every 2 seconds for a source sent from the
/// iPhone, and after two minutes without one shows a hint.
@MainActor @Observable
final class SetupPairingModel {
    /// What the details step shows beside the form.
    enum Card: Equatable {
        /// Not signed in to iCloud: the card about the iPhone's keyboard.
        case keyboard
        /// The QR card for this link.
        case code(SetupLink)
    }

    /// The line under the status after two minutes without a usable source.
    enum Hint: Equatable {
        /// Nothing arrived.
        case nothing
        /// A source arrived that the card cannot set up.
        case unusable
    }

    /// What the model needs from outside, so tests can script it.
    struct Dependencies {
        var identity: any ICloudIdentity
        var activity: any SetupActivityRecording
        var sleep: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
        var now: @MainActor () -> Date = { Date.now }
        var token: @MainActor () -> PairingToken = { PairingToken() }
        var pollInterval = Duration.seconds(2)
        var hintDelay: TimeInterval = 120
    }

    private(set) var card = Card.keyboard
    private(set) var hint: Hint?
    /// The source the card took, once one arrived.
    private(set) var arrived: SourceDescriptor?
    /// Called once with the source the card took.
    @ObservationIgnored var onArrival: (SourceDescriptor) -> Void = { _ in }

    @ObservationIgnored private let dependencies: Dependencies
    @ObservationIgnored private var arrivals: SetupArrivals?
    @ObservationIgnored private var shownAt: Date?
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var stopped = false

    init(_ dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    /// The link while the QR card shows and no source has arrived.
    var link: SetupLink? {
        guard case .code(let link) = card, arrived == nil, !stopped else { return nil }
        return link
    }

    /// Onboarding stays up while the QR card shows, so a source arriving
    /// through iCloud does not switch the window to the app first.
    var holdsApp: Bool {
        guard !stopped else { return false }
        if case .code = card { return true }
        return arrived != nil
    }

    /// Runs until the task is cancelled, a source arrives or `stop()` is
    /// called: follows the iCloud sign-in and checks the store.
    func run(in context: ModelContext) async {
        await start(in: context)
        let identity = dependencies.identity
        let follow = Task { [weak self] in
            for await _ in identity.changes() {
                await self?.followSignIn()
            }
        }
        defer {
            follow.cancel()
            end()
        }
        while !Task.isCancelled, !stopped, arrived == nil {
            do {
                try await dependencies.sleep(dependencies.pollInterval)
            } catch {
                return
            }
            check()
        }
    }

    /// Back from sleep: checks at once.
    func wake() {
        check()
    }

    /// Connect on the TV worked, or the step closed: the card, the link and
    /// the Handoff offer go away and the store is no longer checked.
    func stop() {
        stopped = true
        end()
    }

    /// Checks the store for a source sent from the iPhone, and shows the
    /// hint once the delay has passed.
    func check() {
        guard !stopped, arrived == nil, case .code = card, var arrivals, let context else { return }
        let records = (try? context.fetch(FetchDescriptor<SourceRecord>())) ?? []
        let candidates = records.map {
            SetupArrivals.Candidate(id: $0.id, kind: $0.kindRaw, hasAddress: $0.url != nil, createdAt: $0.createdAt)
        }
        let arrival = arrivals.check(candidates)
        self.arrivals = arrivals
        if let arrival {
            let id: UUID
            switch arrival {
            case .playlist(let found), .login(let found, _): id = found
            }
            guard let descriptor = records.first(where: { $0.id == id })?.descriptor else { return }
            arrived = descriptor
            hint = nil
            dependencies.activity.end()
            onArrival(descriptor)
            return
        }
        if let shownAt, dependencies.now().timeIntervalSince(shownAt) >= dependencies.hintDelay {
            hint = arrivals.sawUnusable ? .unusable : .nothing
        }
    }

    /// Reads the iCloud state and shows the QR card when signed in. Tests
    /// call it and `check()` in place of `run(in:)`.
    func start(in context: ModelContext) async {
        self.context = context
        stopped = false
        await followSignIn()
    }

    /// Swaps the QR card and the keyboard card when the iCloud state changed;
    /// a newly shown QR card has a fresh code.
    func followSignIn() async {
        let signedIn = await dependencies.identity.isSignedIn()
        guard !stopped, arrived == nil else { return }
        switch (signedIn, card) {
        case (true, .keyboard): show()
        case (false, .code): end()
        default: break
        }
    }

    /// A new code and a new snapshot of the sources already stored.
    private func show() {
        let link = SetupLink(token: dependencies.token())
        let now = dependencies.now()
        let present = Set(((try? context?.fetch(FetchDescriptor<SourceRecord>())) ?? []).map(\.id))
        arrivals = SetupArrivals(present: present, shownAt: now)
        shownAt = now
        hint = nil
        card = .code(link)
        dependencies.activity.begin(link)
    }

    private func end() {
        dependencies.activity.end()
        guard arrived == nil else { return }
        card = .keyboard
        arrivals = nil
        shownAt = nil
        hint = nil
    }
}

/// Whether this device is signed in to iCloud, and when that changes.
@MainActor
protocol ICloudIdentity {
    func isSignedIn() async -> Bool
    /// Yields each time the account may have changed.
    func changes() -> AsyncStream<Void>
}

/// The Handoff offer for the setup link.
@MainActor
protocol SetupActivityRecording {
    func begin(_ link: SetupLink)
    func end()
}

/// iCloud as CloudKit reports it: only `.available` counts as signed in,
/// so an Apple ID without iCloud Drive does not.
struct CloudKitIdentity: ICloudIdentity {
    static let containerIdentifier = "iCloud.se.codecrave.antenna"

    func isSignedIn() async -> Bool {
        let status = try? await CKContainer(identifier: Self.containerIdentifier).accountStatus()
        return status == .available
    }

    func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
                    continuation.yield()
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// A fixed iCloud state, for tests and UI tests.
@MainActor
final class FixedICloudIdentity: ICloudIdentity {
    var signedIn: Bool {
        didSet { continuation?.yield() }
    }
    private var continuation: AsyncStream<Void>.Continuation?

    init(signedIn: Bool) {
        self.signedIn = signedIn
    }

    func isSignedIn() async -> Bool { signedIn }

    func changes() -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        self.continuation = continuation
        return stream
    }
}

/// The Handoff offer as an `NSUserActivity` holding the link and the code
/// only, kept out of Spotlight, Siri suggestions and public indexing.
@MainActor
final class HandoffSetupActivity: SetupActivityRecording {
    private var activity: NSUserActivity?

    func begin(_ link: SetupLink) {
        end()
        let activity = NSUserActivity(activityType: SetupLink.activityType)
        activity.title = SetupLink.activityTitle
        activity.webpageURL = link.url
        activity.userInfo = link.userInfo
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = false
        activity.isEligibleForPublicIndexing = false
        #if os(iOS)
            activity.isEligibleForPrediction = false
        #endif
        activity.becomeCurrent()
        self.activity = activity
    }

    func end() {
        activity?.invalidate()
        activity = nil
    }
}

/// No Handoff offer, for tests.
@MainActor
final class NoSetupActivity: SetupActivityRecording {
    private(set) var current: SetupLink?
    private(set) var offered: [SetupLink] = []

    func begin(_ link: SetupLink) {
        current = link
        offered.append(link)
    }

    func end() {
        current = nil
    }
}

extension SetupPairingModel.Dependencies {
    /// CloudKit and Handoff, or a scripted iCloud state in a Debug build
    /// launched for UI tests.
    @MainActor static var app: Self {
        #if DEBUG
            if let scripted = UITestingSetup.pairingDependencies() { return scripted }
        #endif
        return .init(identity: CloudKitIdentity(), activity: HandoffSetupActivity())
    }
}
