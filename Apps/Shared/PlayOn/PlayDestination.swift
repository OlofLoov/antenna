import AntennaCore
import Foundation
import Network
import Observation
import SwiftUI

/// What a screen asks to play on a TV: the item by key, its source and the
/// names the TV and the messages show.
struct PlayOnItem: Equatable, Sendable {
    var item: PlayRequest.Item
    var source: UUID
    /// The channel or title name, as the TV's banner shows it.
    var title: String
    /// The source's name, for "Living Room isn't signed in to Acme TV."
    var sourceName: String
    /// Seconds into a film or episode; nil plays from the TV's saved place.
    var start: TimeInterval?
}

extension PlayOnItem {
    /// A channel live.
    static func channel(_ channel: Channel, sourceName: String) -> PlayOnItem? {
        guard let source = channel.sourceID else { return nil }
        return PlayOnItem(item: .channel(key: PlayItemKeys.channel(channel)), source: source, title: channel.name, sourceName: sourceName)
    }

    /// A programme in the guide: live while it airs, catch-up once it ended.
    static func programme(_ programme: Programme, on channel: Channel, sourceName: String) -> PlayOnItem? {
        guard let source = channel.sourceID else { return nil }
        return PlayOnItem(
            item: .programme(channelKey: PlayItemKeys.channel(channel), start: programme.start, end: programme.stop), source: source,
            title: programme.title, sourceName: sourceName)
    }

    /// One episode from `position` seconds, 0 for its start.
    static func episode(_ episode: Episode, of series: ShelfTitle, from position: Double, sourceName: String) -> PlayOnItem {
        PlayOnItem(
            item: .episode(seriesKey: PlayItemKeys.title(series), episodeKey: PlayItemKeys.episode(episode)), source: series.sourceID,
            title: "\(series.name): \(episode.title)", sourceName: sourceName, start: position > 0 ? position : nil)
    }
}

/// A line the phone shows about a send.
struct PlayOnNotice: Identifiable, Equatable {
    enum Kind: Equatable {
        /// The TV started, or the request waits for it.
        case sent
        /// The TV cannot play it; the reason is in `text`.
        case error
    }

    let id = UUID()
    var text: String
    var kind: Kind
    /// The source to sign the TV in to, when its login is missing there.
    var signIn: UUID?
    /// The request Cancel on this line takes back, while it can
    /// (play-on-apple-tv/the-phone-can-take-a-request-back).
    var cancel: UUID?
}

/// The Play on control's rows: each Apple TV on the account and whether it
/// can start now (play-on-apple-tv/apple-tvs-on-the-same-icloud-account).
struct PlayOnChoice: Equatable {
    struct Row: Identifiable, Equatable {
        let id: UUID
        let name: String
        let ready: Bool
    }

    var rows: [Row]
    /// Local network access was refused; the menu points at Settings.
    var accessRefused: Bool
}

/// What a Play on control does.
struct PlayOnActions {
    /// The control was opened or tapped, before any pick.
    var opened: () -> Void
    /// Sends to the TV with this id.
    var pick: (UUID) -> Void
    /// Opens the app's page in Settings.
    var openSettings: () -> Void
}

/// Where a play from this phone, iPad or Mac goes: the Apple TVs on the
/// account, which of them answer on the network now, and sending to one
/// (play-on-apple-tv capability). Screens read it through `playDestination`.
@MainActor @Observable
final class PlayDestination {
    struct Dependencies {
        var devices: any PlayDeviceStoring
        var browser: any PlayOnBrowsing
        var sender: any PlayOnSending
        var device: PlayOnDevice
        /// Where a request waits for a TV the network did not reach; nil sends over the network only.
        var queue: (any PlayRequestQueueing)?
        /// Closed while connected, so no screen opens a stream here.
        var gate: StreamGate = .app
        /// How long a connection lasts without a status from the TV.
        var liveness = Duration.seconds(10)
        /// How long "Stopped on Living Room" shows before the bar goes.
        var stoppedShows = Duration.seconds(3)
        /// Closes every stream this device has open and returns once they are closed.
        var stopLocal: @MainActor () async -> Void = { await OpenEngines.shared.stopAll() }
        var now: @MainActor () -> Date = { .now }
        var sleep: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
        var defaults: UserDefaults = .standard
        var locale = Locale.autoupdatingCurrent
        /// How long a send over the network has to reach the TV, and then for its answer.
        var limits = PlaySendLimits()
        /// How long a TV the browser has not found yet has to show up on the network.
        var discoveryWait = Duration.seconds(3)
        /// Waits between reads of the device list while the account has no TV yet.
        var rereadWait: @MainActor () async throws -> Void = { try await Task.sleep(for: PlayDestination.rereadInterval) }
    }

