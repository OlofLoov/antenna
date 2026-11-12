import AntennaCore
import Foundation
import SwiftData

/// The Guide sources screen's state and actions for one source
/// (guide-sources-and-channel-mapping capability): its guide rows, the
/// channels without a guide with their reasons, the channels matched by
/// name, and the changes the user makes, saved to the synced settings.
@MainActor @Observable
final class GuideSourcesModel {
    /// A channel without a current programme and why.
    struct Missing: Identifiable, Equatable {
        var channel: Channel
        var reason: GuideReason
        var id: String { channel.id }
    }

    /// What the channel column shows, the first that holds.
    enum Column: Equatable {
        case noChannels
        case sharedReason(GuideReason, count: Int)
        case waiting
        case everyChannel
        case rows
    }

    let sourceID: UUID
    var source: String
    var kind: SourceKind
    var filter = ""
    /// Rows of a reason that covers the whole playlist show after "Show n channels".
    var expanded = false
    var selected: String?
    var error: String?
    @ObservationIgnored let store: AppGuideStore?
    @ObservationIgnored let context: ModelContext
    @ObservationIgnored let credentials: any CredentialStoring
    @ObservationIgnored var now: () -> Date
    @ObservationIgnored private var cachedSearch: (key: Int, search: GuideEntrySearch)?

    init(
        sourceID: UUID, source: String, kind: SourceKind, store: AppGuideStore?, context: ModelContext,
        credentials: any CredentialStoring = CredentialStore(), now: @escaping () -> Date = { .now }
    ) {
        self.sourceID = sourceID
        self.source = source
        self.kind = kind
        self.store = store
        self.context = context
        self.credentials = credentials
        self.now = now
    }

    // MARK: Reading

    var status: GuideSourceStatus { store?.statuses[sourceID] ?? GuideSourceStatus() }
    var index: GuideIndex { store?.index ?? GuideIndex() }
    var channels: [Channel] { store?.channels[sourceID] ?? [] }
    var settings: GuideSettings { GuideSettingsStore.settings(for: sourceID, in: context) }

    var text: GuideSourcesText {
        #if os(tvOS)
            GuideSourcesText(television: true)
        #else
            GuideSourcesText()
        #endif
    }

    /// The row's first line.
    func name(_ reference: GuideReference) -> String {
        text.name(reference, link: link(reference))
    }

    func link(_ reference: GuideReference) -> GuideSettings.Link? {
        guard case .added(let id) = reference else { return nil }
        return settings.links[id]
    }

    func statusLine(_ row: GuideRow) -> GuideSourcesText.Line {
        let coverage = index.coverage(of: row.reference, sourceID: sourceID, channels: channels, now: now())
        return text.status(row, coverage: coverage, channels: channels.count, source: source)
    }

    /// Every channel without a current programme, in the list's order.
    var missing: [Missing] {
        let status = status
        let index = index
        let now = now()
        return channels.compactMap { channel in
            let reason = GuideDiagnosis.reason(for: channel, rows: status, index: index, now: now)
            if case .hasGuide = reason { return nil }
            return Missing(channel: channel, reason: reason)
        }
    }

    /// Channels matched by name, in the list's order.
    var named: [Channel] {
        let index = index
        return channels.filter { index.match(for: $0)?.origin == .name }
    }

    var column: Column {
        if channels.isEmpty { return .noChannels }
        if let shared = GuideDiagnosis.sourceReason(status) {
            if shared.coversPlaylist { return .sharedReason(shared, count: channels.count) }
            if case .notDownloaded = shared { return .waiting }
        }
        return missing.isEmpty ? .everyChannel : .rows
    }

    /// The missing channels the filter lets through, by name or number.
    func filtered(_ list: [Missing]) -> [Missing] {
        let filter = ChannelFilter(filter)
        return list.filter { filter.matches(name: $0.channel.name, number: $0.channel.number) }
    }

    func channel(_ id: String) -> Channel? {
        channels.first { $0.id == id }
    }

    /// The card for a channel: why it has no guide, or where its guide comes from.
    func card(for channel: Channel) -> GuideSourcesText.Card {
        let reason = GuideDiagnosis.reason(for: channel, rows: status, index: index, now: now())
        let names = Dictionary(uniqueKeysWithValues: status.rows.map { ($0.reference.storageKey, name($0.reference)) })
        let context = GuideSourcesText.CardContext(
            channel: channel, source: source, kind: kind, status: status, index: index, now: now(),
            guideName: { names[$0.storageKey] ?? "" })
        return text.card(reason, context)
    }

    /// The channel's match when it can be removed: picked by hand or by name.
    func match(for channel: Channel) -> GuideMatch? {
        index.match(for: channel)
    }

