#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// The channel overlay over the running player (tv-channel-overlay capability; `Main`):
    /// the groups, the chosen group's channels and the clock. Playback is the
    /// shell's; this view only reports a pick or the Search entry.
    struct ChannelOverlayView: View {
        let catalogue: Catalogue<PersistentIdentifier>
        let playing: Channel?
        let guide: OverlayGuide
        let model: ChannelOverlayModel
        let focus: FocusState<ShellFocus?>.Binding
        /// A channel was selected in the shown group.
        let pick: (Channel, CatalogueGroup) -> Void
        /// The favorite button was pressed for the highlighted channel.
        let toggleFavorite: (Channel, RowKey) -> Void
        let openSearch: () -> Void
        /// The multi-view button, and the picker's wording while a tile picks a channel.
        var multiView: OverlayMultiView?
        /// Start over for the playing channel's programme on now, nil while it cannot work
        /// (timeshift-catch-up-and-start-over/start-over-shows-only-when-it-can-work).
        var startOver: (() -> Void)?
        @Environment(\.reminders) private var reminders
        @Environment(\.unlockGroup) private var unlock
        /// The locked group last picked; it opens once the passcode adds it to the list.
        @State private var asked: CatalogueGroup?

        var body: some View {
            layout.onChange(of: catalogue.groups) { _, groups in
                guard let asked, groups.contains(asked) else { return }
                self.asked = nil
                model.show(asked)
            }
        }

        private var layout: some View {
            ChannelOverlay.Layout {
                ScrollViewReader { proxy in
                    groups
                        .onAppear { proxy.scrollTo(model.group, anchor: .center) }
                        .onChange(of: model.group) { _, group in
                            // Focus scrolls the column itself while it is there.
                            guard !focusIsOnGroups else { return }
                            proxy.scrollTo(group, anchor: .center)
                        }
                }
                // Left from the channels lands on the group they belong to.
                .defaultFocus(focus, .overlay(.group(model.group)), priority: .userInitiated)
                .focusSection()
                .controlHints(.overlayGroups)
            } channels: {
                ChannelOverlay.ChannelColumn(title: catalogue.label(of: model.group), order: model.group.order) {
                    if let empty = model.emptyText(catalogue) {
                        ChannelOverlay.EmptyGroup(text: empty)
                    } else {
                        OverlayChannelList(
                            catalogue: catalogue, group: model.group, entry: entry, guide: guide, focus: focus, multiView: multiView,
                            pick: { [model] channel in pick(channel, model.group) }, toggleFavorite: toggleFavorite
                        )
                        .equatable()
                        .id(model.group)
                    }
                }
                // Right from a group, or left from the panel, lands on the row the panel describes, else the entry row.
                .defaultFocus(focus, channelTarget, priority: .userInitiated)
                .focusSection()
                .controlHints(.overlayChannels)
            } panel: {
                if let key = model.panelRow(catalogue), let channel = catalogue.channel(for: key) {
                    TimelineView(.everyMinute) { context in
                        panel(key, channel, at: context.date)
                    }
                    .controlHints(.overlayChannels)
                }
            } clock: {
                TimelineView(.everyMinute) { context in
                    ShellTabBar.Clock(date: context.date, identifier: "overlay.clock")
                }
            }
        }

        private var groups: some View {
            ChannelOverlay.GroupColumn {
                ForEach(Array(catalogue.groups.enumerated()), id: \.element) { index, group in
                    let count = catalogue.count(of: group)
                    ChannelOverlay.GroupRow(
                        title: catalogue.label(of: group), systemImage: group.systemImage, count: count,
                        look: group == model.group ? .selected : .plain
                    ) {
                        model.show(group)
                        if let target = model.target(catalogue, playing: playing) { focus.wrappedValue = .overlay(.channel(target)) }
                    }
                    .focused(focus, equals: .overlay(.group(group)))
                    .groupSpokenLabel(group, count: count)
                    .id(group)
                    .accessibilityIdentifier(group == .new ? "overlay.group.new" : "overlay.group.\(index)")
                }
                ForEach(catalogue.lockedGroups, id: \.self) { group in
                    ChannelOverlay.GroupRow(
                        title: catalogue.label(of: group), systemImage: "lock.fill", count: 0, look: .plain
                    ) {
                        asked = group
                        unlock?(group)
                    }
                    .focused(focus, equals: .overlay(.group(group)))
                    .id(group)
                    .accessibilityLabel("\(catalogue.label(of: group)), locked")
                    .accessibilityIdentifier("overlay.locked.\(group.storageKey)")
                }
            } search: {
                // The picker for a multi-view tile has no Search.
                if multiView?.pickTarget == nil {
                    ChannelOverlay.SearchRow(open: openSearch)
                        .focused(focus, equals: .overlay(.search))
                        .accessibilityIdentifier("overlay.search")
                }
            }
        }

        /// The playing channel when the shown group holds it, else its first row.
        private var entry: RowKey? {
            model.entry(catalogue, playing: playing)
        }

        /// Where focus lands entering the channel column, from a group or from the panel.
        private var channelTarget: ShellFocus? {
            model.target(catalogue, playing: playing).map { .overlay(.channel($0)) }
        }

        private var focusIsOnGroups: Bool {
            switch focus.wrappedValue {
            case .overlay(.group), .overlay(.search): true
            default: false
            }
        }

        private func panel(_ key: RowKey, _ channel: Channel, at date: Date) -> some View {
            let guideNow = guide.panel(for: channel, at: date)
            let now = guideNow.now.flatMap { programme -> ChannelOverlay.PanelNow? in
                guard case .programme(_, let progress, let remaining) = guideNow.line else { return nil }
                let times = "\(Self.time(programme.start)) – \(Self.time(programme.stop)) · \(remaining)"
                return .init(title: programme.title, times: times, progress: progress, summary: programme.summary)
            }
            return ChannelOverlay.Panel(
                name: channel.name,
                badges: [catalogue.channelNumber(for: key).map(\.description), channel.catchUpBadge].compactMap(\.self),
                now: now, nothingOn: guideNow.line.text,
                next: guideNow.next.map { .init(time: Self.time($0.start), title: $0.title) }, eyebrow: multiView?.pickTarget
            ) {
                OverlayLogo(channel: channel)
            } nextRow: { item in
                nextRow(item, programmes: guideNow.next, channel: channel, at: date)
            } buttons: {
                PanelButtons(
                    isFavorite: catalogue.isFavorite(channel), focus: focus, watchTitle: multiView?.watchTitle ?? "Watch",
                    watch: { pick(channel, model.group) }, toggle: { toggleFavorite(channel, key) },
                    startOver: channel == playing ? startOver : nil,
                    multiView: multiView.flatMap { offer in offer.offered(channel) ? (offer.title, { offer.add(channel) }) : nil })
            }
        }

        /// A programme that follows, as a row that sets or removes its
        /// reminder when the channel has a guide id
        /// (programme-reminders/remind-me-appears-only-before-a-programme-starts).
        @ViewBuilder
        private func nextRow(_ item: ChannelOverlay.PanelNext, programmes: [Programme], channel: Channel, at date: Date) -> some View {
            let index = programmes.firstIndex { Self.time($0.start) == item.time && $0.title == item.title }
            if let index, let reminders, reminders.offers(programmes[index], on: channel, now: date) {
                let programme = programmes[index]
                ChannelOverlay.NextReminderRow(item: item, isSet: reminders.isSet(programme, on: channel)) {
                    reminders.toggle(programme, on: channel)
                }
                .focused(focus, equals: .overlay(.next(index)))
                .accessibilityIdentifier("overlay.panel.next.\(index)")
            } else {
                ChannelOverlay.NextLine(item: item)
            }
        }

        private static func time(_ date: Date) -> String {
            date.formatted(date: .omitted, time: .shortened)
        }
    }

    /// Watch, the favorite button, then the multi-view button when it is
    /// offered, in the panel's focus order.
    struct PanelButtons: View {
        let isFavorite: Bool
        let focus: FocusState<ShellFocus?>.Binding
        var watchTitle = "Watch"
        let watch: () -> Void
        let toggle: () -> Void
        /// Start over; nil leaves it out.
        var startOver: (() -> Void)?
        /// The multi-view button's title and action; nil leaves it out.
        var multiView: (title: String, add: () -> Void)?

        var body: some View {
            ChannelOverlay.WatchButton(title: watchTitle, watch: watch)
                .focused(focus, equals: .overlay(.watch))
                .accessibilityIdentifier("overlay.watch")
            if let startOver {
                ChannelOverlay.WatchButton(title: "Start over", watch: startOver)
                    .focused(focus, equals: .overlay(.startOver))
                    .accessibilityIdentifier("overlay.startOver")
            }
            ChannelOverlay.FavoriteButton(isFavorite: isFavorite, toggle: toggle)
                .focused(focus, equals: .overlay(.favorite))
                .accessibilityIdentifier("overlay.favorite")
            if let multiView {
                ChannelOverlay.MultiViewButton(title: multiView.title, add: multiView.add)
                    .focused(focus, equals: .overlay(.multiView))
                    .accessibilityIdentifier("overlay.multiView")
            }
        }
    }

    /// What the overlay offers for multi-view (multi-view/start-multi-view-on-apple-tv,
    /// multi-view/change-a-tile-s-channel): over full-screen live, "Add to
    /// multi-view"; in the picker for a tile, "Add as new tile", the tile
    /// it changes and the tiles each channel is in.
    struct OverlayMultiView {
        let title: String
        /// Whether the button shows for this channel.
        let offered: (Channel) -> Bool
        let add: (Channel) -> Void
        /// "Changing tile 2 of 3" in the picker, nil over full-screen live.
        var pickTarget: String?
        /// "Show in tile 2" in the picker.
        var watchTitle: String?
        /// The tile a channel is in, counted from 1.
        var tileBadge: (RowKey) -> Int? = { _ in nil }
    }
#endif
