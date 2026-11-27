#if os(tvOS)
    import AntennaCore
    import Foundation
    import Observation
    import SwiftUI

    /// Requests from a phone wait here, outside every gate, until the shell
    /// takes them, as Top Shelf links do. Unlike a shelf link, a request
    /// that arrives behind the paywall or "Who's watching?" is kept and
    /// offered once the shell shows
    /// (play-on-apple-tv/the-tv-keeps-its-own-locks-and-profile). A request
    /// id the TV has handled once is not handled again, so the same request
    /// arriving a second way plays once.
    @MainActor @Observable
    final class PlayRequestInbox {
        /// The "From Anna's iPhone" line over the TV for four seconds,
        /// with the reason when the request could not play.
        struct Banner: Identifiable, Equatable {
            let id = UUID()
            var eyebrow: String
            var line: String
        }

        /// A request for the shell to play, with where its answer goes.
        struct Delivery: Identifiable {
            var request: PlayRequest
            var reply: @MainActor (PlayAnswer.Result) -> Void
            var id: UUID { request.id }
        }

        /// The request the shell plays next.
        private(set) var delivery: Delivery?
        /// The banner on screen, nil while none shows.
        var banner: Banner?

        /// A request kept while no shell shows, as behind the paywall.
        @ObservationIgnored private(set) var kept: PlayRequest?
        @ObservationIgnored private(set) var handled: Set<UUID> = []
        @ObservationIgnored private var attached = false

        /// Takes a request from the network. With the shell up it goes to
        /// the shell, which answers through `reply`; otherwise it is kept
        /// and the answer is `.waiting`. A request handled before answers
        /// `.started` and plays nothing.
        func receive(_ request: PlayRequest, reply: @escaping @MainActor (PlayAnswer.Result) -> Void) {
            guard !handled.contains(request.id) else { return reply(.started) }
            handled.insert(request.id)
            guard attached else {
                kept = request
                return reply(.waiting)
            }
            delivery = Delivery(request: request, reply: reply)
        }

        /// The shell shows: a request kept behind a gate is offered now.
        func attach() {
            attached = true
            if let kept {
                self.kept = nil
                offered = kept
            }
        }

        // MARK: Connected phones

        /// What the TV plays, as connected phones see it; the shell keeps it
        /// current (play-on-apple-tv/connected-to-a-tv).
        var status: PlayStatus?

        /// Play, pause or hand-off from a connected phone, for the shell.
        struct ControlRequest: Identifiable, Equatable {
            let id = UUID()
            var control: PlayControl
        }

        private(set) var controlRequest: ControlRequest?

        /// A phone asked the TV to play, pause or hand off.
        func receive(_ control: PlayControl) {
            controlRequest = ControlRequest(control: control)
        }

        /// The next control, once; the shell acts on it.
        func takeControl() -> PlayControl? {
            defer { controlRequest = nil }
            return controlRequest?.control
        }

        /// The id of the request the TV plays now, so a status can name it.
        @ObservationIgnored var playingRequest: UUID?

        // MARK: Offer

        /// The request the TV offers with Play and Not now: one that waited
        /// in iCloud, or one that arrived behind a gate
        /// (play-on-apple-tv/the-tv-offers-a-waiting-request).
        private(set) var offered: PlayRequest?

        /// Offers `request` unless the TV has handled its id already.
        func offer(_ request: PlayRequest) {
            guard !handled.contains(request.id) else { return }
            handled.insert(request.id)
            offered = request
        }

        /// Play on the offer: the shell plays it as it plays a request from the network.
        func playOffered() {
            guard let offered else { return }
            self.offered = nil
            delivery = Delivery(request: offered) { _ in }
        }

        /// Not now, or Menu, on the offer: the TV stays where it was.
        func dismissOffered() {
            offered = nil
        }

        /// The shell went away, as when "Who's watching?" replaces it.
        func detach() {
            attached = false
        }

        /// The next request, once; the shell plays it.
        func take() -> Delivery? {
            defer { delivery = nil }
            return delivery
        }

        /// The banner for `request`, with `reason` when it did not play.
        func announce(_ request: PlayRequest, reason: String? = nil, locale: Locale = .autoupdatingCurrent) {
            banner = Banner(eyebrow: PlayOnText.from(request.senderName, locale: locale), line: reason ?? request.displayTitle)
        }
    }

    /// The Apple TV's side of Play on while the scene is active: it writes
    /// the TV's record, reads the account's devices, and listens on the home
    /// network for the phones, iPads and Macs among them
    /// (play-on-apple-tv/starts-at-once-on-the-same-network). It stops
    /// listening in the background, since tvOS suspends the app. It also
    /// picks up the request waiting for this TV in iCloud on launch, on
    /// returning to the foreground, on a push and every 30 seconds while
    /// active, since pushes can be held back
    /// (play-on-apple-tv/the-tv-offers-a-waiting-request).
    @MainActor
    final class PlayOnReceiver {
        /// How often the TV looks for a waiting request while it is active.
        static let pickupInterval = Duration.seconds(30)

        let inbox: PlayRequestInbox
        private let device: PlayOnDevice
        private let devices: any PlayDeviceStoring
        private let queue: (any PlayRequestQueueing)?
        private let subscribe: @MainActor () async -> Void
        private let listener: PlayOnListener
        private var published: PlayDeviceInfo?
        private var subscribed = false
        private var lastRefetch = Date.distantPast
        private var active = false
        private var polling: Task<Void, Never>?
        private var pump: Task<Void, Never>?

        init(
            inbox: PlayRequestInbox, device: PlayOnDevice, devices: any PlayDeviceStoring, queue: (any PlayRequestQueueing)? = nil,
            advertises: Bool = true, subscribe: @escaping @MainActor () async -> Void = {}
        ) {
            self.inbox = inbox
            self.device = device
            self.devices = devices
            self.queue = queue
            self.subscribe = subscribe
            listener = PlayOnListener(device: device, advertises: advertises)
            listener.request = { [weak inbox] request, reply in
                guard let inbox else { return reply(.waiting) }
                inbox.receive(request, reply: reply)
            }
            listener.refused = { [weak self] in
                Task { await self?.refetch() }
            }
            listener.control = { [weak inbox] control in inbox?.receive(control) }
            listener.currentStatus = { [weak inbox] in inbox?.status }
        }

        /// Sends the status to connected phones when it changes, checked
        /// twice a second, and every five seconds as a sign of life.
        private func pumpStatus() async {
            var last: PlayStatus?
            var sentAt = ContinuousClock.now
            while !Task.isCancelled {
                if let status = inbox.status, status != last || ContinuousClock.now - sentAt >= .seconds(5) {
                    listener.broadcast(status)
                    last = status
                    sentAt = .now
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }

        /// The port the listener got, for tests that connect without Bonjour.
        var port: UInt16? { listener.port?.rawValue }

        func activate() async {
            active = true
            let now = Date.now
            if published.map({ $0.needsRefresh(keyDate: device.keys.keyDate, now: now) }) ?? true {
                let info = device.info(now: now)
                if (try? await devices.save(info)) != nil { published = info }
                _ = try? await devices.sweep(notSeenSince: now.addingTimeInterval(-PlayDeviceInfo.forgetAfter))
            }
            if let all = try? await devices.all() { listener.accept(all) }
            // The scene may have left the foreground while the records were read.
            guard active else { return }
            listener.start()
            if !subscribed {
                subscribed = true
                await subscribe()
            }
            polling?.cancel()
            polling = Task { [weak self] in
                while !Task.isCancelled {
                    await self?.pickUp()
                    try? await Task.sleep(for: Self.pickupInterval)
                }
            }
            pump?.cancel()
            pump = Task { [weak self] in await self?.pumpStatus() }
        }

        func deactivate() {
            active = false
            polling?.cancel()
            polling = nil
            pump?.cancel()
            pump = nil
            listener.stop()
        }

        /// Takes the request waiting for this TV, if any: an expired one is
        /// deleted unread, any other is deleted and offered
        /// (play-on-apple-tv/requests-expire-and-leave-no-trace). One the TV
        /// already played from the network is deleted without an offer.
        func pickUp(now: Date = .now) async {
            guard let queue, let request = try? await queue.waiting(for: device.id) else { return }
            try? await queue.delete(request)
            _ = try? await queue.sweep(now: now)
            guard !request.isExpired(at: now) else { return }
            inbox.offer(request)
        }

        /// A device the TV does not know yet tried to connect: read the
        /// list again, at most once every five seconds.
        private func refetch() async {
            guard Date.now.timeIntervalSince(lastRefetch) > 5 else { return }
            lastRefetch = .now
            if let all = try? await devices.all() { listener.accept(all) }
        }
    }
#endif
