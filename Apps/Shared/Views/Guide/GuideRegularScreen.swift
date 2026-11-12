#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    extension EnvironmentValues {
        /// Shows Live; the window root sets it for the guide.
        @Entry var guideBoardOpenLive: @MainActor () -> Void = {}
    }

    /// The Guide on iPad and Mac in the wide layout
    /// (guide-on-iphone-ipad-and-mac capability; `iPad-Guide`,
    /// `iPad-Guide-Placeholders`, `iPad-Guide-Empty`): the toolbar with the
    /// filter, day chips, Now, zoom and what is playing, the banners, then
    /// the grid of the current group. `leading` holds the sidebar button
    /// while the sidebar is folded.
    struct GuideRegularScreen<Leading: View>: View {
        @ViewBuilder var leading: Leading
        @Environment(LiveModel.self) private var live
        @Environment(GuideBoardModel.self) private var model
        @Environment(\.guideBoardOpenLive) private var openLive
        @FocusState private var filterFocused: Bool

        private var reading: GuideBoardReading { GuideBoardReading(live: live, model: model) }

        var body: some View {
            Group {
                if live.launched, live.sources.isEmpty {
                    // With no source at all, onboarding shows instead.
                    LiveNoSources()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: .topLeading) { leading.padding(8) }
                } else {
                    TimelineView(.periodic(from: .now, by: LiveClock.tick)) { context in
                        content(now: context.date)
                    }
                }
            }
            .background(Palette.ground)
            #if os(macOS)
                // The Mac window is at least 640 pt wide, so the grid keeps 440 pt.
                .frame(minWidth: 640)
            #endif
            .modifier(GuideRequestTaker())
            .modifier(GuideBannerWatch())
            // Another group brings back the whole group (guide-on-iphone-ipad-and-mac/filter-channels-by-typing).
            .onChange(of: live.group) { _, _ in model.filter = "" }
            #if DEBUG
                .onChange(of: model.details) { _, details in
                    if details != nil { UITestingLive.Layout.shared.detailsOpened() }
                }
            #endif
        }

        @ViewBuilder private func content(now: Date) -> some View {
            switch live.status {
            case .channels:
                let data = reading.data(at: now, filtered: true)
                VStack(alignment: .leading, spacing: 12) {
                    toolbar(data, now: now)
                    GuideBannerList(banners: reading.banners())
                    GuideScrollGrid(data: data, now: now)
                }
                .padding(20)
                .background { shortcuts(data, now: now) }
            case let status:
                VStack(alignment: .leading, spacing: 0) {
                    HStack { leading }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(EdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 16))
                    LiveStatusMessage(status: status)
                }
            }
        }

        private func toolbar(_ data: GuideData, now: Date) -> some View {
            @Bindable var model = model
            let days = data.timeline.days(at: now)
            let selected = model.selectedDay(data.timeline, now: now)
            return HStack(spacing: 12) {
                leading
                GuideBoard.FilterField(text: $model.filter)
                    .focused($filterFocused)
                GuideBoard.Days {
                    ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                        GuideBoard.DayChip(title: data.timeline.dayLabel(day, today: now), isSelected: index == selected) {
                            model.pick(day: index, timeline: data.timeline, now: now)
                        }
                        .accessibilityIdentifier("guide.day.\(index)")
                    }
                }
                .frame(minWidth: 80)
                GuideBoard.NowButton { model.showNow(playing: reading.playingKey) }
                GuideBoard.ZoomButtons(
                    canZoomOut: model.zoom.canZoomOut, canZoomIn: model.zoom.canZoomIn, zoomOut: model.zoomOut, zoomIn: model.zoomIn)
                Spacer(minLength: 0)
                GuideNowPlayingItem()
            }
            .frame(height: 44)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("guide.toolbar")
        }

        /// The grid's keys, as key commands so they work wherever focus is:
        /// Command-F to the filter, Command-Plus and Command-Minus to zoom,
        /// and outside the filter the arrows move the cursor and Return
        /// opens its details.
        private func shortcuts(_ data: GuideData, now: Date) -> some View {
            ZStack {
                Button("Filter channels") { filterFocused = true }
                    .keyboardShortcut("f", modifiers: .command)
                Button("Zoom in") { model.zoomIn() }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Zoom in") { model.zoomIn() }
                    .keyboardShortcut("=", modifiers: .command)
                Button("Zoom out") { model.zoomOut() }
                    .keyboardShortcut("-", modifiers: .command)
                Group {
                    Button("Up") { move(.up, data, now: now) }
                        .keyboardShortcut(.upArrow, modifiers: [])
                    Button("Down") { move(.down, data, now: now) }
                        .keyboardShortcut(.downArrow, modifiers: [])
                    Button("Earlier") { move(.left, data, now: now) }
                        .keyboardShortcut(.leftArrow, modifiers: [])
                    Button("Later") { move(.right, data, now: now) }
                        .keyboardShortcut(.rightArrow, modifiers: [])
                    Button("Open details") { openCursor(data) }
                        .keyboardShortcut(.return, modifiers: [])
                }
                .disabled(filterFocused || model.details != nil)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }

        private func move(_ direction: GuideCursorMove, _ data: GuideData, now: Date) {
            // The cursor starts on what is on now, or at the left edge of a later day.
            model.moveCursor(direction, data, playing: reading.playingKey, start: max(model.time ?? now, now))
            if let cursor = model.cursor { model.reveal(cursor) }
        }

        private func openCursor(_ data: GuideData) {
            guard let cursor = model.cursor, reading.cell(cursor, data)?.programme != nil else { return }
            model.open(cursor)
        }
    }

    /// The programme details in the popover (guide-on-iphone-ipad-and-mac/read-about-a-programme).
    struct GuideDetailsPopover: View {
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
                    GuideBoard.Details.Popover(details: details, reminder: reading.reminder(target, data, reminders, now: context.date)) {
                        reading.watch(target, data: data, now: context.date)
                        openLive()
                    } close: {
                        model.closeDetails()
                    }
                    .presentationCompactAdaptation(.popover)
                    .onAppear {
                        AccessibilityNotification.Announcement("\(details.title), details").post()
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    /// What plays in Live, in the toolbar; nothing while nothing plays
    /// (guide-on-iphone-ipad-and-mac/playback-carries-on-out-of-sight).
    struct GuideNowPlayingItem: View {
        @Environment(LiveModel.self) private var live
        @Environment(\.guideBoardOpenLive) private var openLive

        var body: some View {
            if let channel = live.playing {
                TimelineView(.periodic(from: .now, by: LiveClock.tick)) { context in
                    let text = GuideNowPlaying.text(for: channel, live: live, at: context.date)
                    GuideBoard.NowPlayingChip(
                        channel: text.channel, isPlaying: live.playback == .playing, progress: text.progress, open: openLive
                    ) {
                        GuideBoardLogo(channel: channel, look: .playing)
                    }
                }
            }
        }
    }

    extension GuideNowPlaying {
        @MainActor static func text(for channel: Channel, live: LiveModel, at date: Date) -> GuideNowPlaying {
            GuideNowPlaying(
                channel: channel.name, number: RowKey(channel).flatMap(live.catalogue.channelNumber(for:)) ?? channel.channelNumber,
                state: live.programmes.state(channel), current: live.programmes.current(channel, date), now: date)
        }
    }

    /// The failed-guide and waiting banners above the grid or the rows.
    struct GuideBannerList: View {
        let banners: [GuideBanner]
        @Environment(LiveModel.self) private var live
        @Environment(GuideBoardModel.self) private var model

        var body: some View {
            if !banners.isEmpty {
                VStack(spacing: 8) {
                    ForEach(banners) { banner in
                        switch banner.kind {
                        case .failed:
                            Browse.FailureBanner(
                                text: banner.text, identifier: "guide.banner.failed",
                                retry: { live.programmes.refresh(banner.id) },
                                dismiss: { model.dismissBanner(banner.id) })
                        case .waiting:
                            Browse.WaitingNote(text: banner.text)
                                .accessibilityIdentifier("guide.banner.waiting.\(banner.id.uuidString)")
                        }
                    }
                }
            }
        }
    }

    /// Lets a dismissed failed-guide banner come back on a new failure.
    struct GuideBannerWatch: ViewModifier {
        @Environment(LiveModel.self) private var live
        @Environment(GuideBoardModel.self) private var model

        func body(content: Content) -> some View {
            TimelineView(.periodic(from: .now, by: LiveClock.tick)) { _ in
                let failed = Set(GuideBoardReading(live: live, model: model).failedSources().map(\.id))
                content.onChange(of: failed, initial: true) { _, ids in model.failedSourcesChanged(to: ids) }
            }
        }
    }

    /// Opens the guide at a programme another screen asked for
    /// (guide-on-iphone-ipad-and-mac/open-at-a-programme): in All channels
    /// when the current group does not hold its channel, at now when the
    /// programme cannot be found. It does not try again later.
    struct GuideRequestTaker: ViewModifier {
        @Environment(LiveModel.self) private var live
        @Environment(GuideBoardModel.self) private var model

        func body(content: Content) -> some View {
            content.task(id: model.request) {
                guard let request = model.request else { return }
                model.request = nil
                let reading = GuideBoardReading(live: live, model: model)
                let now = Date.now
                let matches = { (key: RowKey) in reading.channel(key).flatMap(GuideLookup.key(for:)) == request.guideKey }
                if !live.catalogue.rows(in: live.group).contains(where: matches), live.catalogue.rows(in: .all).contains(where: matches) {
                    live.show(.all)
                }
                let data = reading.data(at: now, filtered: false)
                let target = GuideBoardModel.target(for: request, rows: data.rows, channel: reading.channel) { key, window in
                    data.cells(key, window)
                }
                model.open(at: target, playing: reading.playingKey)
            }
        }
    }
#endif