    /// How often the device list is read again while the scene is active and no TV is listed.
    static let rereadInterval = Duration.seconds(30)

    /// How long the "Sent" line offers Cancel: long enough for an open TV
    /// to pick the request up and count it down.
    static let cancelWindow = Duration.seconds(10)

    /// Where `browsing` is kept: true once the user opened Play on with a TV on the account.
    static let browsingKey = "playOn.browsing"

    /// Every device record on the account, as last fetched.
    private(set) var devices: [PlayDeviceInfo] = []
    /// The latest line about a send; the screen clears it once shown.
    var notice: PlayOnNotice? {
        didSet { if notice?.cancel == nil { pending = nil } }
    }
    /// True while a send is on its way.
    private(set) var sending = false

    @ObservationIgnored let dependencies: Dependencies
    @ObservationIgnored private var active = false
    /// Reads the device list again until a TV shows up.
    @ObservationIgnored private var rereading: Task<Void, Never>?
    /// When the device list was last read.
    @ObservationIgnored private var lastRead: Date?

    init(_ dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    /// The Apple TVs worth listing, numbered where names repeat.
    var tvs: [PlayTV] {
        PlayTV.listed(devices, now: dependencies.now(), locale: dependencies.locale)
    }

    /// The menu's rows, those ready now first; nil with no TV on the account,
    /// so every Play on control stays out.
    var choice: PlayOnChoice? {
        let tvs = tvs
        guard !tvs.isEmpty else { return nil }
        let refused = dependencies.browser.denied
        let ready = refused ? [] : Set(dependencies.browser.endpoints.keys)
        let rows = PlayTV.ordered(tvs, ready: ready, locale: dependencies.locale).map { tv in
            PlayOnChoice.Row(id: tv.id, name: tv.name, ready: ready.contains(tv.id))
        }
        return PlayOnChoice(rows: rows, accessRefused: refused)
    }

    /// True once the user has opened Play on with a TV on the account.
    var browsing: Bool {
        get {
            dependencies.defaults.data(forKey: Self.browsingKey).flatMap { try? JSONDecoder().decode(Bool.self, from: $0) } ?? false
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { dependencies.defaults.set(data, forKey: Self.browsingKey) }
        }
    }

    // MARK: Scene

    /// The scene became active: write this device's record, read the
    /// account's devices and browse, if the user has opened Play on before.
    /// Requests nobody picked up before they expired are deleted unread
    /// (play-on-apple-tv/requests-expire-and-leave-no-trace).
    func activate() async {
        active = true
        // Browsing first, so the TV is found while iCloud answers
        // (play-on-apple-tv/starts-at-once-on-the-same-network).
        if browsing { dependencies.browser.start() }
        await publish()
        await refresh()
        rereadUntilATVShows()
        await reconnect()
        do {
            _ = try await dependencies.queue?.sweep(now: dependencies.now())
        } catch {
            PlayOnLog.failure("sweep requests", error)
        }
    }

    /// A TV that opens Antuna for the first time while the phone is open
    /// shows up within 30 seconds: until one is listed, the device list is
    /// read again on that interval while the scene is active
    /// (play-on-apple-tv/apple-tvs-on-the-same-icloud-account, a TV that registers later).
    private func rereadUntilATVShows() {
        guard rereading == nil, active, tvs.isEmpty else { return }
        rereading = Task { [weak self] in
            while !Task.isCancelled {
                guard let wait = self?.dependencies.rereadWait else { return }
                do { try await wait() } catch { break }
                guard let self, self.active, !Task.isCancelled else { break }
                await self.refresh()
                if !self.tvs.isEmpty {
                    if self.browsing { self.dependencies.browser.start() }
                    break
                }
            }
            if !Task.isCancelled { self?.rereading = nil }
        }
    }

    /// A screen with a Play on control appeared: with no TV listed yet, the
    /// device list is read again, at most once every 10 seconds.
    func lookForTVs() async {
        guard tvs.isEmpty else { return }
        if let lastRead, dependencies.now().timeIntervalSince(lastRead) < 10 { return }
        await refresh()
    }

    /// The scene went to the background: browsing stops and the connection
    /// ends, remembering what the TV played so the phone can connect again
    /// when it comes back (play-on-apple-tv/the-connection-ends-cleanly).
    /// The phone opens no stream in between.
    func deactivate() {
        active = false
        rereading?.cancel()
        rereading = nil
        if let connection, !connection.stopped {
            resume = Resume(tv: connection.tv.id, request: connection.status?.requestID)
            connection.ended = {}
            connection.disconnectQuietly()
            self.connection = nil
        }
        dependencies.browser.stop()
    }

    // MARK: Connected

    /// The TV this phone is connected to, nil while plays start here
    /// (play-on-apple-tv/connected-to-a-tv).
    private(set) var connection: PlayOnConnection?

    /// What the phone was connected to when it went to the background.
    private struct Resume {
        var tv: UUID
        var request: UUID?
    }

    @ObservationIgnored private var resume: Resume? {
        didSet { updateGate() }
    }

    /// Plays the TV's item here once the TV stopped; the screen that owns
    /// playback sets it (play-on-apple-tv/play-on-this-iphone).
    @ObservationIgnored var playHere: @MainActor (PlayStatus) -> Void = { _ in }

    /// Sends `item` to the connected TV instead of playing it here; false
    /// when not connected, so the caller plays it here
    /// (play-on-apple-tv/play-goes-to-the-tv-while-connected).
    @discardableResult
    func playOnTV(_ item: PlayOnItem) -> Bool {
        guard let tv = connection?.tv else { return false }
        Task { await send(item, to: tv.id) }
        return true
    }

    /// Play or pause on the TV.
    func playPause() {
        guard let connection else { return }
        connection.control(connection.isPlaying ? .pause : .play)
    }

    /// Leaves the TV playing and lets the phone play on its own again.
    func disconnect() {
        connection?.disconnect()
    }

    /// Stops the TV and plays the same item here from the TV's place.
    func moveHere() async {
        guard let connection else { return }
        let status = await connection.handOff()
        if let status { playHere(status) }
    }

    func connect(_ link: any PlayOnLinking, to tv: PlayTV) {
        let connection = PlayOnConnection(tv: tv, link: link, liveness: dependencies.liveness, stoppedShows: dependencies.stoppedShows)
        connection.ended = { [weak self, weak connection] in
            guard let self, self.connection === connection else { return }
            self.connection = nil
            updateGate()
        }
        self.connection = connection
        resume = nil
        connection.start()
        updateGate()
    }

    /// Back in the foreground after being connected: connects again when
    /// the TV still plays what this phone sent; until then, and if that
    /// fails, the phone opens no stream.
    private func reconnect() async {
        guard let resume, connection == nil else { return }
        defer { self.resume = nil }
        guard let tv = tvs.first(where: { $0.id == resume.tv }), let endpoint = await endpoint(for: tv.id),
            let link = await dependencies.sender.connect(to: tv.device, at: endpoint, within: dependencies.limits.reach)
        else { return }
        let first = await firstStatus(on: link)
        guard let first, first.state != .stopped, resume.request == nil || first.requestID == resume.request else {
            link.close()
            return
        }
        connect(link, to: tv)
        connection?.adopt(first)
    }

    /// The first status the TV sends on a fresh link, which it sends on
    /// connecting and then every five seconds.
    private func firstStatus(on link: any PlayOnLinking) async -> PlayStatus? {
        await withCheckedContinuation { continuation in
            var done = false
            let resolve: @MainActor (PlayStatus?) -> Void = { status in
                guard !done else { return }
                done = true
                continuation.resume(returning: status)
            }
            link.listen { result in
                if case .success(.status(let status)) = result { resolve(status) }
            }
            link.changed = { state in
                if case .ended = state { resolve(nil) }
            }
            Task {
                try? await Task.sleep(for: .seconds(6))
                resolve(nil)
            }
        }
    }

    /// Closed while connected, or while a connection may come back.
    private func updateGate() {
        if connection != nil || resume != nil { dependencies.gate.close() } else { dependencies.gate.open() }
    }

    /// Writes this device's record when it has a new key or is a day old.
    @ObservationIgnored private var published: PlayDeviceInfo?

    private func publish() async {
        let now = dependencies.now()
        if let published, !published.needsRefresh(keyDate: dependencies.device.keys.keyDate, now: now) { return }
        let info = dependencies.device.info(now: now)
        do {
            try await dependencies.devices.save(info)
            published = info
        } catch {
            PlayOnLog.failure("save this device", error)
            return
        }
        do {
            try await dependencies.devices.sweep(notSeenSince: now.addingTimeInterval(-PlayDeviceInfo.forgetAfter))
        } catch {
            PlayOnLog.failure("sweep devices", error)
        }
    }

    /// Reads the account's devices again; a failure keeps the last list.
    func refresh() async {
        lastRead = dependencies.now()
        do {
            let devices = try await dependencies.devices.all()
            self.devices = devices
            PlayOnLog.read(devices)
        } catch {
            PlayOnLog.failure("read devices", error)
        }
    }

    /// The user opened Play on: from now on the browser runs while the
    /// scene is active, which is when iOS asks for local network access
    /// (play-on-apple-tv/the-local-network-is-asked-for-only-when-needed).
    func opened() {
        guard !tvs.isEmpty else { return }
        browsing = true
        dependencies.browser.start()
        Task { await refresh() }
    }

    // MARK: Sending

    /// Sends `item` to `tv` and leaves a notice saying how it went. Over the
    /// network the phone first closes every stream it has open, so the
    /// provider sees one connection
    /// (play-on-apple-tv/starts-at-once-on-the-same-network). A refused
    /// handshake or a dropped connection is tried again as `PlaySendRetry`
    /// says, reading the device list again after a refusal, before the
    /// request goes through iCloud.
    func send(_ item: PlayOnItem, to id: UUID) async {
        guard let tv = tvs.first(where: { $0.id == id }), !sending else { return }
        sending = true
        defer { sending = false }
        pending = nil
        opened()
        let request = PlayRequest(
            sender: dependencies.device.id, senderName: dependencies.device.name, target: tv.id, source: item.source, item: item.item,
            startPosition: item.start, displayTitle: item.title, created: dependencies.now())
        if let connection, connection.tv.id == tv.id {
            // Connected: the request goes over the open link, and nothing plays here.
            if let result = await connection.send(request, within: dependencies.limits.answer) {
                notice = Self.notice(for: result, tv: tv.name, item: item, locale: dependencies.locale, connected: true)
                return
            }
        }
        connection?.disconnect()
        let failure: PlaySendFailure
        var attempts = 0
        if let endpoint = await endpoint(for: tv.id) {
            await dependencies.stopLocal()
            var target = tv.device
            var at = endpoint
            while true {
                attempts += 1
                let sent = await dependencies.sender.send(request, to: target, at: at, limits: dependencies.limits)
                if case .answered(let result) = sent.outcome {
                    return answered(result, link: sent.link, request: request, item: item, tv: tv)
                }
                let failed = sent.outcome.failure ?? .noAnswer
                guard let wait = PlaySendRetry.delay(after: failed, attempt: attempts) else {
                    failure = failed
                    break
                }
                PlayOnLog.retry(failed, attempt: attempts)
                try? await dependencies.sleep(wait)
                if failed == .refused {
                    // The TV reads the device list again on a refused handshake; so does the phone.
                    await refresh()
                    target = devices.first(where: { $0.id == tv.id }) ?? target
                }
                at = dependencies.browser.endpoints[tv.id] ?? at
            }
        } else {
            failure = dependencies.browser.denied ? .accessRefused : .notFound
        }
        PlayOnLog.fallback(failure, attempts: attempts)
        await queue(request, for: tv)
    }

    /// The request the "Sent" line's Cancel takes back, cleared with the line.
    @ObservationIgnored var pending: PlayPending?

    /// Leaves `request` in iCloud for the TV to count down if Antuna opens
    /// there within a minute, after the network found no TV or got no answer. The same
    /// request never goes both ways at once, and the TV plays a request
    /// id once (play-on-apple-tv/waits-in-icloud-when-the-tv-is-not-reachable).
    private func queue(_ request: PlayRequest, for tv: PlayTV) async {
        let locale = dependencies.locale
        guard let queue = dependencies.queue else {
            notice = PlayOnNotice(text: PlayOnText.unreachable(tv.name, locale: locale), kind: .error)
            return
        }
        do {
            try await queue.save(request)
            notice = PlayOnNotice(text: PlayOnText.sent(to: tv.name, locale: locale), kind: .sent, cancel: request.id)
            pending = PlayPending(request: request, tv: tv, queued: true)
        } catch .offline {
            PlayOnLog.failure("save request", PlayOnStoreError.offline)
            notice = PlayOnNotice(text: PlayOnText.offline(locale), kind: .error)
        } catch {
            PlayOnLog.failure("save request", error)
            notice = PlayOnNotice(text: PlayOnText.unreachable(tv.name, locale: locale), kind: .error)
        }
    }

    /// The TV's endpoint, waiting a moment for one that the browser has not
    /// found yet, as right after the first tap.
    private func endpoint(for id: UUID) async -> NWEndpoint? {
        if dependencies.browser.denied { return nil }
        if let endpoint = dependencies.browser.endpoints[id] { return endpoint }
        let steps = 10
        for _ in 0..<steps {
            do { try await dependencies.sleep(dependencies.discoveryWait / steps) } catch { return nil }
            if let endpoint = dependencies.browser.endpoints[id] { return endpoint }
            if dependencies.browser.denied { return nil }
        }
        return nil
    }
}

extension EnvironmentValues {
    /// Where a play goes on iPhone, iPad and Mac; nil on Apple TV and in
    /// previews, where no Play on control shows.
    @Entry var playDestination: PlayDestination?
}
