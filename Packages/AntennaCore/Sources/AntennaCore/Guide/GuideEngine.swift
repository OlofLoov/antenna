import Foundation

/// Downloads, joins and keeps every source's guides, one source at a time in
/// `sortOrder` and each source's guides in the user's order. All work runs
/// off the main actor. Each change publishes a new `GuideIndex` on
/// `indexes`, and each change of a guide's status the rows on `statuses`.
///
/// Before a source's first completed load its channels report `.loading`,
/// `.unavailable` or `.failed`. After one they report `.loaded` or `.noData`
/// and keep doing so through failed refreshes, which are reported only on
/// `progressStream()` and in the statuses. Guides live in memory only. A
/// guide's parse is kept while the process runs, so a reorder or a guide
/// turned back on needs no download.
public actor GuideEngine {
    public struct Configuration: Sendable {
        public var session: URLSession
        /// Holds downloads in progress. Emptied when the engine starts.
        public var directory: URL
        public var limits: GuideLimits
        /// The app's sources as they are now.
        public var sources: @Sendable () async -> [GuideSourceDescriptor]
        /// Reads a login by its Keychain key.
        public var credential: @Sendable (String) -> GuideCredentialLookup
        /// The whole link of a guide the user added, from the Keychain, by
        /// source id and link id. Nil when this device does not have it.
        public var addedLink: @Sendable (UUID, String) -> URL?
        /// Receives only redacted links, source ids and error cases.
        public var log: @Sendable (String) -> Void
        public var now: @Sendable () -> Date
        public var uptime: @Sendable () -> Duration
        public var chunkSize: Int
        /// The shared client of a Stalker source, for its portal guide. Nil
        /// when the source's login is not on this device.
        public var stalkerClient: @Sendable (UUID) async -> StalkerClient?
        /// The client of a Jellyfin source, for its guide. Nil when the
        /// source's login is not on this device.
        public var jellyfinClient: @Sendable (UUID) async -> JellyfinClient?

        private static let processStart = ContinuousClock.now

        /// Time since the first engine was configured.
        public static func processUptime() -> Duration {
            processStart.duration(to: .now)
        }

        public init(
            session: URLSession,
            directory: URL,
            limits: GuideLimits = .platform,
            sources: @escaping @Sendable () async -> [GuideSourceDescriptor],
            credential: @escaping @Sendable (String) -> GuideCredentialLookup,
            addedLink: @escaping @Sendable (UUID, String) -> URL? = { _, _ in nil },
            log: @escaping @Sendable (String) -> Void,
            now: @escaping @Sendable () -> Date = { .now },
            uptime: @escaping @Sendable () -> Duration = Configuration.processUptime,
            chunkSize: Int = 65_536,
            stalkerClient: @escaping @Sendable (UUID) async -> StalkerClient? = { _ in nil },
            jellyfinClient: @escaping @Sendable (UUID) async -> JellyfinClient? = { _ in nil }
        ) {
            self.session = session
            self.directory = directory
            self.limits = limits
            self.sources = sources
            self.credential = credential
            self.addedLink = addedLink
            self.log = log
            self.now = now
            self.uptime = uptime
            self.chunkSize = chunkSize
            self.stalkerClient = stalkerClient
            self.jellyfinClient = jellyfinClient
        }
    }

    /// Which guides a pass loads whatever their age.
    enum Force: Sendable, Equatable {
        case none
        case all
        case only(Set<GuideReference>)

        func adding(_ other: Force) -> Force {
            switch (self, other) {
            case (.all, _), (_, .all): .all
            case (.none, let other), (let other, .none): other
            case (.only(let left), .only(let right)): .only(left.union(right))
            }
        }

        func includes(_ reference: GuideReference) -> Bool {
            switch self {
            case .none: false
            case .all: true
            case .only(let set): set.contains(reference)
            }
        }
    }

    /// A guide older than this is downloaded again.
    public static let freshness: TimeInterval = 12 * 3600

    /// A parse kept for one guide of a source. `fingerprint` hashes the link
    /// it came from, so a changed link loads again.
    struct LoadedGuide: Sendable {
        var guide: SourceGuide
        var fingerprint: UInt64
        var completedAt: Date
    }

    let configuration: Configuration
    let fetcher: GuideFetcher
    let hub = GuideProgressHub()
    private let indexContinuation: AsyncStream<GuideIndex>.Continuation
    private let statusContinuation: AsyncStream<[UUID: GuideSourceStatus]>.Continuation
    /// Channel lists from `update(channels:)`, applied in the order they came.
    private let channelInbox: AsyncStream<[Channel]>.Continuation

    /// Every published index, newest only, for one consumer.
    public nonisolated let indexes: AsyncStream<GuideIndex>
    /// Every source's guide rows, newest only, for one consumer.
    public nonisolated let statuses: AsyncStream<[UUID: GuideSourceStatus]>
    public private(set) var index = GuideIndex()
    public internal(set) var sourceStatuses: [UUID: GuideSourceStatus] = [:]

    var entries: [UUID: GuideIndex.SourceEntry] = [:]
    var descriptors: [UUID: GuideSourceDescriptor] = [:]
    var playlistLinks: [UUID: [URL]] = [:]
    var channels: [UUID: [Channel]] = [:]
    var loaded: [UUID: [GuideReference: LoadedGuide]] = [:]
    var guideStatuses: [UUID: [GuideReference: GuideStatus]] = [:]
    /// Matches by name per source and channel id, worked out from the loaded guides.
    var nameMatches: [UUID: [String: String]] = [:]
    var removed: Set<UUID> = []
    /// Sources an explicit refresh restarted; they stay ahead of the queue.
    private var restarted: Set<UUID> = []
    /// What the next pass of a queued source loads whatever its age.
    private var forced: [UUID: Force] = [:]
    /// Bumped each time counts are computed, so only the newest are sent.
    var summaryTokens: [UUID: Int] = [:]
    private var queue: [UUID] = []
    private var running: (sourceID: UUID, task: Task<Void, Never>)?

    public init(_ configuration: Configuration) {
        self.configuration = configuration
        fetcher = GuideFetcher(
            session: configuration.session, limits: configuration.limits, directory: configuration.directory,
            uptime: configuration.uptime, chunkSize: configuration.chunkSize)
        (indexes, indexContinuation) = AsyncStream.makeStream(of: GuideIndex.self, bufferingPolicy: .bufferingNewest(1))
        (statuses, statusContinuation) = AsyncStream.makeStream(
            of: [UUID: GuideSourceStatus].self, bufferingPolicy: .bufferingNewest(1))
        do {
            if FileManager.default.fileExists(atPath: configuration.directory.path()) {
                try FileManager.default.removeItem(at: configuration.directory)
            }
            try FileManager.default.createDirectory(at: configuration.directory, withIntermediateDirectories: true)
        } catch {
            configuration.log("guide directory could not be reset")
        }
        let (lists, inbox) = AsyncStream.makeStream(of: [Channel].self)
        channelInbox = inbox
        Task { [weak self] in
            for await list in lists {
                await self?.apply(channels: list)
            }
        }
    }

    /// A stream of its own for each caller. It first hears the latest event
    /// of each source, then every event as it happens.
    public nonisolated func progressStream() -> AsyncStream<GuideProgress> {
        hub.stream()
    }

    /// Queues every source with a turned-on guide that is missing, whose
    /// link changed, or that completed more than 12 hours before `now`. A
    /// source already queued or loading is left alone.
    public func refreshIfStale(now: Date) async {
        let list = await configuration.sources()
        apply(list)
        for source in list.sorted(by: { $0.sortOrder < $1.sortOrder }) where !removed.contains(source.sourceID) {
            if needsLoad(source, now: now, onlyMissing: false) { enqueue(source.sourceID) }
        }
        pump()
    }

    /// Downloads every turned-on guide of the source whatever its age. A
    /// load already running for it is cancelled, quietly, and starts again.
    public func refresh(sourceID: UUID) async {
        await restart(sourceID, force: .all)
    }

    /// Downloads one guide of the source whatever its age, as Retry now does
    /// (guide-sources-and-channel-mapping/one-broken-guide-does-not-break-the-others).
    public func refresh(sourceID: UUID, guide: GuideReference) async {
        await restart(sourceID, force: .only([guide]))
    }

    /// Reads the sources again after a source's guide settings changed, here
    /// or on another device. Applies the order, flags and matches to the
    /// index at once, without downloading, then queues turned-on guides that
    /// have not loaded (guide-sources-and-channel-mapping/choose-which-guide-wins).
    public func settingsChanged() async {
        let list = await configuration.sources()
        apply(list)
        for source in list where !removed.contains(source.sourceID) {
            _ = updateNameMatches(source.sourceID)
            rebuild(source.sourceID)
        }
        publish()
        for source in list.sorted(by: { $0.sortOrder < $1.sortOrder }) where !removed.contains(source.sourceID) {
            if needsLoad(source, now: configuration.now(), onlyMissing: true) { enqueue(source.sourceID) }
        }
        pump()
    }

    private func restart(_ sourceID: UUID, force: Force) async {
        apply(await configuration.sources())
        guard descriptors[sourceID] != nil, !removed.contains(sourceID) else { return }
        forced[sourceID] = (forced[sourceID] ?? .none).adding(force)
        if let running, running.sourceID == sourceID {
            _ = hub.bump(sourceID)
            running.task.cancel()
            queue.removeAll { $0 == sourceID }
            queue.insert(sourceID, at: 0)
            restarted.insert(sourceID)
        } else {
            enqueue(sourceID)
        }
        pump()
    }

    /// Replaces the channel list of each source the channels are tagged with,
    /// then reports fresh counts for those with a completed guide. Returns at
    /// once; the lists are applied on the engine in the order they were given.
    public nonisolated func update(channels: [Channel]) {
        channelInbox.yield(channels)
    }

    private func apply(channels newChannels: [Channel]) async {
        var groups: [UUID: [Channel]] = [:]
        if let id = newChannels.first?.sourceID, newChannels.allSatisfy({ $0.sourceID == id }) {
            groups[id] = newChannels
        } else {
            for channel in newChannels {
                guard let id = channel.sourceID else { continue }
                groups[id, default: []].append(channel)
            }
        }
        for (id, list) in groups where !removed.contains(id) {
            channels[id] = list
            if updateNameMatches(id) {
                rebuild(id)
                publish()
            }
            if entries[id]?.hasGuide == true {
                await reportLoaded(id)
            }
            let waitingProvider = descriptors[id].map { source in
                source.kind == .jellyfin && loaded[id]?[.provider] == nil
                    && guideList(source).contains { $0.reference == .provider && $0.enabled }
            }
            if waitingProvider == true, !list.isEmpty {
                // A Jellyfin guide waits for the channel list it asks for.
                enqueue(id)
                pump()
            }
        }
    }

    /// The guide links an M3U playlist names, used at its next load.
    public func register(epgURLs: [URL], for sourceID: UUID) {
        guard !removed.contains(sourceID) else { return }
        playlistLinks[sourceID] = epgURLs
    }

    /// Stops any load for the source and forgets its guides. Its channels
    /// report `.unavailable` and no event about it is sent again.
    public func remove(sourceID: UUID) {
        removed.insert(sourceID)
        hub.forget(sourceID)
        queue.removeAll { $0 == sourceID }
        restarted.remove(sourceID)
        forced[sourceID] = nil
        if let running, running.sourceID == sourceID { running.task.cancel() }
        descriptors[sourceID] = nil
        playlistLinks[sourceID] = nil
        channels[sourceID] = nil
        loaded[sourceID] = nil
        guideStatuses[sourceID] = nil
        nameMatches[sourceID] = nil
        sourceStatuses[sourceID] = nil
        entries[sourceID] = GuideIndex.SourceEntry(state: .unavailable)
        publish()
    }

    /// Waits until no load is running or queued.
    func idle() async {
        while let running { await running.task.value }
    }

    // MARK: Queue

    /// Takes the app's current sources. A removed id that is listed again
    /// counts as a new source.
    private func apply(_ list: [GuideSourceDescriptor]) {
        for source in list {
            removed.remove(source.sourceID)
            descriptors[source.sourceID] = source
        }
    }

    /// Inserts by `sortOrder`, behind any source an explicit refresh restarted.
    private func enqueue(_ id: UUID) {
        guard running?.sourceID != id, !queue.contains(id) else { return }
        let order = descriptors[id]?.sortOrder ?? 0
        let position = queue.firstIndex { !restarted.contains($0) && (descriptors[$0]?.sortOrder ?? 0) > order } ?? queue.endIndex
        queue.insert(id, at: position)
    }

    private func pump() {
        guard running == nil, !queue.isEmpty else { return }
        let id = queue.removeFirst()
        restarted.remove(id)
        let force = forced.removeValue(forKey: id) ?? .none
        guard let source = descriptors[id], !removed.contains(id) else {
            pump()
            return
        }
        let generation = hub.bump(id)
        running = (id, Task { await self.load(source, generation: generation, force: force) })
    }

    func finish() {
        running = nil
        pump()
    }

    func publish() {
        index = GuideIndex(sources: entries)
        indexContinuation.yield(index)
        statusContinuation.yield(sourceStatuses)
    }

    /// Publishes the statuses alone, for progress that leaves the index as it is.
    func publishStatuses() {
        statusContinuation.yield(sourceStatuses)
    }
}
