#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// The Guide on iPhone and in a narrow iPad Split View
    /// (guide-on-iphone-ipad-and-mac/one-row-per-channel-on-iphone;
    /// `iPhone-Guide`, `iPhone-Guide-Placeholders`, `iPhone-Guide-Detail`):
    /// the group button and day chips over one row per channel, each scrolling
    /// sideways through that channel's programmes from the one on now, and
    /// the now-playing bar above the tab bar. A filter field waits above the
    /// first row until the list is pulled down
    /// (guide-on-iphone-ipad-and-mac/filter-channels-by-typing).
    struct GuideCompactScreen: View {
        @Environment(LiveModel.self) private var live
        @Environment(GuideBoardModel.self) private var model
        @Environment(\.guideBoardOpenLive) private var openLive
        @State private var groupsShown = false

        private var reading: GuideBoardReading { GuideBoardReading(live: live, model: model) }

        var body: some View {
            @Bindable var model = model
            Group {
                if live.launched, live.sources.isEmpty {
                    LiveNoSources().profileButtonInCorner()
                } else {
                    // The clock ticks in the header and in each row, not here,
                    // so a tick never walks the group's rows
                    // (guide-on-iphone-ipad-and-mac/the-clock-redraws-only-what-shows-the-time).
                    content
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
            .overlay(alignment: .bottomLeading) {
                #if DEBUG
                    // Out of the way of the profile button at the top right.
                    UITestingLive.Probe(engine: live.engine)
                        .frame(width: 60, height: 30)
                        .allowsHitTesting(false)
                #endif
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("guide.root")
        }

        @ViewBuilder private var content: some View {
            switch live.status {
            case .channels:
                let data = reading.data(at: .now, filtered: true)
                VStack(spacing: 0) {
                    LiveGroupButton(place: .guide, isPresented: $groupsShown).withProfileButton()
                    TimelineView(.periodic(from: .now, by: LiveClock.tick)) { context in
                        days(reading.data(at: context.date, filtered: false).timeline, now: context.date)
                    }
                    GuideBannerList(banners: reading.banners())
                        .padding(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
                    if data.rows.isEmpty, model.filter.isEmpty {
                        GuideBoard.Empty(text: "No channels in \(live.catalogue.label(of: live.group))")
                            .accessibilityIdentifier("guide.empty")
                    } else {
                        GuideCompactList(data: data, time: model.time)
                            // Another group opens at its first row.
                            .id(live.group)
                    }
                }
            case let status:
                LiveStatusMessage(status: status).profileButtonInCorner()
            }
        }

        private func days(_ timeline: GuideTimeline, now: Date) -> some View {
            let days = timeline.days(at: now)
            let selected = model.selectedDay(timeline, now: now)
            return HStack(spacing: 6) {
                GuideBoard.Days {
                    ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                        GuideBoard.DayChip(title: timeline.dayLabel(day, today: now), isSelected: index == selected) {
                            if index == 0 {
                                model.showNow(playing: nil)
                            } else {
                                model.pick(day: index, timeline: timeline, now: now)
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
        /// The time the user moved to, nil while the rows follow now.
        let time: Date?
        @Environment(LiveModel.self) private var live
        @Environment(GuideBoardModel.self) private var model
        @Environment(\.tabTaps) private var tabTaps
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                            // Each row on screen moves on with the clock by itself.
                            TimelineView(.periodic(from: .now, by: LiveClock.tick)) { context in
                                GuideCompactRow(key: key, now: context.date, anchor: time ?? context.date)
                            }
                            .id(key)
                        }
                    }
                    .padding(.vertical, 4)
                }
                // The field starts out of sight above the first row; pulling down shows it.
                .onAppear {
                    if model.filter.isEmpty, let first = data.rows.first { proxy.scrollTo(first, anchor: .top) }
                }
                // Tapping Guide again goes back to the first channel
                // (live-tv-on-iphone-ipad-mac/tap-the-open-tab-to-go-back-to-the-top).
                .onChange(of: tabTaps) { _, _ in
                    guard let first = data.rows.first else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { proxy.scrollTo(first, anchor: .top) }
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
            #if DEBUG
                // How often the list was built, for the UI test that pins
                // the clock tick to the rows.
                .accessibilityValue("builds=\(UITestingLive.Counts.guideListBuilds())")
            #endif
        }
    }

    /// A channel's header and its strip of cards from the programme on at `anchor`.
    private struct GuideCompactRow: View {
        @Environment(\.locale) private var locale
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
                        time: GuideText(locale: locale).time(segment.start), title: GuidePanelText.title(programme), timing: timing,
                        progress: progress)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(GuideText(locale: locale).spoken(cell, channel: channel, now: now))
                .accessibilityIdentifier(identifier)
            } else {
                GuideBoard.Compact.GapCard(times: GuideText(locale: locale).times(segment.start, segment.stop))
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
            LogoImage(url: channel.logoURL) { initials }
        }
    }

    /// The details as a sheet at the medium detent on iPhone.
    struct GuideDetailsSheet: View {
        @Environment(\.locale) private var locale
        let target: GuideTarget
        @Environment(\.reminders) private var reminders
        @Environment(LiveModel.self) private var live
        @Environment(GuideBoardModel.self) private var model
        @Environment(\.guideBoardOpenLive) private var openLive

        var body: some View {
            TimelineView(.periodic(from: .now, by: LiveClock.tick)) { context in
                let reading = GuideBoardReading(live: live, model: model)
                let data = reading.data(at: context.date, filtered: false)
                if let details = reading.details(target, data, now: context.date, locale: locale) {
                    GuideBoard.Details.Sheet(details: details, reminder: reading.reminder(target, data, reminders, now: context.date)) {
                        reading.watch(target, data: data, now: context.date)
                        openLive()
                    }
                    .onAppear {
                        AccessibilityNotification.Announcement(Words(locale)("\(details.title), details")).post()
                    }
                }
            }
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
                        open: openLive.perform
                    ) {
                        GuideCompactLogo(channel: channel, look: .playing)
                    }
                }
            }
        }
    }
#endif
