#if os(tvOS)
    import AntennaCore
    import Foundation
    import Observation
    import SwiftUI

    /// Requests from a phone wait here, outside every gate, until the shell
    /// takes them, as Top Shelf links do. Unlike a shelf link, a request
    /// that arrives behind the paywall or "Who's watching?" is kept and
    /// plays once the shell shows
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

        /// The shell shows: a kept request plays now.
        func attach() {
            attached = true
            if let kept {
                self.kept = nil
                delivery = Delivery(request: kept) { _ in }
            }
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
    /// listening in the background, since tvOS suspends the app.
    @MainActor
    final class PlayOnReceiver {
        let inbox: PlayRequestInbox
        private let device: PlayOnDevice
        private let devices: any PlayDeviceStoring
        private let listener: PlayOnListener
        private var published: PlayDeviceInfo?
        private var lastRefetch = Date.distantPast
        private var active = false

        init(inbox: PlayRequestInbox, device: PlayOnDevice, devices: any PlayDeviceStoring, advertises: Bool = true) {
            self.inbox = inbox
            self.device = device
            self.devices = devices
            listener = PlayOnListener(device: device, advertises: advertises)
            listener.request = { [weak inbox] request, reply in
                guard let inbox else { return reply(.waiting) }
                inbox.receive(request, reply: reply)
            }
            listener.refused = { [weak self] in
                Task { await self?.refetch() }
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
            if active { listener.start() }
        }

        func deactivate() {
            active = false
            listener.stop()
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
