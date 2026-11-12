import Foundation

extension GuideEngine {
    /// How one guide's load ended.
    enum GuideResult: Sendable, Equatable {
        case loaded
        case failed(GuideError)
        case cancelled
        /// Nothing to load yet, such as a Jellyfin guide before its channels.
        case waiting
    }

    // MARK: Deciding what loads

    /// True when the source has never been looked at, or a turned-on guide
    /// is due. With `onlyMissing`, a guide is due only when it has neither
    /// loaded nor failed, so a reorder retries nothing.
    func needsLoad(_ source: GuideSourceDescriptor, now: Date, onlyMissing: Bool) -> Bool {
        let id = source.sourceID
        if entries[id] == nil { return true }
        return guideList(source).contains { entry in
            guard entry.enabled else { return false }
            if onlyMissing {
                let status = guideStatuses[id]?[entry.reference]
                return loaded[id]?[entry.reference] == nil && (status == nil || status == .pending)
            }
            return isDue(entry, of: id, now: now)
        }
    }

    /// Missing, loaded from another link, or older than `freshness`.
    private func isDue(_ entry: GuideListEntry, of id: UUID, now: Date) -> Bool {
        guard let kept = loaded[id]?[entry.reference] else { return true }
        if let url = entry.url, kept.fingerprint != fingerprint(url) { return true }
        return now.timeIntervalSince(kept.completedAt) > Self.freshness
    }

    /// 64-bit FNV-1a over the link's text, so a cache never keeps the link.
    func fingerprint(_ url: URL) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in url.absoluteString.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    // MARK: A pass over one source

    /// Loads the source's due guides one at a time, top first. A failure is
    /// reported per source once the pass ends with nothing loaded, so one
    /// broken guide among working ones never reads as a failed source.
    func load(_ source: GuideSourceDescriptor, generation: Int, force: Force) async {
        defer { finish() }
        let id = source.sourceID
        let now = configuration.now()
        let due = guideList(source).filter { $0.enabled && (force.includes($0.reference) || isDue($0, of: id, now: now)) }
        for entry in due where loaded[id]?[entry.reference] == nil {
            guideStatuses[id, default: [:]][entry.reference] = .pending
        }
        _ = updateNameMatches(id)
        rebuild(id)
        publish()

        var loadedAny = false
        var firstFailure: GuideError?
        for entry in due {
            guard hub.generation(of: id) == generation, !removed.contains(id) else { return }
            switch await loadGuide(source, entry, generation: generation) {
            case .loaded: loadedAny = true
            case .failed(let error): firstFailure = firstFailure ?? error
            case .cancelled: return
            case .waiting: break
            }
        }
        guard hub.generation(of: id) == generation, !removed.contains(id) else { return }
        if !loadedAny, let firstFailure {
            let quiet = firstFailure == .credentialMissing || firstFailure == .credentialUnreadable
            hub.emit(.failed(sourceID: id, firstFailure), order: source.sortOrder, generation: generation, unlessRepeated: quiet)
        }
    }

    private func loadGuide(_ source: GuideSourceDescriptor, _ entry: GuideListEntry, generation: Int) async -> GuideResult {
        let reference = entry.reference
        guard reference == .provider else {
            guard let url = entry.url else { return failBeforeRequest(source, reference, .credentialMissing) }
            return await fetch(url, for: source, reference, loginURL: false, generation: generation)
        }
        var headers: [String: String] = [:]
        switch source.kind {
        case .m3u, .m3uFile:
            return .waiting
        case .xtream:
            switch readCredential(source.credentialKey) {
            case .failure(let error): return failBeforeRequest(source, reference, error)
            case .success(let login):
                let credentials = XtreamCredentials(server: source.url, username: login.username, password: login.password)
                return await fetch(
                    XtreamClient(credentials: credentials).xmltvURL(), for: source, reference, loginURL: true, generation: generation)
            }
        case .stalker:
            return await loadPortalGuide(source, generation: generation)
        case .jellyfin:
            return await loadJellyfinGuide(source, generation: generation)
        case .channelsDVR:
            if let key = source.credentialKey {
                switch readCredential(key) {
                case .failure(let error): return failBeforeRequest(source, reference, error)
                case .success(let login):
                    guard let basic = HTTPBasicCredential(username: login.username, password: login.password) else {
                        return failBeforeRequest(source, reference, .credentialUnreadable)
                    }
                    headers["Authorization"] = basic.headerValue
                }
            }
            return await fetch(
                ChannelsDVRClient(server: source.url).guideURL(), for: source, reference, loginURL: true, headers: headers,
                generation: generation)
        }
    }

    /// The login under `key`; a key that is nil counts as missing.
    private func readCredential(_ key: String?) -> Result<(username: String, password: String), GuideError> {
        switch key.map(configuration.credential) ?? .missing {
        case .found(let username, let password): .success((username, password))
        case .missing: .failure(.credentialMissing)
        case .unreadable: .failure(.credentialUnreadable)
        }
    }

    private func fetch(
        _ url: URL, for source: GuideSourceDescriptor, _ reference: GuideReference, loginURL: Bool, headers: [String: String] = [:],
        generation: Int
    ) async -> GuideResult {
        let id = source.sourceID
        setStatus(.downloading(bytes: nil), for: id, reference)
        configuration.log("guide load \(id.uuidString) \(reference.storageKey) \(redacted(url))")
        let hub = hub
        let order = source.sortOrder
        let outcome = await fetcher.fetch(
            url, sourceID: id, loginURL: loginURL, headers: headers,
            progress: { [weak self] event in
                hub.emit(event, order: order, generation: generation)
                Task { await self?.progressed(event, id, reference, generation: generation) }
            })
        return await complete(
            source, reference, outcome: outcome, fingerprint: fingerprint(url), generation: generation, from: redacted(url))
    }

