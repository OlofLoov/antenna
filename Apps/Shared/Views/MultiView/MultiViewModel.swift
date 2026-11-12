import AntennaCore
import Foundation
import Observation

/// One multi-view session on screen (multi-view capability), shared by
/// Apple TV and the Mac: the session, each tile's loading or failure, the
/// hint and the full-screen badge. Every action runs the session's
/// commands on the tiles' engines in order. The screen that hosts it
/// learns from `ended` which channel plays on alone.
@MainActor @Observable
final class MultiViewModel {
    /// What a tile shows over its picture.
    enum TileStatus: Equatable {
        case waiting
        case playing
        case failed(FailureMessage)
    }

    struct Dependencies {
        var tiles = TileEngines.Dependencies()
        var device: FailureMessage.Device = .current
        var cap: MultiViewCap = .current
        var sleep: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
        /// How long the hint and the full-screen badge show.
        var showFor = Duration.seconds(5)
    }

    private(set) var session: MultiViewSession
    private(set) var statuses: [Int: TileStatus] = [:]
    /// The keys hint after entering, for a few seconds.
    private(set) var hintShown = false
    /// The badge over a full-screen tile, for a few seconds after it enlarges.
    private(set) var badgeShown = false
    /// The tile whose channel the picker changes, nil while it is closed.
    var picking: Int?
    /// The tile whose actions menu is open, nil while it is closed.
    var actionsOpen: Int?

    @ObservationIgnored let engines: TileEngines
    @ObservationIgnored private let dependencies: Dependencies
    @ObservationIgnored private let channel: @MainActor (RowKey) -> Channel?
    @ObservationIgnored private let sourceName: @MainActor (UUID) -> String
    /// Told once when multi-view ends: the channel that plays on alone in
    /// the single player, or nil when every tile stopped.
    @ObservationIgnored var ended: @MainActor (Channel?) -> Void = { _ in }
    @ObservationIgnored private var start: [MultiViewSession.Command]
    @ObservationIgnored private var watches: [Int: Task<Void, Never>] = [:]
    @ObservationIgnored private var hintTimer: Task<Void, Never>?
    @ObservationIgnored private var badgeTimer: Task<Void, Never>?

    /// Nil when `adding` cannot join `playing` (multi-view/start-multi-view-on-apple-tv):
    /// the same channel, or a channel with no place in a source.
    init?(
        playing: Channel, adding: Channel, single: RoutedEngine, dependencies: Dependencies = Dependencies(),
        channel: @escaping @MainActor (RowKey) -> Channel?, sourceName: @escaping @MainActor (UUID) -> String
    ) {
        guard let first = RowKey(playing), let second = RowKey(adding),
            let started = MultiViewSession.start(playing: first, adding: second, cap: dependencies.cap)
        else { return nil }
        session = started.0
        start = started.1
        self.dependencies = dependencies
        self.channel = channel
        self.sourceName = sourceName
        engines = TileEngines(single: single, dependencies: dependencies.tiles)
    }

    // MARK: Reading

    var isOpen: Bool { session.isOpen }

    func status(_ id: Int) -> TileStatus { statuses[id] ?? .waiting }

    func channel(of id: Int) -> Channel? {
        session.tile(id).flatMap { channel($0.channel) }
    }

    func engine(of id: Int) -> RoutedEngine? { engines.engines[id] }

    /// "2 of 4".
    var count: String { session.cap.count(tiles: session.tiles.count) }

    /// "Tile 2 of 4" for the selected tile.
    var selectedName: String {
        MultiViewText.selected(tile: session.number(of: session.selected) ?? 1, of: session.tiles.count)
    }

    /// The tile showing `channel`, as "TILE n" badges count.
    func tileNumber(showing key: RowKey) -> Int? {
        session.tile(showing: key).flatMap { session.number(of: $0.id) }
    }

    /// "Loading", the failure's title and explanation, or nothing while it plays.
    func statusText(_ id: Int) -> String {
        switch status(id) {
        case .waiting: "Loading"
        case .playing: ""
        case .failed(let message): "\(message.title). \(message.explanation)"
        }
    }

    func spokenLabel(_ id: Int) -> String {
        let shown = channel(of: id)
        return MultiViewText.spokenLabel(number: shown?.number, name: shown?.name ?? "", audible: session.audible == id)
    }

    // MARK: Actions

    /// Runs the start: the playing channel moves into tile 1, the new one
    /// opens in tile 2 with the sound, and the hint shows.
    func begin() async {
        let commands = start
        start = []
        showHint()
        await apply(commands)
    }

    func select(_ id: Int) async {
        guard session.selected != id || (session.enlarged != nil && session.enlarged != id) else { return }
        await apply(session.select(id))
    }

    func add(_ channel: Channel) async {
        guard let key = RowKey(channel) else { return }
        picking = nil
        await apply(session.add(key))
    }

