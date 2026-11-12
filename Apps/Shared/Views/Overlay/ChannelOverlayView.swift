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

        var body: some View {
            ChannelOverlay.Layout {
                ChannelOverlay.GroupColumn {
                    ForEach(Array(catalogue.groups.enumerated()), id: \.element) { index, group in
                        ChannelOverlay.GroupRow(
                            title: group.label, systemImage: group.systemImage, count: catalogue.count(of: group),
                            look: group == model.group ? .selected : .plain
                        ) {
                            model.show(group)
                            if let entry = model.entry(catalogue, playing: playing) { focus.wrappedValue = .overlay(.channel(entry)) }
                        }
                        .focused(focus, equals: .overlay(.group(group)))
                        .groupSpokenLabel(group, count: catalogue.count(of: group))
                        .accessibilityIdentifier("overlay.group.\(index)")
                    }
                } search: {
                    // The picker for a multi-view tile has no Search.
                    if multiView?.pickTarget == nil {
                        ChannelOverlay.SearchRow(open: openSearch)
                            .focused(focus, equals: .overlay(.search))
                            .accessibilityIdentifier("overlay.search")
                    }
                }
                .focusSection()
            } channels: {
                ChannelOverlay.ChannelColumn(title: model.group.label, order: model.group.order) {
                    if let empty = model.emptyText(catalogue) {
                        ChannelOverlay.EmptyGroup(text: empty)
                    } else {
                        rows
                    }
                }
                .focusSection()
            } panel: {
                if let key = model.panelRow(catalogue), let channel = catalogue.channel(for: key) {
                    TimelineView(.everyMinute) { context in
                        panel(key, channel, at: context.date)
                    }
                }
            } clock: {
                TimelineView(.everyMinute) { context in
                    ShellTabBar.Clock(date: context.date, identifier: "overlay.clock")
                }
            }
        }

        private var rows: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    // Rows move on to the next programme at the minute it starts.
                    TimelineView(.everyMinute) { context in
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(catalogue.rows(in: model.group), id: \.self) { key in
                                if let channel = catalogue.channel(for: key) {
                                    row(key, channel, line: guide.line(for: channel, at: context.date))
                                }
                            }
                        }
                    }
                }
                .scrollClipDisabled()
                .accessibilityIdentifier("overlay.channels")
                .onAppear { scroll(proxy) }
                .onChange(of: model.group) { _, _ in scroll(proxy) }
            }
        }

        private func row(_ key: RowKey, _ channel: Channel, line: GuideLine) -> some View {
            let number = catalogue.number(for: key)
            let progress: Double?
            let remaining: String?
            switch line {
            case .programme(_, let fraction, let left):
                progress = fraction
                remaining = left
            case .message:
                progress = nil
                remaining = nil
            }
            let identifier = "overlay.channel.\(key.identifier)"
            return ChannelOverlay.ChannelRow(
                number: number, name: channel.name, detail: line.text, progress: progress, hasCatchUp: channel.catchUpBadge != nil,
                identifier: identifier, badge: multiView?.tileBadge(key).map(MultiViewText.tileBadge)
            ) {
                pick(channel, model.group)
            } logo: {
                logo(channel)
            }
            .focused(focus, equals: .overlay(.channel(key)))
            .id(key)
            .accessibilityIdentifier(identifier)
            .accessibilityLabel([number.map(String.init), channel.name, line.text, remaining].compactMap(\.self).joined(separator: ", "))
        }

        @ViewBuilder private func logo(_ channel: Channel) -> some View {
            let initials = ChannelOverlay.Initials(text: Channel.initials(for: channel.name))
            if let url = channel.logoURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        initials
                    }
                }
            } else {
                initials
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
                name: channel.name, badges: [catalogue.number(for: key).map(String.init), channel.catchUpBadge].compactMap(\.self),
                now: now, nothingOn: guideNow.line.text,
                next: guideNow.next.map { .init(time: Self.time($0.start), title: $0.title) }, eyebrow: multiView?.pickTarget
            ) {
                logo(channel)
            } buttons: {
                PanelButtons(
                    isFavorite: catalogue.isFavorite(channel), focus: focus, watchTitle: multiView?.watchTitle ?? "Watch",
                    watch: { pick(channel, model.group) }, toggle: { toggleFavorite(channel, key) },
                    startOver: channel == playing ? startOver : nil,
                    multiView: multiView.flatMap { offer in offer.offered(channel) ? (offer.title, { offer.add(channel) }) : nil })
            }
        }

        private static func time(_ date: Date) -> String {
            date.formatted(date: .omitted, time: .shortened)
        }

        /// Brings the highlighted or playing row into view.
        private func scroll(_ proxy: ScrollViewProxy) {
            let target: RowKey?
            if case .overlay(.channel(let key)) = focus.wrappedValue {
                target = key
            } else {
                target = model.entry(catalogue, playing: playing)
            }
            if let target { proxy.scrollTo(target, anchor: .center) }
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
