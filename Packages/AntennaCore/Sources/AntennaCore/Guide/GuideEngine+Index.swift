import Foundation

extension GuideEngine {
    /// The source's guides in the user's order, with the Keychain links of
    /// added guides this device has.
    func guideList(_ source: GuideSourceDescriptor) -> [GuideListEntry] {
        let id = source.sourceID
        var added: [String: URL] = [:]
        for (linkID, link) in source.settings.activeLinks where link.plain == nil {
            added[linkID] = configuration.addedLink(id, linkID)
        }
        return GuideList.resolve(
            kind: source.kind, savedURL: source.epgURL, playlistLinks: playlistLinks[id] ?? [], settings: source.settings,
            addedLinks: added, panelGuide: GuideURLResolver.panelGuide(kind: source.kind, url: source.url))
    }

    /// The links of the source's guides this device knows, for the add
    /// form's duplicate check. Holds logins: never log or show them.
    public func guideLinks(sourceID: UUID) -> [URL] {
        guard let source = descriptors[sourceID] else { return [] }
        return guideList(source).compactMap(\.url)
    }

    /// True for a playlist whose header links have not arrived yet.
    private func waitsForPlaylist(_ source: GuideSourceDescriptor) -> Bool {
        (source.kind == .m3u || source.kind == .m3uFile) && playlistLinks[source.sourceID] == nil
    }

    /// Works out the source's index entry and guide rows from its turned-on
    /// guides, their statuses and its matches. Publishes nothing.
    func rebuild(_ id: UUID) {
        guard let source = descriptors[id], !removed.contains(id) else { return }
        let list = guideList(source)
        let enabled = list.filter(\.enabled)
        let kept = loaded[id] ?? [:]
        let layers = enabled.compactMap { entry in
            kept[entry.reference].map { GuideIndex.Layer(reference: entry.reference, guide: $0.guide) }
        }
        if entries[id]?.hasGuide == true, layers.isEmpty { hub.forget(id) }
        entries[id] = GuideIndex.SourceEntry(layers: layers, state: state(of: source, enabled: enabled), matches: matches(of: source))

        let rows = list.map { entry in
            GuideRow(
                reference: entry.reference, enabled: entry.enabled,
                status: entry.enabled ? (guideStatuses[id]?[entry.reference] ?? .pending) : .off,
                address: entry.url.map(redacted), hasGuide: kept[entry.reference] != nil)
        }
        sourceStatuses[id] = GuideSourceStatus(rows: rows, playlistLoading: waitsForPlaylist(source))
    }

    /// Hand-picked entries, then matches by name for channels the user left alone.
    private func matches(of source: GuideSourceDescriptor) -> [String: GuideMatch] {
        var result: [String: GuideMatch] = [:]
        for (channelID, entryID) in nameMatches[source.sourceID] ?? [:] {
            result[channelID] = GuideMatch(entryID: entryID, origin: .name)
        }
        for (channelID, entryID) in source.settings.activeMatches {
            guard let entryID else {
                result[channelID] = nil
                continue
            }
            let match = GuideMatch(entryID: entryID, origin: .user)
            result[channelID] = match.entryID.isEmpty ? nil : match
        }
        return result
    }

    /// What the source's channels report while no guide has loaded: loading
    /// while a guide is due or the playlist has not named its links, the
    /// first failure once every guide failed, and unavailable without a guide
    /// or while a login is missing.
    private func state(of source: GuideSourceDescriptor, enabled: [GuideListEntry]) -> GuideLoadingState {
        let id = source.sourceID
        if enabled.isEmpty { return waitsForPlaylist(source) ? .loading : .unavailable }
        let statuses = enabled.map { guideStatuses[id]?[$0.reference] }
        if statuses.contains(where: { $0 == nil || $0?.isInFlight == true }) { return .loading }
        for case .failed(let error) in statuses {
            return error == .credentialMissing ? .unavailable : .failed(error)
        }
        return waitsForPlaylist(source) ? .loading : .unavailable
    }

    /// Works out the source's matches by name again. True when they changed.
    func updateNameMatches(_ id: UUID) -> Bool {
        guard let source = descriptors[id] else { return false }
        let enabled = Set(guideList(source).filter(\.enabled).map(\.reference))
        let guides = guideList(source).compactMap { entry in
            enabled.contains(entry.reference) ? loaded[id]?[entry.reference]?.guide : nil
        }
        let found = GuideNameMatcher.matches(
            channels: channels[id] ?? [], guides: guides, excluding: Set(source.settings.activeMatches.keys))
        guard found != (nameMatches[id] ?? [:]) else { return false }
        nameMatches[id] = found.isEmpty ? nil : found
        return true
    }

    /// Sends `.loaded` with counts from the source's channels over every
    /// turned-on guide. The counting runs off the actor.
    func reportLoaded(_ id: UUID) async {
        guard entries[id]?.hasGuide == true else { return }
        let list = channels[id] ?? []
        let token = (summaryTokens[id] ?? 0) + 1
        summaryTokens[id] = token
        let summary = await Self.summarize(index, sourceID: id, channels: list, now: configuration.now())
        guard !removed.contains(id), summaryTokens[id] == token else { return }
        let order = descriptors[id]?.sortOrder ?? 0
        hub.emit(
            .loaded(
                sourceID: id, channelsWithGuide: summary.channelsWithGuide, channelsTotal: summary.channelsTotal,
                days: summary.days, unmatched: summary.unmatched),
            order: order)
    }

    @concurrent
    private static func summarize(_ index: GuideIndex, sourceID: UUID, channels: [Channel], now: Date) async -> SourceGuide.Summary {
        index.summary(sourceID: sourceID, channels: channels, now: now)
    }
}
