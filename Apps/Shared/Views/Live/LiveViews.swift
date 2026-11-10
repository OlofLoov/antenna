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

        func body(content: Content) -> some View {
            content
                .environment(live)
                .task(id: records.compactMap(\.descriptor)) {
                    live.sourcesChanged(records.compactMap(\.descriptor))
                }
                .onChange(of: favorites.map(\.snapshot), initial: true) { _, snapshots in
                    live.favoritesChanged(snapshots)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { live.checkLogins() }
                }
                .task { await live.observeEngine() }
        }
    }

    /// The picture area, 16:9: the playing channel, or "Select a channel"
    /// before one is picked. The same engine feeds it in every layout.
    struct LivePicture: View {
        @Environment(LiveModel.self) private var live

        var body: some View {
            Color.clear
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    if live.playing != nil {
                        PlayerSurfaceView(engine: live.engine)
                    } else {
                        Browse.NothingSelected()
                    }
                }
                .clipped()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("browse.player")
        }
    }

    /// The open group's channels in catalogue order, the playing one
    /// highlighted (live-tv-on-iphone-ipad-mac/pick-a-group). Each row says
    /// what is on now.
    struct LiveChannelList: View {
        @Environment(LiveModel.self) private var live

        var body: some View {
            let rows = live.catalogue.rows(in: live.group)
            if rows.isEmpty, live.group == .favorites {
                Browse.EmptyGroup(text: "No favorites yet. Tap the star on a channel to add it.")
            } else {
                TimelineView(.everyMinute) { context in
                    List(rows, id: \.self) { key in
                        if let channel = live.catalogue.channel(for: key) {
                            row(key, channel, at: context.date)
                                .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .accessibilityIdentifier("browse.list")
                }
                // A new group opens at its top.
                .id(live.group)
            }
        }

        private func row(_ key: RowKey, _ channel: Channel, at date: Date) -> some View {
            let line = live.programmes.line(for: channel, at: date)
            let number = live.catalogue.number(for: key)
            let isPlaying = channel == live.playing
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
            } logo: {
                Browse.Logo(url: channel.logoURL, initials: Channel.initials(for: channel.name), isSelected: isPlaying)
            }
            .accessibilityIdentifier("browse.row.\(key.identifier)")
            .accessibilityLabel([channel.name, number.map(String.init), line.text, remaining].compactMap(\.self).joined(separator: ", "))
        }
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
#endif
