#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// The info bar for the channel `ZapBarModel` describes, along the bottom
    /// of the full-screen picture (`TV-ZapBar` and its state boards): which
    /// channel and where it sits in the current list, what is on and next,
    /// the LIVE and quality badges from the engine, and the catch-up footer.
    struct ZapBarView: View {
        let channel: Channel
        let catalogue: Catalogue<PersistentIdentifier>
        /// The list the channel is counted in.
        let list: CatalogueGroup
        let guide: OverlayGuide
        let engine: any PlaybackEngine
        /// Where the picture is in the buffer.
        let timeshift: TimeshiftModel

        @State private var state: PlaybackState = .idle
        @State private var presentation: PresentationInfo?

        var body: some View {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                // The programme at the picture's time (timeshift-catch-up-and-start-over/pause-live-tv-and-pick-up-where-you-left-off).
                let shown = rewinds ? timeshift.shownTime ?? context.date : context.date
                let panel = guide.panel(for: channel, at: shown)
                let line = ZapBarText.line(state: guide.state(channel), current: panel.now, now: shown)
                ZapBar.Bar(height: rewinds ? 274 : 236) {
                    ZapBar.ChannelIdentity(number: number, name: channel.name, position: position) {
                        logo
                    }
                } nowPlaying: {
                    VStack(alignment: .leading, spacing: 14) {
                        ZapBar.NowPlaying(content: content(line, now: panel.now, next: panel.next.first))
                        if rewinds {
                            Timeshift.Row(
                                isPaused: state == .paused, time: Self.time(shown), marker: timeshift.markerFraction ?? 1,
                                gaps: timeshift.gaps, behind: timeshift.behindText)
                        }
                    }
                } status: {
                    ZapBar.Status(
                        badges: badges,
                        catchUp: channel.catchUpFooter, hint: rewinds ? TimeshiftText.liveHint : ZapBarText.browseHint,
                        live: rewinds ? .behind : .live)
                }
                .accessibilityLabel(spoken(line))
            }
            .task(id: channel) {
                // VoiceOver reads the channel, programme and time left once per change.
                let now = Date.now
                AccessibilityNotification.Announcement(
                    spoken(ZapBarText.line(state: guide.state(channel), current: guide.current(channel, now), now: now))
                ).post()
            }
            .task {
                for await value in await engine.states() { state = value }
            }
            .task {
                for await value in await engine.presentation() { presentation = value }
            }
        }

        /// LIVE and the quality badges; CATCH-UP in place of LIVE while catch-up plays
        /// (timeshift-catch-up-and-start-over/start-the-programme-from-the-beginning).
        private var badges: [String] {
            let list = ZapBarText.badges(state: rewinds ? .playing : state, presentation: presentation)
            guard timeshift.catchup != nil else { return list }
            return [ZapBar.Status.catchUp] + list.filter { $0 != "LIVE" }
        }

        /// The rewind row shows while paused or behind live on a channel that records.
        private var rewinds: Bool {
            timeshift.showsRewindRow
        }

        private var key: RowKey? { RowKey(channel) }

        private var number: ChannelNumber? { key.flatMap(catalogue.channelNumber(for:)) ?? channel.channelNumber }

        /// "Sport · 4 of 42", or nil when the channel is in no list yet.
        private var position: String? {
            guard let key, let (index, count) = catalogue.position(of: key, in: list) else { return nil }
            return ZapBarText.position(list: catalogue.label(of: list), index: index, count: count)
        }

        private func content(_ line: GuideLine, now: Programme?, next: Programme?) -> ZapBar.NowPlaying.Content {
            guard case .programme(let title, let progress, let remaining) = line, let now else { return .message(line.text) }
            let times = "\(Self.time(now.start)) – \(Self.time(now.stop))"
            return .programme(
                title: title, times: times, progress: progress, next: next.map { "\(Self.time($0.start)) · \($0.title)" },
                remaining: remaining)
        }

        /// What VoiceOver reads once as the bar appears: channel, programme, time left.
        private func spoken(_ line: GuideLine) -> String {
            var parts = [number.map(String.init), channel.name].compactMap(\.self)
            parts.append(line.text)
            if case .programme(_, _, let remaining) = line { parts.append(remaining) }
            return parts.joined(separator: ", ")
        }

        private static func time(_ date: Date) -> String {
            date.formatted(date: .omitted, time: .shortened)
        }

        @ViewBuilder private var logo: some View {
            let initials = ZapBar.Initials(text: Channel.initials(for: channel.name))
            LogoImage(url: channel.logoURL) { initials }
        }
    }
#endif
