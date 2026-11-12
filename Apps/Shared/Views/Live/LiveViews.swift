#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// Feeds the Live model from the store and the system: the sources, the
    /// favorites, the engine's state and returns to the foreground. Applied
    /// once above both layouts, so a layout switch reloads nothing.
    struct LiveSync: ViewModifier {
        let live: LiveModel
        @Query(sort: SourceRecord.displayOrder) private var records: [SourceRecord]
        @Query(sort: \FavoriteRecord.sortOrder) private var favorites: [FavoriteRecord]
        @Environment(\.scenePhase) private var scenePhase
        @Environment(\.currentProfile) private var profile
        @Environment(\.sourceRefresher) private var refresher
        @Query private var preferences: [PreferencesRecord]

        func body(content: Content) -> some View {
            content
                .environment(live)
                .environment(\.loadedChannels, live.channels)
                .task(id: records.compactMap(\.descriptor)) {
                    live.sourcesChanged(records.compactMap(\.descriptor))
                }
                // The current profile's favorites, on this device or through sync.
                .onChange(of: ownFavorites, initial: true) { _, snapshots in
                    live.favoritesChanged(snapshots)
                }
                .onChange(of: scenePhase) { _, phase in
                    // Leaving the app stops the ten-second count; coming back
                    // starts it again from zero when the channel still plays.
                    switch phase {
                    case .active:
                        live.checkLogins()
                        live.session.stateChanged(live.playback)
                        // Sources that failed, as when offline at launch, and sources past their
                        // refresh interval load again (sources-and-settings/sources-refresh-on-a-schedule).
                        live.retry()
                        refresher?.refreshDue(interval: PreferencesStore.current(preferences).refresh.duration)
                    case .background: live.session.interrupt()
                    default: break
                    }
                }
                .modifier(SourceDeletions(removed: live.sourceDeleted, defaults: live.session.store.defaults))
                .modifier(GroupRulesFeed(changed: live.rulesChanged))
                .task { await live.observeEngine() }
                .task { await live.player.observeDetails() }
                .task { await live.player.observeAirPlay() }
                .task { await live.player.observePictureInPicture() }
                .task { await live.publishNowPlaying() }
                // The controls hide again a while after the track list closes.
                .onChange(of: live.player.pickerOpen) { _, open in
                    if !open, live.controlsShown { live.showControls(after: .touch) }
                }
        }

        private var ownFavorites: [FavoriteSnapshot<PersistentIdentifier>] {
            favorites.filter { ProfileList.owns(profile, recordProfile: $0.profileID) }.map(\.snapshot)
        }
    }

    /// The star for the playing channel (live-tv-on-iphone-ipad-mac/star-a-channel):
    /// filled while it is one of the current profile's favorites; a tap
    /// adds or removes it through the store.
    struct LiveFavoriteButton: View {
        let channel: Channel
        @Environment(LiveModel.self) private var live
        @Environment(\.modelContext) private var context
        @Environment(\.currentProfile) private var profile

        var body: some View {
            Browse.FavoriteButton(isFavorite: live.catalogue.isFavorite(channel)) {
                FavoriteRecord.toggle(channel, in: live.catalogue, profile: profile, context: context)
            }
            .accessibilityIdentifier("browse.favorite")
        }
    }

    /// The open group's channels in catalogue order, the playing one
    /// highlighted (live-tv-on-iphone-ipad-mac/pick-a-group). Each row says
    /// what is on now.
    struct LiveChannelList: View {
        /// Called after a row is picked.
        var picked: () -> Void = {}
        /// The row the arrow keys moved to, drawn with a focus ring.
        var cursor: RowKey?
        @Environment(LiveModel.self) private var live

        var body: some View {
            let rows = live.rows
            if rows.isEmpty, live.group == .favorites, live.filter.isEmpty {
                Browse.EmptyGroup(text: "No favorites yet. Tap the star on a channel to add it.")
            } else if rows.isEmpty {
                Browse.EmptyGroup(text: "No channels match.")
            } else {
                ScrollViewReader { proxy in
                    list(rows)
                        .onChange(of: cursor) { _, key in
                            if let key { proxy.scrollTo(key) }
                        }
                }
            }
        }

        private func list(_ rows: [RowKey]) -> some View {
            List(rows, id: \.self) { key in
                if let channel = live.catalogue.channel(for: key) {
                    // Each row on screen moves on to the next programme
                    // within seconds of it starting.
                    TimelineView(.periodic(from: .now, by: LiveClock.tick)) { context in
                        row(key, channel, at: context.date)
                    }
                    .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("browse.list")
            // A new group opens at its top.
            .id(live.group)
        }

        private func row(_ key: RowKey, _ channel: Channel, at date: Date) -> some View {
            let line = live.programmes.line(for: channel, at: date)
            let number = live.catalogue.number(for: key)
            let isPlaying = channel == live.listedChannel
            var progress: Double?
            var remaining: String?
            if case .programme(_, let fraction, let left) = line {
                progress = fraction
                remaining = left
            }
            return Browse.ChannelRow(
                number: number, name: channel.name, detail: line.text, progress: progress, hasCatchUp: channel.catchUpBadge != nil,
                isPlaying: isPlaying
            ) {
                live.pick(channel)
                picked()
            } logo: {
                Browse.Logo(url: channel.logoURL, initials: Channel.initials(for: channel.name), isSelected: isPlaying)
            }
            .liveMultiViewMenu(channel)
            .browseFocusRing(key == cursor)
            .accessibilityValue(key == cursor ? "Keyboard focus" : "")
            .id(key)
            .accessibilityIdentifier("browse.row.\(key.identifier)")
            .accessibilityLabel([channel.name, number.map(String.init), line.text, remaining].compactMap(\.self).joined(separator: ", "))
        }
    }

    /// How often Live redraws what is on now, so a programme that ends
    /// gives way to the next within seconds
    /// (live-tv-on-iphone-ipad-mac/see-what-is-on-now-and-next).
    enum LiveClock {
        static let tick: TimeInterval = 5
    }

    /// Stands in for onboarding, which change add-first-run-onboarding builds,
    /// while the user has no source at all.
    struct LiveNoSources: View {
        var body: some View {
            ContentUnavailableView(
                "No sources yet",
                systemImage: "antenna.radiowaves.left.and.right",
                description: Text("Add an M3U playlist or Xtream login under Settings. It syncs to your other devices through iCloud.")
            )
            .accessibilityIdentifier("channels.emptyState")
        }
    }

    /// The details panel for the playing channel, with up to three
    /// programmes after the current one.
    struct LiveDetails: View {
        let channel: Channel
        @Environment(LiveModel.self) private var live

        var body: some View {
            TimelineView(.periodic(from: .now, by: LiveClock.tick)) { context in
                let text = live.nowText(for: channel, at: context.date)
                Browse.Panel(
                    channel: channel.name,
                    now: .init(
                        title: text.title, times: text.times, meta: text.meta, summary: text.summary,
                        progress: text.progress),
                    next: text.next.map { .init(time: LiveModel.time($0.start), title: $0.title) }
                ) {
                    Browse.Logo(url: channel.logoURL, initials: Channel.initials(for: channel.name), isSelected: true)
                } trailing: {
                    LiveFavoriteButton(channel: channel)
                        .environment(\.browseMetrics, .regular)
                }
            }
        }
    }
#endif
