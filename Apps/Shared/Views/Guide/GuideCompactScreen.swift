#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// The Guide on iPhone and in a narrow iPad Split View
    /// (guide-on-iphone-ipad-and-mac/one-row-per-channel-on-iphone;
    /// `iPhone-Guide`, `iPhone-Guide-Placeholders`, `iPhone-Guide-Detail`):
    /// group chips and day chips over one row per channel, each scrolling
    /// sideways through that channel's programmes from the one on now, and
    /// the now-playing bar above the tab bar. A filter field waits above the
    /// first row until the list is pulled down
    /// (guide-on-iphone-ipad-and-mac/filter-channels-by-typing).
    struct GuideCompactScreen: View {
        @Environment(LiveModel.self) private var live
        @Environment(GuideBoardModel.self) private var model
        @Environment(\.guideBoardOpenLive) private var openLive

        private var reading: GuideBoardReading { GuideBoardReading(live: live, model: model) }

        var body: some View {
            @Bindable var model = model
            Group {
                if live.launched, live.sources.isEmpty {
                    LiveNoSources()
                } else {
                    TimelineView(.periodic(from: .now, by: LiveClock.tick)) { context in
                        content(now: context.date)
                    }
                }
            }
            .background(Palette.ground)
            .safeAreaInset(edge: .bottom, spacing: 0) { GuideNowPlayingBar() }
            .sheet(item: $model.details) { target in
                GuideDetailsSheet(target: target)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(GuideBoard.panelGround)
            }
            .modifier(GuideRequestTaker())
            .modifier(GuideBannerWatch())
            // Another group brings back the whole group.
            .onChange(of: live.group) { _, _ in model.filter = "" }
            .overlay {
                #if DEBUG
                    UITestingLive.Probe(engine: live.engine)
                #endif
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("guide.root")
        }

        @ViewBuilder private func content(now: Date) -> some View {
            switch live.status {
            case .channels:
                let data = reading.data(at: now, filtered: true)
                VStack(spacing: 0) {
                    groups
                    days(data, now: now)
                    GuideBannerList(banners: reading.banners())
                        .padding(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
                    if data.rows.isEmpty, model.filter.isEmpty {
                        GuideBoard.Empty(text: "No channels in \(live.catalogue.label(of: live.group))")
                            .accessibilityIdentifier("guide.empty")
                    } else {
                        GuideCompactList(data: data, now: now, anchor: model.time ?? now)
                    }
                }
            case let status:
                LiveStatusMessage(status: status)
            }
        }

        private var groups: some View {
            ScrollViewReader { proxy in
                Browse.Chips {
                    ForEach(Array(live.catalogue.groups.enumerated()), id: \.element) { index, group in
                        Browse.Chip(title: live.catalogue.label(of: group), isSelected: group == live.group) {
                            live.show(group)
                        }
                        .id(group)
                        .accessibilityIdentifier("guide.group.\(index)")
                    }
                    LockedGroupChips()
                }
                .task { proxy.scrollTo(live.group) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("guide.chips")
        }

        private func days(_ data: GuideData, now: Date) -> some View {
            let days = data.timeline.days(at: now)
            let selected = model.selectedDay(data.timeline, now: now)
            return HStack(spacing: 6) {
                GuideBoard.Days {
                    ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                        GuideBoard.DayChip(title: data.timeline.dayLabel(day, today: now), isSelected: index == selected) {
                            if index == 0 {
                                model.showNow(playing: nil)
                            } else {
                                model.pick(day: index, timeline: data.timeline, now: now)
                            }
                        }
                        .accessibilityIdentifier("guide.day.\(index)")
                    }
                }
                GuideBoard.NowButton { model.showNow(playing: reading.playingKey) }
            }
            .padding(.horizontal, 16)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Palette.surface(0.08)).frame(height: 1)
            }
        }
    }

    /// One row per channel, built as they scroll into view.
    private struct GuideCompactList: View {
        let data: GuideData
        let now: Date
        let anchor: Date
        @Environment(LiveModel.self) private var live
        @Environment(GuideBoardModel.self) private var model

        /// The filter field's place in the list, above the first row.
        static let filterID = "guide.filter.row"

        var body: some View {
            @Bindable var model = model
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        Browse.FilterField(text: $model.filter)
                            .padding(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                            .id(Self.filterID)
                        ForEach(data.rows, id: \.self) { key in
                            GuideCompactRow(key: key, now: now, anchor: anchor)
                                .id(key)
                        }
                    }
                    .padding(.vertical, 4)
                }
                // The field starts out of sight above the first row; pulling down shows it.
                .onAppear {
                    if model.filter.isEmpty, let first = data.rows.first { proxy.scrollTo(first, anchor: .top) }
                }
                .onChange(of: model.jump) { _, jump in
                    guard let jump else { return }
                    switch jump.place {
                    case .now(let row), .time(_, let row):
                        if let row, data.rows.contains(row) { proxy.scrollTo(row, anchor: .center) }
                    case .reveal(let target):
                        proxy.scrollTo(target.key)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("guide.list")
        }
    }

    /// A channel's header and its strip of cards from the programme on at `anchor`.
    private struct GuideCompactRow: View {
        let key: RowKey
        let now: Date
        let anchor: Date
        @Environment(LiveModel.self) private var live
        @Environment(GuideBoardModel.self) private var model
        @Environment(\.guideBoardOpenLive) private var openLive

        /// How far ahead a row reads programmes.
        static let reach: TimeInterval = 24 * 3600

        var body: some View {
            let reading = GuideBoardReading(live: live, model: model)
            if let channel = reading.channel(key) {
                let look: GuideBoard.ChannelLook = key == reading.playingKey ? .playing : .plain
                VStack(alignment: .leading, spacing: 6) {
                    GuideBoard.Compact.RowHeader(number: reading.number(key), name: channel.name, look: look) {
                        reading.watch(key, programme: nil, now: now)
                        openLive()
                    } logo: {
                        GuideCompactLogo(channel: channel, look: look)
                    }
                    .accessibilityValue(look == .playing ? "playing" : "")
                    .modifier(LiveFavoriteMenu(channel: channel, identifier: "guide.menu.favorite") { EmptyView() })
                    .modifier(LiveFavoriteAction(channel: channel))
                    .accessibilityIdentifier("guide.channel.\(key.identifier)")
                    strip(channel, look: look)
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("guide.row.\(key.identifier)")
            }
        }

        @ViewBuilder private func strip(_ channel: Channel, look: GuideBoard.ChannelLook) -> some View {
            let state = live.programmes.state(channel)
            let programmes = live.programmes.programmes(channel, DateInterval(start: anchor, duration: Self.reach))
            let cards = GuidePlaceholder(state: state) == nil ? GuideStrip.cards(programmes, from: anchor) : []
            if let placeholder = GuidePlaceholder(state: state) ?? (cards.isEmpty ? .noGuide : nil) {
                GuideBoard.Compact.Placeholder(text: placeholder.text)
                    .accessibilityIdentifier(
                        GuideText.identifier(
                            GuideCell(segment: GuideSegment(start: anchor, stop: anchor), placeholder: placeholder), key: key))
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: GuideStrip.spacing) {
                        ForEach(cards, id: \.start) { segment in
                            card(segment, channel: channel)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
                // A new day starts the strip from its first card; the clock ticking does not.
                .id(model.time)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("guide.strip.\(key.identifier)")
            }
        }

        @ViewBuilder private func card(_ segment: GuideSegment, channel: Channel) -> some View {
            let cell = GuideCell(segment: segment)
            let identifier = GuideText.identifier(cell, key: key)
            if let programme = segment.programme {
                let timing = GuideTiming(start: segment.start, stop: segment.stop, now: now)
                let progress = timing == .now ? ProgrammeProgress.fraction(start: segment.start, end: segment.stop, now: now) : nil
                Button {
                    model.open(GuideTarget(key: key, start: segment.start))
                } label: {
                    GuideBoard.Compact.Card(
                        time: GuideText.time(segment.start), title: GuidePanelText.title(programme), timing: timing, progress: progress)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(GuideText.spoken(cell, channel: channel, now: now))
                .accessibilityIdentifier(identifier)
            } else {
                GuideBoard.Compact.GapCard(times: GuideText.times(segment.start, segment.stop))
                    .accessibilityIdentifier(identifier)
            }
        }
    }

    /// A channel's logo on the small tile, or its initials while there is none.
    private struct GuideCompactLogo: View {
        let channel: Channel
        let look: GuideBoard.ChannelLook

        var body: some View {
            let initials = GuideBoard.Compact.Initials(text: Channel.initials(for: channel.name), look: look)
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
    }

    /// The details as a sheet at the medium detent on iPhone.
    struct GuideDetailsSheet: View {
        let target: GuideTarget
        @Environment(\.reminders) private var reminders
        @Environment(LiveModel.self) private var live
        @Environment(GuideBoardModel.self) private var model
        @Environment(\.guideBoardOpenLive) private var openLive

        var body: some View {
            TimelineView(.periodic(from: .now, by: LiveClock.tick)) { context in
                let reading = GuideBoardReading(live: live, model: model)
                let data = reading.data(at: context.date, filtered: false)
                if let details = reading.details(target, data, now: context.date) {
                    GuideBoard.Details.Sheet(details: details, reminder: reading.reminder(target, data, reminders, now: context.date)) {
                        reading.watch(target, data: data, now: context.date)
                        openLive()
                    }
                    .onAppear {
                        AccessibilityNotification.Announcement("\(details.title), details").post()
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    /// The bar above the tab bar while a channel plays in Live; a tap goes
    /// back to Live (guide-on-iphone-ipad-and-mac/playback-carries-on-out-of-sight).
    struct GuideNowPlayingBar: View {
        @Environment(LiveModel.self) private var live
        @Environment(\.guideBoardOpenLive) private var openLive

        var body: some View {
            if let channel = live.playing {
                TimelineView(.periodic(from: .now, by: LiveClock.tick)) { context in
                    let text = GuideNowPlaying.text(for: channel, live: live, at: context.date)
                    GuideBoard.Compact.NowPlayingBar(
                        title: text.title, detail: text.detail, isPlaying: live.playback == .playing, progress: text.progress,
                        open: openLive
                    ) {
                        GuideCompactLogo(channel: channel, look: .playing)
                    }
                }
            }
        }
    }
#endif
