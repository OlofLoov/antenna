import AntennaCore
import Foundation
import Network
import Observation
import SwiftUI

#if os(iOS)
    import UIKit
#endif

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
        /// Closes every stream this device has open and returns once they are closed.
        var stopLocal: @MainActor () async -> Void = { await OpenEngines.shared.stopAll() }
        var now: @MainActor () -> Date = { .now }
        var sleep: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
        var defaults: UserDefaults = .standard
        var locale = Locale.autoupdatingCurrent
        /// How long a send over the network may take before it gives up.
        var answerLimit = Duration.seconds(3)
        /// How long a TV that was just opened in the menu has to show up on the network.
        var discoveryWait = Duration.milliseconds(1500)
    }

    /// Where `browsing` is kept: true once the user opened Play on with a TV on the account.
    static let browsingKey = "playOn.browsing"

    /// Every device record on the account, as last fetched.
    private(set) var devices: [PlayDeviceInfo] = []
    /// The latest line about a send; the screen clears it once shown.
    var notice: PlayOnNotice?
    /// True while a send is on its way.
    private(set) var sending = false

    @ObservationIgnored let dependencies: Dependencies
    @ObservationIgnored private var active = false

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
    func activate() async {
        active = true
        await publish()
        await refresh()
        if active, browsing, !tvs.isEmpty { dependencies.browser.start() }
    }

    /// The scene went to the background: browsing stops.
    func deactivate() {
        active = false
        dependencies.browser.stop()
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
            return
        }
        _ = try? await dependencies.devices.sweep(notSeenSince: now.addingTimeInterval(-PlayDeviceInfo.forgetAfter))
    }

    /// Reads the account's devices again; a failure keeps the last list.
    func refresh() async {
        guard let devices = try? await dependencies.devices.all() else { return }
        self.devices = devices
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
    /// (play-on-apple-tv/starts-at-once-on-the-same-network). A TV that does
    /// not know this device's key yet gets one more try after the device
    /// list is read again.
    func send(_ item: PlayOnItem, to id: UUID) async {
        guard let tv = tvs.first(where: { $0.id == id }), !sending else { return }
        sending = true
        defer { sending = false }
        opened()
        guard let endpoint = await endpoint(for: tv.id) else {
            notice = PlayOnNotice(text: PlayOnText.unreachable(tv.name, locale: dependencies.locale), kind: .error)
            return
        }
        await dependencies.stopLocal()
        let request = PlayRequest(
            sender: dependencies.device.id, senderName: dependencies.device.name, target: tv.id, source: item.source, item: item.item,
            startPosition: item.start, displayTitle: item.title, created: dependencies.now())
        var outcome = await dependencies.sender.send(request, to: tv.device, at: endpoint, within: dependencies.answerLimit)
        if outcome == .refused {
            // The TV reads the device list again on a refused handshake; give it a moment.
            try? await dependencies.sleep(.seconds(1))
            await refresh()
            if let fresh = devices.first(where: { $0.id == tv.id }) {
                let again = dependencies.browser.endpoints[tv.id] ?? endpoint
                outcome = await dependencies.sender.send(request, to: fresh, at: again, within: dependencies.answerLimit)
            }
        }
        switch outcome {
        case .answered(let result):
            notice = Self.notice(for: result, tv: tv.name, item: item, locale: dependencies.locale)
        case .refused, .noAnswer:
            notice = PlayOnNotice(text: PlayOnText.unreachable(tv.name, locale: dependencies.locale), kind: .error)
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

    /// What a control does for `item`; nil sends nothing.
    func actions(_ item: PlayOnItem?, openURL: OpenURLAction) -> PlayOnActions {
        PlayOnActions(
            opened: { [weak self] in self?.opened() },
            pick: { [weak self] id in
                guard let item else { return }
                Task { await self?.send(item, to: id) }
            },
            openSettings: { if let url = Self.settingsURL { openURL(url) } })
    }

    /// Antuna's page in Settings, where local network access is turned on.
    static var settingsURL: URL? {
        #if os(macOS)
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork")
        #elseif os(iOS)
            URL(string: UIApplication.openSettingsURLString)
        #else
            nil
        #endif
    }

    static func notice(for result: PlayAnswer.Result, tv: String, item: PlayOnItem, locale: Locale) -> PlayOnNotice {
        let text = PlayOnText.line(for: result, tv: tv, item: item.title, sourceName: item.sourceName, locale: locale)
        switch result {
        case .started, .waiting: return PlayOnNotice(text: text, kind: .sent)
        case .noLogin(let source): return PlayOnNotice(text: text, kind: .error, signIn: source)
        case .needsPasscode, .noSource, .notFound, .unsupportedVersion: return PlayOnNotice(text: text, kind: .error)
        }
    }
}

extension EnvironmentValues {
    /// Where a play goes on iPhone, iPad and Mac; nil on Apple TV and in
    /// previews, where no Play on control shows.
    @Entry var playDestination: PlayDestination?
}
