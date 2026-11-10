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

        @State private var state: PlaybackState = .idle
        @State private var presentation: PresentationInfo?

        var body: some View {
            TimelineView(.everyMinute) { context in
                let panel = guide.panel(for: channel, at: context.date)
                let line = ZapBarText.line(state: guide.state(channel), current: panel.now, now: context.date)
                ZapBar.Bar {
                    ZapBar.ChannelIdentity(number: number, name: channel.name, position: position) {
                        logo
                    }
                } nowPlaying: {
                    ZapBar.NowPlaying(content: content(line, now: panel.now, next: panel.next.first))
                } status: {
                    ZapBar.Status(
                        badges: ZapBarText.badges(state: state, presentation: presentation), catchUp: channel.catchUpFooter,
                        hint: ZapBarText.browseHint)
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

        private var key: RowKey? { RowKey(channel) }

        private var number: Int? { key.flatMap(catalogue.number(for:)) ?? channel.number }

        /// "Sport · 4 of 42", or nil when the channel is in no list yet.
        private var position: String? {
            guard let key, let (index, count) = catalogue.position(of: key, in: list) else { return nil }
            return ZapBarText.position(list: list.label, index: index, count: count)
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
#endif