    /// Moves a guide's status along while it downloads.
    private func progressed(_ event: GuideProgress, _ id: UUID, _ reference: GuideReference, generation: Int) {
        guard hub.generation(of: id) == generation, case .downloading(_, let received, let expected) = event else { return }
        switch guideStatuses[id]?[reference] {
        case .downloading, .reading: break
        default: return
        }
        let finished = expected.map { received >= $0 && $0 > 0 } ?? false
        guideStatuses[id, default: [:]][reference] = finished ? .reading : .downloading(bytes: received)
        rebuild(id)
        publishStatuses()
    }

    /// The portal's own guide for a Stalker source
    /// (guide-data/find-the-guide-for-each-source). A source whose login is
    /// not on this device reports a missing credential.
    private func loadPortalGuide(_ source: GuideSourceDescriptor, generation: Int) async -> GuideResult {
        let id = source.sourceID
        guard let client = await configuration.stalkerClient(id) else { return failBeforeRequest(source, .provider, .credentialMissing) }
        guard hub.generation(of: id) == generation, !removed.contains(id) else { return .cancelled }
        setStatus(.downloading(bytes: nil), for: id, .provider)
        configuration.log("guide load \(id.uuidString) portal \(client)")
        let fetcher = PortalGuideFetcher(session: configuration.session, limits: configuration.limits)
        let read = await fetcher.fetch(client, names: channelNames(id))
        if read.skipped > 0 { configuration.log("guide \(id.uuidString) skipped \(read.skipped) portal rows") }
        return await complete(source, .provider, outcome: read.outcome, fingerprint: 0, generation: generation, from: "portal \(client)")
    }

    /// A Jellyfin source's guide, asked for by its channels' server ids
    /// (guide-data/guide-from-a-source-that-serves-programmes-directly).
    /// Before its channels arrive the guide waits, and the channel list
    /// queues it again. A failure after a load keeps the guide.
    private func loadJellyfinGuide(_ source: GuideSourceDescriptor, generation: Int) async -> GuideResult {
        let id = source.sourceID
        guard let client = await configuration.jellyfinClient(id) else { return failBeforeRequest(source, .provider, .credentialMissing) }
        guard hub.generation(of: id) == generation, !removed.contains(id) else { return .cancelled }
        guard let list = channels[id] else { return .waiting }
        setStatus(.downloading(bytes: nil), for: id, .provider)
        var seen = Set<String>()
        let ids = list.compactMap(\.epgID).filter { seen.insert($0).inserted }
        configuration.log("guide load \(id.uuidString) jellyfin \(client) \(ids.count) channels")
        let hub = hub
        let order = source.sortOrder
        let names = channelNames(id)
        let read = await JellyfinGuideFetcher.fetch(client, channelIDs: ids, names: names, from: configuration.now()) { done, total in
            hub.emit(.fetching(sourceID: id, batchesDone: done, batchesTotal: total), order: order, generation: generation)
        }
        if read.skipped > 0 { configuration.log("guide \(id.uuidString) skipped \(read.skipped) jellyfin rows") }
        return await complete(
            source, .provider, outcome: read.outcome, fingerprint: 0, generation: generation, from: "jellyfin \(client)")
    }

    /// The source's channel names by guide id, for a guide that has no
    /// channel elements of its own.
    private func channelNames(_ id: UUID) -> [String: String] {
        var names: [String: String] = [:]
        for channel in channels[id] ?? [] {
            guard let key = GuideKey(channel: channel), names[key.epgID] == nil else { continue }
            names[key.epgID] = channel.name
        }
        return names
    }

    /// Applies a finished load. `place` names where it came from, as a log
    /// line may show it.
    private func complete(
        _ source: GuideSourceDescriptor, _ reference: GuideReference, outcome: GuideFetcher.Outcome, fingerprint: UInt64,
        generation: Int, from place: String
    ) async -> GuideResult {
        let id = source.sourceID
        guard hub.generation(of: id) == generation, !removed.contains(id) else { return .cancelled }
        switch outcome {
        case .loaded(let guide):
            let now = configuration.now()
            loaded[id, default: [:]][reference] = LoadedGuide(guide: guide, fingerprint: fingerprint, completedAt: now)
            guideStatuses[id, default: [:]][reference] = .loaded(now)
            _ = updateNameMatches(id)
            rebuild(id)
            publish()
            await reportLoaded(id)
            return .loaded
        case .failed(let error):
            configuration.log("guide failed \(id.uuidString) \(reference.storageKey) \(place) \(error)")
            guideStatuses[id, default: [:]][reference] = .failed(error)
            rebuild(id)
            publish()
            return .failed(error)
        case .cancelled:
            return .cancelled
        }
    }

    /// Records a failure found before any request.
    private func failBeforeRequest(_ source: GuideSourceDescriptor, _ reference: GuideReference, _ error: GuideError) -> GuideResult {
        let id = source.sourceID
        configuration.log("guide failed \(id.uuidString) \(reference.storageKey) \(error)")
        guideStatuses[id, default: [:]][reference] = .failed(error)
        rebuild(id)
        publish()
        return .failed(error)
    }

    private func setStatus(_ status: GuideStatus, for id: UUID, _ reference: GuideReference) {
        guideStatuses[id, default: [:]][reference] = status
        rebuild(id)
        publish()
    }
}