    /// Shows `channel` in tile `id`, as the picker's Watch and the Mac list do.
    func change(_ id: Int, to channel: Channel) async {
        guard let key = RowKey(channel) else { return }
        picking = nil
        await apply(session.change(id, to: key))
    }

    func enlarge(_ id: Int) async {
        actionsOpen = nil
        await apply(session.enlarge(id))
        showBadge()
    }

    func shrink() {
        session.shrink()
        badgeShown = false
    }

    func retry(_ id: Int) async {
        actionsOpen = nil
        await apply(session.retry(id))
    }

    func remove(_ id: Int) async {
        actionsOpen = nil
        await apply(session.remove(id))
    }

    /// Ends multi-view keeping the selected tile's channel.
    func leave() async {
        picking = nil
        actionsOpen = nil
        await apply(session.leave())
    }

    /// The sources' channels changed. A tile whose channel is gone is
    /// removed (multi-view/remove-a-tile).
    func channelsChanged(isListed: (RowKey) -> Bool) async {
        await apply(session.channelsChanged(isListed: isListed))
    }

    /// Stops every tile at once, as when the paywall replaces the screen
    /// (multi-view/leave-multi-view).
    func stopAll() {
        watches.values.forEach { $0.cancel() }
        watches = [:]
        engines.stopAll()
    }

    // MARK: Running commands

    private func apply(_ commands: [MultiViewSession.Command]) async {
        guard !commands.isEmpty else { return }
        for case .load(let tile, _) in commands { statuses[tile] = .waiting }
        await engines.run(commands, channel: channel) { [weak self] tile, failure in
            self?.stateChanged(tile, .failed(failure))
        }
        engines.sharingChanged(session)
        for case .stop(let tile) in commands { watches.removeValue(forKey: tile)?.cancel() }
        for (tile, engine) in engines.engines where watches[tile] == nil { watch(tile, engine) }
        guard !session.isOpen else { return }
        watches.values.forEach { $0.cancel() }
        watches = [:]
        let kept = commands.compactMap { command -> Int? in
            if case .keep(let tile) = command { return tile }
            return nil
        }.first
        ended(kept.flatMap { session.tile($0) }.flatMap { channel($0.channel) })
    }

    private func watch(_ tile: Int, _ engine: RoutedEngine) {
        watches[tile] = Task { [weak self] in
            for await state in await engine.states() {
                guard !Task.isCancelled else { return }
                self?.stateChanged(tile, state)
            }
        }
    }

    private func stateChanged(_ tile: Int, _ state: PlaybackState) {
        guard let current = session.tile(tile), session.isOpen else { return }
        switch state {
        case .failed(let reason):
            if case .failed = statuses[tile] { return }
            let message = MultiViewFailureText.message(
                reason, sharesSource: session.othersShare(source: current.channel.sourceID, besides: tile),
                source: sourceName(current.channel.sourceID), device: dependencies.device)
            statuses[tile] = .failed(message)
            Task { await apply(session.failed(tile, reason)) }
        case .playing, .paused, .ended:
            if case .failed = statuses[tile] { return }
            statuses[tile] = .playing
        case .loading, .buffering, .reconnecting:
            if case .failed = statuses[tile] { return }
            statuses[tile] = .waiting
        case .idle:
            break
        }
    }

    // MARK: Hint and badge

    private func showHint() {
        hintShown = true
        hintTimer?.cancel()
        hintTimer = timer { $0.hintShown = false }
    }

    private func showBadge() {
        badgeShown = true
        badgeTimer?.cancel()
        badgeTimer = timer { $0.badgeShown = false }
    }

    private func timer(_ done: @escaping @MainActor (MultiViewModel) -> Void) -> Task<Void, Never> {
        let sleep = dependencies.sleep
        let delay = dependencies.showFor
        return Task { [weak self] in
            do { try await sleep(delay) } catch { return }
            guard let self, !Task.isCancelled else { return }
            done(self)
        }
    }
}

extension MultiViewCap {
    /// This device's tile limit (multi-view/add-more-tiles-up-to-the-limit).
    /// `UITESTING_MULTIVIEW_CAP` sets it in a Debug build.
    static var current: MultiViewCap {
        #if DEBUG
            if let limit = ProcessInfo.processInfo.environment["UITESTING_MULTIVIEW_CAP"].flatMap(Int.init) {
                return MultiViewCap(limit: limit)
            }
        #endif
        #if os(macOS)
            #if arch(arm64)
                return MultiViewCap(device: .mac(appleSilicon: true))
            #else
                return MultiViewCap(device: .mac(appleSilicon: false))
            #endif
        #else
            return MultiViewCap(device: .appleTV(model: hardwareModel))
        #endif
    }

    /// "AppleTV5,3" and the like; the simulator reports the model it runs as.
    private static var hardwareModel: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulated }
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var bytes = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &bytes, &size, nil, 0)
        return String(decoding: bytes.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)), as: UTF8.self)
    }
}
