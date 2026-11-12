#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// Focus inside the guide besides the grid, which holds the shell's `.content`.
    enum GuideFocus: Hashable {
        case day(Int)
        /// Right of the last chip; taking it moves focus to Watch.
        case pastLastDay
        case watch
        /// Remind me, right of Watch (programme-reminders capability).
        case remind
    }

    /// The Guide tab on Apple TV (tv-guide-grid capability; `TV-Guide` and its
    /// state boards): the playing channel in the shell's small picture with
    /// its caption, the panel for the highlighted block, the day chips and
    /// the grid of the current group. The grid is one focusable holder; the
    /// model moves the highlight, so focus follows the rules in design.md.
    struct GuideScreen: View {
        let shell: ShellModel
        let catalogue: Catalogue<PersistentIdentifier>
        let overlay: ChannelOverlayModel
        let guide: OverlayGuide
        let focus: FocusState<ShellFocus?>.Binding

        @State private var model = GuideModel()
        @State private var opened = false
        @State private var engineState: PlaybackState = .idle
        @State private var presentation: PresentationInfo?
        @FocusState private var local: GuideFocus?
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
        @Environment(\.reminders) private var reminders
        @Query private var preferences: [PreferencesRecord]

        var body: some View {
            TimelineView(.everyMinute) { context in
                screen(data(at: context.date), now: context.date)
            }
            .task(id: shell.guideRequest) {
                if let request = shell.guideRequest {
                    shell.guideRequest = nil
                    if open(at: request) { return }
                }
                guard !opened else { return }
                let now = Date.now
                let data = data(at: now)
                model.open(data, playing: playingKey, now: now)
                opened = true
                if data.rows.isEmpty { local = .day(model.selectedDay(data, now: now)) }
            }
            .task {
                for await value in await shell.engine.states() { engineState = value }
            }
            .task {
                for await value in await shell.engine.presentation() { presentation = value }
            }
            .onChange(of: hours) { _, _ in model.fit(data(at: .now)) }
            .onChange(of: local) { _, new in localFocusMoved(to: new) }
            .onChange(of: focus.wrappedValue) { _, new in
                guard new == .content, model.area != .grid else { return }
                let data = data(at: .now)
                if model.area == .days { model.leaveDays(data) } else { model.leaveWatch(data) }
            }
            .onChange(of: model.highlight) { _, _ in
                // Focus stays on the holder, so VoiceOver hears each new block read out.
                guard voiceOver, model.area == .grid else { return }
                AccessibilityNotification.Announcement(spokenHighlight(data(at: .now), now: .now)).post()
            }
        }

        // MARK: Layout

        private func screen(_ data: GuideData, now: Date) -> some View {
            GuideGrid.Screen {
                GuidePanel.PictureCaption(caption: caption, look: pictureLook)
            } panel: {
                panel(data, now: now)
            } grid: {
                GuideGrid.Grid(columns: data.timeline.columns(from: model.windowStart).map(GuideText.time), now: nowMark(data, now)) {
                    days(data, now: now)
                } rows: {
                    if data.rows.isEmpty {
                        GuideGrid.Empty(text: "No channels in \(catalogue.label(of: group))")
                    } else {
                        ZStack(alignment: .topLeading) {
                            holder(data, now: now)
                            if opened {
                                GuideRows(data: data, model: model, catalogue: catalogue, playing: playingKey, now: now)
                                    .allowsHitTesting(false)
                                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.windowStart)
                            }
                        }
                    }
                }
            }
        }

        @ViewBuilder
        private func panel(_ data: GuideData, now: Date) -> some View {
            if opened, let target = highlighted(data) {
                let quality = target.key == playingKey ? pictureQuality : nil
                GuidePanel.Panel(
                    date: now,
                    details: GuideText.details(target.cell, channel: target.channel, timeline: data.timeline, now: now, quality: quality)
                ) {
                    GuidePanel.WatchButton { tune(model.watch(data)) }
                        .focused($local, equals: .watch)
                        .disabled(model.area == .grid)
                        .onExitCommand { backFromWatch() }
                        .accessibilityIdentifier("guide.watch")
                    remindButton(target, now: now)
                }
            } else {
                GuidePanel.ClockOnly(date: now)
            }
        }

        private func days(_ data: GuideData, now: Date) -> some View {
            let days = data.timeline.days(at: now)
            let selected = model.selectedDay(data, now: now)
            return ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(Array(zip(days.indices, days)), id: \.0) { index, day in
                        GuideGrid.DayChip(title: data.timeline.dayLabel(day, today: now), look: index == selected ? .selected : .plain) {
                            model.pick(day: index, data, now: now)
                        }
                        .focused($local, equals: .day(index))
                        .accessibilityIdentifier("guide.day.\(index)")
                    }
                    Color.clear
                        .frame(width: 1, height: 36)
                        .focusable(model.area == .days)
                        .focused($local, equals: .pastLastDay)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 20)
            }
            .scrollClipDisabled()
            .scrollIndicators(.hidden)
            .disabled(model.area != .days)
            .focusSection()
        }

        /// The one focusable element over the rows. Its label is the
        /// highlighted block, so VoiceOver reads what the highlight is on.
        private func holder(_ data: GuideData, now: Date) -> some View {
            Button {
                let selection = model.select(data, now: now)
                if selection == .watch { local = .watch } else { tune(selection) }
            } label: {
                Color.clear
            }
            .buttonStyle(GuideHolderStyle())
            .focused(focus, equals: .content)
            .onMoveCommand { direction in move(direction, data) }
            .accessibilityLabel(spokenHighlight(data, now: now))
            .accessibilityIdentifier("guide.grid")
        }

        /// Remind me right of Watch for a programme that has not started
        /// (programme-reminders/remind-me-appears-only-before-a-programme-starts).
        /// Setting it leaves focus where it is.
        @ViewBuilder
        private func remindButton(_ target: HighlightedCell, now: Date) -> some View {
            if let reminders, let programme = target.cell.programme, reminders.offers(programme, on: target.channel, now: now) {
                GuidePanel.RemindButton(isSet: reminders.isSet(programme, on: target.channel)) {
                    reminders.toggle(programme, on: target.channel)
                }
                .focused($local, equals: .remind)
                .disabled(model.area == .grid)
                .onExitCommand { backFromWatch() }
                .accessibilityIdentifier("guide.remind")
            }
        }

        // MARK: Input

        private func move(_ direction: MoveCommandDirection, _ data: GuideData) {
            guard model.area == .grid else { return }
            let move: GuideMove
            switch direction {
            case .up: move = .up
            case .down: move = .down
            case .left: move = .left
            case .right: move = .right
            @unknown default: return
            }
            model.move(move, data)
            if model.area == .days { local = .day(model.selectedDay(data, now: .now)) }
        }

        private func localFocusMoved(to new: GuideFocus?) {
            switch new {
            case .pastLastDay:
                local = .watch
            case .watch, .remind:
                model.toWatch()
            case .day:
                model.focusedDays()
            case nil:
                break
            }
        }

        /// Opens on the programme Search picked, switching the current group
        /// to All channels when its channel is not in it
        /// (tv-guide-grid/open-at-a-programme-found-in-search). False when no
        /// channel has that guide.
        private func open(at request: ProgrammeKey) -> Bool {
            let matches = { (key: RowKey) in catalogue.channel(for: key).flatMap(GuideKey.init(channel:)) == request.guideKey }
            if !catalogue.rows(in: group).contains(where: matches) {
                guard catalogue.rows(in: .all).contains(where: matches) else { return false }
                overlay.tuned(from: .all)
            }
            let data = data(at: .now)
            guard let row = data.rows.firstIndex(where: matches) else { return false }
            model.open(data, row: row, start: request.start)
            opened = true
            focus.wrappedValue = .content
            return true
        }

        /// Menu on Watch: the highlight goes back to the grid and the guide stays.
        private func backFromWatch() {
            let data = data(at: .now)
            model.leaveWatch(data)
            if data.rows.isEmpty {
                local = .day(model.selectedDay(data, now: .now))
            } else {
                focus.wrappedValue = .content
            }
        }

        private func tune(_ selection: GuideModel.Selection) {
            guard case .tune(let key) = selection, let channel = catalogue.channel(for: key) else { return }
            overlay.tuned(from: group)
            Task {
                await shell.pickFromOverlay(channel)
                focus.wrappedValue = .picture
            }
        }

        // MARK: Derived

        /// The current group: the one last tuned from, else the playing
        /// channel's own group, else All channels.
        private var group: CatalogueGroup {
            let chosen = overlay.lastTuned ?? shell.tuned.flatMap(catalogue.sourceGroup(of:)) ?? .all
            return catalogue.groups.contains(chosen) ? chosen : .all
        }

        private var playingKey: RowKey? { shell.tuned.flatMap(RowKey.init) }

        /// The Guide window preference, read again whenever it changes here or
        /// on another device (sources-and-settings/choose-how-the-app-behaves).
        private var hours: Int { PreferencesStore.current(preferences).guideHours }

        private func data(at now: Date) -> GuideData {
            .live(rows: catalogue.rows(in: group), channel: catalogue.channel(for:), guide: guide, now: now, hours: hours)
        }

        private func nowMark(_ data: GuideData, _ now: Date) -> GuideGrid.NowMark? {
            data.timeline.nowLine(at: now, windowStart: model.windowStart).map { GuideGrid.NowMark(offset: $0, time: GuideText.time(now)) }
        }

        private var caption: String {
            guard let channel = shell.tuned else { return "" }
            let number = RowKey(channel).flatMap(catalogue.channelNumber(for:)) ?? channel.channelNumber
            return [number.map(String.init), channel.name].compactMap(\.self).joined(separator: " ")
        }

        private var pictureLook: GuidePanel.PictureLook {
            guard shell.tuned != nil else { return .nothing }
            return engineState == .playing ? .playing : .waiting
        }

        private var pictureQuality: String? {
            guard engineState == .playing else { return nil }
            return presentation?.video.flatMap { QualityBadge.picture(height: $0.height) }
        }

        private func spokenHighlight(_ data: GuideData, now: Date) -> String {
            guard let target = highlighted(data) else { return "Guide" }
            return GuideText.spoken(target.cell, channel: target.channel, now: now)
        }

        /// The highlighted cell with its row and channel.
        private func highlighted(_ data: GuideData) -> HighlightedCell? {
            guard let cell = model.highlightedCell(data), let row = model.highlightedRow(data) else { return nil }
            let key = data.rows[row]
            return catalogue.channel(for: key).map { HighlightedCell(cell: cell, key: key, channel: $0) }
        }
    }

    private struct HighlightedCell {
        let cell: GuideCell
        let key: RowKey
        let channel: Channel
    }

    /// Draws nothing: the highlighted block shows where focus is.
    private struct GuideHolderStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.contentShape(Rectangle())
        }
    }
#endif
