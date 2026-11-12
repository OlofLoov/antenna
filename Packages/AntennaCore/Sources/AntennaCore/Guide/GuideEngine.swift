import Foundation

/// What the guide needs to know about a source, mapped by the app from its
/// stored record. `url` may hold a login (an M3U link with a password in its
/// query), so it is never logged, persisted or used in a file name.
public struct GuideSourceDescriptor: Sendable, Equatable {
    public var sourceID: UUID
    public var kind: SourceKind
    public var url: URL
    public var epgURL: URL?
    public var credentialKey: String?
    public var sortOrder: Int

    public init(sourceID: UUID, kind: SourceKind, url: URL, epgURL: URL? = nil, credentialKey: String? = nil, sortOrder: Int = 0) {
        self.sourceID = sourceID
        self.kind = kind
        self.url = url
        self.epgURL = epgURL
        self.credentialKey = credentialKey
        self.sortOrder = sortOrder
    }
}

/// The result of reading a source's login, so a login that has not synced yet
/// can be told apart from one the Keychain cannot read.
public enum GuideCredentialLookup: Sendable {
    case found(username: String, password: String)
    case missing
    case unreadable
}

/// Downloads, joins and keeps every source's guide, one source at a time in
/// `sortOrder`. All work runs off the main actor. Each change publishes a
/// new `GuideIndex` on `indexes`.
///
/// Before a source's first completed load its channels report `.loading`,
/// `.unavailable` or `.failed`. After one they report `.loaded` or `.noData`
/// and keep doing so through failed refreshes, which are reported only on
/// `progressStream()`. Guides live in memory only.
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
            self.log = log
            self.now = now
            self.uptime = uptime
            self.chunkSize = chunkSize
            self.stalkerClient = stalkerClient
            self.jellyfinClient = jellyfinClient
        }
    }

    /// A guide older than this is downloaded again.
    public static let freshness: TimeInterval = 12 * 3600

    private let configuration: Configuration
    private let fetcher: GuideFetcher
    private let hub = GuideProgressHub()
    private let indexContinuation: AsyncStream<GuideIndex>.Continuation
    /// Channel lists from `update(channels:)`, applied in the order they came.
    private let channelInbox: AsyncStream<[Channel]>.Continuation

    /// Every published index, newest only, for one consumer.
    public nonisolated let indexes: AsyncStream<GuideIndex>
    public private(set) var index = GuideIndex()

    private var entries: [UUID: GuideIndex.SourceEntry] = [:]
    private var descriptors: [UUID: GuideSourceDescriptor] = [:]
    private var playlistLinks: [UUID: [URL]] = [:]
    private var channels: [UUID: [Channel]] = [:]
    private var completedAt: [UUID: Date] = [:]
    private var removed: Set<UUID> = []
    /// Sources an explicit refresh restarted; they stay ahead of the queue.
    private var restarted: Set<UUID> = []
    /// Bumped each time counts are computed, so only the newest are sent.
    private var summaryTokens: [UUID: Int] = [:]
    private var queue: [UUID] = []
    private var running: (sourceID: UUID, task: Task<Void, Never>)?

    public init(_ configuration: Configuration) {
        self.configuration = configuration
        fetcher = GuideFetcher(
            session: configuration.session, limits: configuration.limits, directory: configuration.directory,
            uptime: configuration.uptime, chunkSize: configuration.chunkSize)
        (indexes, indexContinuation) = AsyncStream.makeStream(of: GuideIndex.self, bufferingPolicy: .bufferingNewest(1))
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

    /// Queues every source whose guide is missing, or completed more than 12
    /// hours before `now`. A source already queued or loading is left alone.
    public func refreshIfStale(now: Date) async {
        let list = await configuration.sources()
        apply(list)
        for source in list.sorted(by: { $0.sortOrder < $1.sortOrder }) where !removed.contains(source.sourceID) {
            let id = source.sourceID
            let fresh = entries[id]?.guide != nil && (completedAt[id].map { now.timeIntervalSince($0) <= Self.freshness } ?? false)
            if !fresh { enqueue(id) }
        }
        pump()
    }

    /// Downloads the source's guide whatever its age. A load already running
    /// for it is cancelled, quietly, and starts again.
    public func refresh(sourceID: UUID) async {
        apply(await configuration.sources())
        guard descriptors[sourceID] != nil, !removed.contains(sourceID) else { return }
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
            if entries[id]?.guide != nil {
                await reportLoaded(id)
            } else if let source = descriptors[id], source.kind == .jellyfin, source.epgURL == nil, !list.isEmpty {
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

    /// Stops any load for the source and forgets its guide. Its channels
    /// report `.unavailable` and no event about it is sent again.
    public func remove(sourceID: UUID) {
        removed.insert(sourceID)
        hub.forget(sourceID)
        queue.removeAll { $0 == sourceID }
        restarted.remove(sourceID)
        if let running, running.sourceID == sourceID { running.task.cancel() }
        descriptors[sourceID] = nil
        playlistLinks[sourceID] = nil
        channels[sourceID] = nil
        completedAt[sourceID] = nil
        entries[sourceID] = GuideIndex.SourceEntry(guide: nil, state: .unavailable)
        publish()
    }

    /// Waits until no load is running or queued.
    func idle() async {
        while let running { await running.task.value }
    }

    // MARK: Loading

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
        guard let source = descriptors[id], !removed.contains(id) else {
            pump()
            return
        }
        let generation = hub.bump(id)
        running = (id, Task { await self.load(source, generation: generation) })
    }

    private func finish() {
        running = nil
        pump()
    }

    private func load(_ source: GuideSourceDescriptor, generation: Int) async {
        defer { finish() }
        let id = source.sourceID
        var credential: (username: String, password: String)?
        var headers: [String: String] = [:]
        if source.epgURL == nil {
            switch source.kind {
            case .m3u, .m3uFile:
                guard playlistLinks[id] != nil else { return }
            case .xtream:
                guard let found = readCredential(source, key: source.credentialKey) else { return }
                credential = found
            case .stalker:
                await loadPortalGuide(source, generation: generation)
                return
            case .jellyfin:
                await loadJellyfinGuide(source, generation: generation)
                return
            case .channelsDVR:
                if let key = source.credentialKey {
                    guard let found = readCredential(source, key: key) else { return }
                    guard let basic = HTTPBasicCredential(username: found.username, password: found.password) else {
                        failBeforeRequest(source, .credentialUnreadable, state: .failed(.credentialUnreadable))
                        return
                    }
                    headers["Authorization"] = basic.headerValue
                }
            }
        }
        guard
            let url = GuideURLResolver.resolve(
                kind: source.kind, url: source.url, epgURL: source.epgURL, playlistEPGURLs: playlistLinks[id] ?? [],
                credential: credential)
        else {
            if entries[id]?.guide != nil { hub.forget(id) }
            completedAt[id] = nil
            entries[id] = GuideIndex.SourceEntry(guide: nil, state: .unavailable)
            publish()
            return
        }
        if entries[id]?.guide == nil {
            entries[id] = GuideIndex.SourceEntry(guide: nil, state: .loading)
            publish()
        }

        configuration.log("guide load \(id.uuidString) \(redacted(url))")
        let hub = hub
        let order = source.sortOrder
        let outcome = await fetcher.fetch(
            url, sourceID: id, loginURL: source.epgURL == nil && (source.kind == .xtream || source.kind == .channelsDVR), headers: headers,
            progress: { hub.emit($0, order: order, generation: generation) })
        await complete(source, outcome: outcome, generation: generation, from: redacted(url))
    }

    /// The portal's own guide for a Stalker source without a guide link
    /// (guide-data/find-the-guide-for-each-source). A source whose login is
    /// not on this device reports a missing credential.
    private func loadPortalGuide(_ source: GuideSourceDescriptor, generation: Int) async {
        let id = source.sourceID
        guard let client = await configuration.stalkerClient(id) else {
            failBeforeRequest(source, .credentialMissing, state: .unavailable)
            return
        }
        guard hub.generation(of: id) == generation, !removed.contains(id) else { return }
        if entries[id]?.guide == nil {
            entries[id] = GuideIndex.SourceEntry(guide: nil, state: .loading)
            publish()
        }
        configuration.log("guide load \(id.uuidString) portal \(client)")
        let read = await PortalGuideFetcher(session: configuration.session, limits: configuration.limits).fetch(client)
        if read.skipped > 0 { configuration.log("guide \(id.uuidString) skipped \(read.skipped) portal rows") }
        await complete(source, outcome: read.outcome, generation: generation, from: "portal \(client)")
    }

    /// Applies a finished download. `place` names where it came from, as a
    /// log line may show it.
    private func complete(_ source: GuideSourceDescriptor, outcome: GuideFetcher.Outcome, generation: Int, from place: String) async {
        let id = source.sourceID
        let order = source.sortOrder
        guard hub.generation(of: id) == generation, !removed.contains(id) else { return }

        switch outcome {
        case .loaded(let guide):
            entries[id] = GuideIndex.SourceEntry(guide: guide, state: .loading)
            completedAt[id] = configuration.now()
            publish()
            await reportLoaded(id)
        case .failed(let error):
            configuration.log("guide failed \(id.uuidString) \(place) \(error)")
            hub.emit(.failed(sourceID: id, error), order: order, generation: generation)
            if entries[id]?.guide == nil {
                entries[id] = GuideIndex.SourceEntry(guide: nil, state: .failed(error))
                publish()
            }
        case .cancelled:
            break
        }
    }

    /// Reports a failure found before any request. Sent once while it lasts.
    fileprivate func failBeforeRequest(_ source: GuideSourceDescriptor, _ error: GuideError, state: GuideLoadingState) {
        let id = source.sourceID
        configuration.log("guide failed \(id.uuidString) \(error)")
        hub.emit(.failed(sourceID: id, error), order: source.sortOrder, unlessRepeated: true)
        if entries[id]?.guide == nil {
            entries[id] = GuideIndex.SourceEntry(guide: nil, state: state)
            publish()
        }
    }

    /// Sends `.loaded` with counts from the source's channels. The counting
    /// runs off the actor.
    private func reportLoaded(_ id: UUID) async {
        guard let guide = entries[id]?.guide else { return }
        let list = channels[id] ?? []
        let token = (summaryTokens[id] ?? 0) + 1
        summaryTokens[id] = token
        let summary = await Self.summarize(guide, channels: list, now: configuration.now())
        guard !removed.contains(id), summaryTokens[id] == token else { return }
        let order = descriptors[id]?.sortOrder ?? 0
        hub.emit(
            .loaded(
                sourceID: id, channelsWithGuide: summary.channelsWithGuide, channelsTotal: summary.channelsTotal,
                days: summary.days, unmatched: summary.unmatched),
            order: order)
    }

    @concurrent
    private static func summarize(_ guide: SourceGuide, channels: [Channel], now: Date) async -> SourceGuide.Summary {
        guide.summary(channels: channels, now: now)
    }

    private func publish() {
        index = GuideIndex(sources: entries)
        indexContinuation.yield(index)
    }
}

extension GuideEngine {
    /// A Jellyfin source's guide, asked for by its channels' server ids
    /// (guide-data/guide-from-a-source-that-serves-programmes-directly).
    /// Before its channels arrive the source stays loading, and the channel
    /// list queues it again. A failure after a load keeps the guide.
    private func loadJellyfinGuide(_ source: GuideSourceDescriptor, generation: Int) async {
        let id = source.sourceID
        guard let client = await configuration.jellyfinClient(id) else {
            failBeforeRequest(source, .credentialMissing, state: .unavailable)
            return
        }
        guard hub.generation(of: id) == generation, !removed.contains(id) else { return }
        if entries[id]?.guide == nil {
            entries[id] = GuideIndex.SourceEntry(guide: nil, state: .loading)
            publish()
        }
        guard let list = channels[id] else { return }
        var seen = Set<String>()
        let ids = list.compactMap(\.epgID).filter { seen.insert($0).inserted }
        configuration.log("guide load \(id.uuidString) jellyfin \(client) \(ids.count) channels")
        let hub = hub
        let order = source.sortOrder
        let read = await JellyfinGuideFetcher.fetch(client, channelIDs: ids, from: configuration.now()) { done, total in
            hub.emit(.fetching(sourceID: id, batchesDone: done, batchesTotal: total), order: order, generation: generation)
        }
        if read.skipped > 0 { configuration.log("guide \(id.uuidString) skipped \(read.skipped) jellyfin rows") }
        await complete(source, outcome: read.outcome, generation: generation, from: "jellyfin \(client)")
    }

    /// The login under `key`, or nil after reporting it missing or unreadable.
    /// No request is made in either case.
    fileprivate func readCredential(_ source: GuideSourceDescriptor, key: String?) -> (username: String, password: String)? {
        switch key.map(configuration.credential) ?? .missing {
        case .found(let username, let password):
            return (username, password)
        case .missing:
            failBeforeRequest(source, .credentialMissing, state: .unavailable)
            return nil
        case .unreadable:
            failBeforeRequest(source, .credentialUnreadable, state: .failed(.credentialUnreadable))
            return nil
        }
    }
}