    /// The picker's results for `query` over the turned-on, loaded guides.
    func search(_ query: String) -> GuideEntrySearch.Result {
        let key = index.programmeCount &* 31 &+ status.rows.count(where: \.hasGuide)
        if cachedSearch?.key != key {
            cachedSearch = (key, GuideEntrySearch(index.entries(sourceID: sourceID)))
        }
        return cachedSearch?.search.search(query) ?? GuideEntrySearch.Result(entries: [], total: 0)
    }

    /// An entry's display name, or its id when no guide names it.
    func entryName(_ id: String) -> String {
        index.entryName(sourceID: sourceID, id: id) ?? id
    }

    /// How many of the source's channels have no current programme, for
    /// the Guide row in the source's details.
    static func missingCount(_ sourceID: UUID, store: AppGuideStore?) -> Int? {
        guard let store, let status = store.statuses[sourceID], let channels = store.channels[sourceID] else { return nil }
        let now = Date.now
        return channels.count { channel in
            if case .hasGuide = GuideDiagnosis.reason(for: channel, rows: status, index: store.index, now: now) { return false }
            return true
        }
    }

    /// True once a turned-on guide of the source has loaded on this device.
    var hasLoadedGuide: Bool { status.rows.contains { $0.enabled && $0.hasGuide } }

    // MARK: Changing

    private func change(_ edit: (inout GuideSettings) -> Bool) -> Bool {
        let saved = GuideSettingsStore.update(sourceID, in: context, edit)
        if saved { Task { await store?.settingsChanged() } }
        return saved
    }

    /// Moves a guide one place up or down
    /// (guide-sources-and-channel-mapping/choose-which-guide-wins).
    func move(_ reference: GuideReference, by offset: Int) {
        var list = status.rows.map(\.reference)
        guard let from = list.firstIndex(of: reference) else { return }
        let to = from + offset
        guard list.indices.contains(to) else { return }
        list.swapAt(from, to)
        let date = now()
        _ = change { settings in
            settings.setOrder(list, at: date)
            return true
        }
    }

    /// Turns a guide on or off (guide-sources-and-channel-mapping/turn-off-or-remove-a-guide).
    func toggle(_ row: GuideRow) {
        let date = now()
        _ = change { settings in
            settings.setEnabled(!row.enabled, for: row.reference, at: date)
            return true
        }
    }

    /// Removes a link the user added, and its Keychain item.
    func remove(_ reference: GuideReference) {
        guard case .added(let id) = reference else { return }
        let date = now()
        _ = change { settings in
            settings.removeLink(id, at: date)
            return true
        }
        try? credentials.delete(for: GuideSettingsStore.linkKey(sourceID, id))
    }

    func retry(_ reference: GuideReference) {
        Task { await store?.refresh(sourceID: sourceID, guide: reference) }
    }

    /// Adds the typed link to the end of the list, or replaces the link of
    /// `replacing` in its place, and starts its download
    /// (guide-sources-and-channel-mapping/add-a-guide-link). Returns the
    /// problem to show, or nil once saved.
    func add(_ typed: String, replacing: String? = nil) async -> GuideLinkInput.Problem? {
        let existing = await store?.guideLinks(sourceID: sourceID) ?? []
        let url: URL
        switch GuideLinkInput.check(typed, existing: existing) {
        case .failure(let problem): return problem
        case .success(let checked): url = checked
        }
        let id = replacing ?? UUID().uuidString
        let date = now()
        var stored = GuideLinkInput.storage(for: url, at: date)
        if let replacing, let old = settings.links[replacing] { stored.link.addedAt = old.addedAt }
        if let secret = stored.secret {
            do {
                try GuideSettingsStore.saveLink(secret, sourceID: sourceID, linkID: id, credentials: credentials)
            } catch {
                return .invalid
            }
        }
        let added = change { $0.addLink(stored.link, id: id) }
        return added ? nil : .invalid
    }

    /// Matches the channel to a guide entry picked by hand
    /// (guide-sources-and-channel-mapping/pick-the-right-guide-entry-by-hand).
    /// False when the source's settings are full.
    @discardableResult
    func pick(_ entry: GuideEntry, for channel: Channel) -> Bool {
        let present = Set(channels.map(\.id))
        let date = now()
        let saved = change { $0.setMatch(entry.id, for: channel.id, at: date, present: present) }
        error = saved ? nil : GuideSourcesText.tooMany
        return saved
    }

    /// Removes a channel's match: a hand-picked one goes back to the
    /// playlist's id (guide-sources-and-channel-mapping/undo-a-hand-picked-match);
    /// a match by name is undone for good
    /// (guide-sources-and-channel-mapping/channels-matched-by-name).
    func removeMatch(for channel: Channel) {
        let origin = index.match(for: channel)?.origin
        let present = Set(channels.map(\.id))
        let date = now()
        _ = change { settings in
            if origin == .name {
                return settings.setMatch(nil, for: channel.id, at: date, present: present)
            }
            settings.removeMatch(for: channel.id, at: date)
            return true
        }
    }
}
