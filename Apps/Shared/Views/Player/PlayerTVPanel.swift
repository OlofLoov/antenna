#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// Where focus is inside the Apple TV info panel.
    enum PanelFocus: Hashable {
        case segment(PanelTab)
        /// A track row by its id, or `TrackMenu.offID`.
        case track(String)
    }

    /// The info panel over the playing picture, opened by holding select
    /// (player-controls-and-playback-errors/see-what-s-on-without-stopping-the-picture-on-apple-tv):
    /// Info, Audio and Subtitles, read from the player model and the guide.
    struct PlayerTVPanel: View {
        let player: PlayerModel
        let channel: Channel
        let catalogue: Catalogue<PersistentIdentifier>
        let guide: OverlayGuide
        let focus: FocusState<ShellFocus?>.Binding

        var body: some View {
            let tab = player.panel ?? .info
            InfoPanel.Frame {
                ForEach(PanelTab.allCases, id: \.self) { item in
                    InfoPanel.Segment(title: item.title, isSelected: item == tab) { player.panel = item }
                        .focused(focus, equals: .panel(.segment(item)))
                        .accessibilityIdentifier("player.panel.segment.\(item.identifier)")
                }
            } content: {
                switch tab {
                case .info:
                    TimelineView(.everyMinute) { context in
                        info(at: context.date)
                    }
                case .audio:
                    tracks(player.audioRows, empty: nil) { player.selectAudio($0) }
                case .subtitles:
                    tracks(player.subtitleRows, empty: TrackMenu.noSubtitles) { player.selectSubtitle($0) }
                }
            }
        }

        private func info(at date: Date) -> some View {
            let panel = guide.panel(for: channel, at: date)
            let line = ZapBarText.line(state: guide.state(channel), current: panel.now, now: date)
            var programme: InfoPanel.Info<ChannelLogo>.Programme?
            if case .programme(let title, let progress, let remaining) = line, let now = panel.now {
                let times = "\(Self.time(now.start)) – \(Self.time(now.stop)) · \(remaining)"
                programme = .init(title: title, times: times, progress: progress, summary: now.summary)
            }
            return InfoPanel.Info(
                number: RowKey(channel).flatMap(catalogue.channelNumber(for:)) ?? channel.channelNumber, channel: channel.name,
                source: player.subject?.source ?? PlayerModel.unnamedSource, programme: programme, message: line.text,
                badges: ZapBarText.badges(state: player.state, presentation: player.presentation), stream: player.streamLine
            ) {
                ChannelLogo(channel: channel)
            }
        }

        @ViewBuilder
        private func tracks(_ rows: [TrackRow], empty: String?, pick: @escaping (String) -> Void) -> some View {
            if rows.isEmpty, let empty {
                InfoPanel.Empty(text: empty)
            } else {
                InfoPanel.Tracks {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        InfoPanel.TrackButton(name: row.name, detail: row.detail, isSelected: row.isSelected) { pick(row.id) }
                            .focused(focus, equals: .panel(.track(row.id)))
                            .accessibilityIdentifier("player.panel.track.\(index)")
                    }
                }
            }
        }

        private static func time(_ date: Date) -> String {
            date.formatted(date: .omitted, time: .shortened)
        }
    }

    /// The channel's logo, or its initials while there is none
    /// (design-system/channels-without-a-logo-show-initials).
    struct ChannelLogo: View {
        let channel: Channel

        var body: some View {
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
