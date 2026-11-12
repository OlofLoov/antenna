#if os(iOS) || os(macOS)
    import AntennaCore
    import Foundation

    /// A banner over the guide (guide-on-iphone-ipad-and-mac/channels-with-gaps-or-no-guide).
    struct GuideBanner: Identifiable, Equatable {
        enum Kind: Equatable {
            /// "Could not load the guide for Home", with Retry and dismiss.
            case failed
            /// "Cabin: waiting for its login to sync from iCloud".
            case waiting
        }

        let id: UUID
        let kind: Kind
        let text: String
    }

    /// What both guide layouts read from Live and the guide model: the
    /// current group's rows and cells, a cell's details, the banners, and
    /// what Watch does.
    @MainActor
    struct GuideBoardReading {
        let live: LiveModel
        let model: GuideBoardModel

        /// The current group's rows, narrowed by the filter when `filtered`.
        func data(at now: Date, filtered: Bool) -> GuideData {
            let filter = ChannelFilter(filtered ? model.filter : "")
            // Matched as Live's list and Search match (guide-on-iphone-ipad-and-mac/filter-channels-by-typing).
            let rows = filter.isEmpty ? live.catalogue.rows(in: live.group) : live.catalogue.rows(in: live.group, matching: filter)
            return .live(rows: rows, channel: live.catalogue.channel(for:), guide: live.programmes, now: now)
        }

        var playingKey: RowKey? { live.playing.flatMap(RowKey.init) }

        func channel(_ key: RowKey) -> Channel? { live.catalogue.channel(for: key) }

        func number(_ key: RowKey) -> Int? { live.catalogue.number(for: key) ?? channel(key)?.number }

        /// The cell `target` names, read again around its start.
        func cell(_ target: GuideTarget, _ data: GuideData) -> GuideCell? {
            let around = DateInterval(start: target.start, duration: GuideTimeline.column)
            return data.cells(target.key, around).first { $0.start == target.start }
                ?? data.cells(target.key, around).first { $0.segment.contains(target.start) }
        }

        /// The details for `target` (guide-on-iphone-ipad-and-mac/read-about-a-programme).
        func details(_ target: GuideTarget, _ data: GuideData, now: Date) -> GuidePanel.Details? {
            guard let cell = cell(target, data), let channel = channel(target.key) else { return nil }
            return GuideText.details(cell, channel: channel, timeline: data.timeline, now: now, quality: nil)
        }

        /// Plays `key` in Live in the same group: a later programme plays
        /// the channel now and shows the programme as Later
        /// (guide-on-iphone-ipad-and-mac/start-watching-from-the-guide).
        /// Live starts, resumes or keeps the channel as its state needs.
        func watch(_ key: RowKey, programme: Programme?, now: Date) {
            guard let channel = channel(key) else { return }
            if let programme, programme.start > now {
                live.pick(channel, later: programme)
            } else {
                live.pick(channel)
            }
            model.closeDetails()
        }

        /// A failed-guide banner for each source with channels whose first
        /// guide load failed, unless dismissed, and a waiting banner for each
        /// source still waiting for its login.
        func banners() -> [GuideBanner] {
            let failed = failedSources().filter { !model.dismissedBanners.contains($0.id) }.map { source in
                GuideBanner(id: source.id, kind: .failed, text: "Could not load the guide for \(source.name)")
            }
            let waiting = live.sources.filter { $0.state == .waitingForLogin }.map { source in
                GuideBanner(id: source.id, kind: .waiting, text: "\(source.name): waiting for its login to sync from iCloud")
            }
            return failed + waiting
        }

        /// Sources with a channel on this device whose guide failed to load.
        func failedSources() -> [LiveSource] {
            live.sources.filter { source in
                guard let channel = live.channels.first(where: { $0.sourceID == source.id }) else { return false }
                if case .failed = live.programmes.state(channel) { return true }
                return false
            }
        }

        /// The details' Watch for `target`.
        func watch(_ target: GuideTarget, data: GuideData, now: Date) {
            watch(target.key, programme: cell(target, data)?.programme, now: now)
        }

        /// Remind me for a programme that has not started, nil otherwise
        /// (programme-reminders/remind-me-appears-only-before-a-programme-starts).
        func reminder(
            _ target: GuideTarget, _ data: GuideData, _ reminders: ReminderCenter?, now: Date
        ) -> GuideBoard.Details.ReminderToggle? {
            guard let reminders, let programme = cell(target, data)?.programme, let channel = channel(target.key) else { return nil }
            guard reminders.offers(programme, on: channel, now: now) else { return nil }
            return GuideBoard.Details.ReminderToggle(isSet: reminders.isSet(programme, on: channel)) {
                reminders.toggle(programme, on: channel)
            }
        }
    }

    extension GuideBoardModel {
        /// The keyboard cursor moves one row or one cell
        /// (guide-on-iphone-ipad-and-mac/read-about-a-programme). With none
        /// yet it starts on the playing channel's row, or the first, at
        /// `start`.
        func moveCursor(_ move: GuideCursorMove, _ data: GuideData, playing: RowKey?, start: Date) {
            guard !data.rows.isEmpty else { return }
            let window = DateInterval(start: start.addingTimeInterval(-GuideCell.reach), duration: GuideCell.reach * 2)
            guard let cursor, let row = data.rows.firstIndex(of: cursor.key) else {
                let key = playing.flatMap { data.rows.contains($0) ? $0 : nil } ?? data.rows[0]
                let cell = data.cells(key, window).first { $0.segment.contains(start) }
                self.cursor = GuideTarget(key: key, start: cell?.start ?? start)
                return
            }
            switch move {
            case .up, .down:
                let next = min(max(row + (move == .up ? -1 : 1), 0), data.rows.count - 1)
                let key = data.rows[next]
                let at = max(cursor.start, start)
                let cell = data.cells(key, window).first { $0.segment.contains(at) }
                self.cursor = GuideTarget(key: key, start: cell?.start ?? at)
            case .left, .right:
                let around = DateInterval(start: cursor.start.addingTimeInterval(-GuideCell.reach), duration: GuideCell.reach * 2)
                let cells = data.cells(cursor.key, around)
                guard let index = cells.firstIndex(where: { $0.start == cursor.start }) else { return }
                let next = index + (move == .left ? -1 : 1)
                guard cells.indices.contains(next) else { return }
                self.cursor = GuideTarget(key: cursor.key, start: cells[next].start)
            }
        }
    }

    /// An arrow key in the grid.
    enum GuideCursorMove: Equatable {
        case up, down, left, right
    }
#endif
