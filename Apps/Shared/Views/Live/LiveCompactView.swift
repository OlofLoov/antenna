#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// The Live tab on iPhone and in a narrow iPad Split View
    /// (live-tv-on-iphone-ipad-mac/picture-pinned-at-the-top-on-iphone; board
    /// `iPhone`): the picture across the top, the now-playing line, the group
    /// chips and the channel list. The tab bar is the shell's.
    struct LiveCompactView: View {
        @Environment(LiveModel.self) private var live

        var body: some View {
            Group {
                if live.launched, live.sources.isEmpty {
                    LiveNoSources()
                } else {
                    VStack(spacing: 0) {
                        LivePicture()
                            .frame(maxHeight: live.fullScreen ? .infinity : nil)
                        if !live.fullScreen {
                            if let channel = live.playing {
                                LiveNowPlayingLine(channel: channel)
                            }
                            content
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .ignoresSafeArea(edges: live.fullScreen ? .all : [])
                }
            }
            .background(Palette.ground)
            .fullScreenChrome(live.fullScreen)
            .overlay {
                #if DEBUG
                    UITestingLive.Probe(engine: live.engine)
                #endif
            }
        }

        @ViewBuilder private var content: some View {
            if live.channels.isEmpty {
                ProgressView("Loading channels…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    LiveGroupChips()
                    LiveChannelList()
                }
            }
        }
    }

    extension View {
        /// Hides the tab bar and the status bar while the picture fills the
        /// iPhone screen (live-tv-on-iphone-ipad-mac/full-screen).
        @ViewBuilder func fullScreenChrome(_ on: Bool) -> some View {
            #if os(iOS)
                toolbar(on ? .hidden : .visible, for: .tabBar)
                    .statusBarHidden(on)
                    .persistentSystemOverlays(on ? .hidden : .automatic)
            #else
                self
            #endif
        }
    }

    /// Favorites, All channels and each group as chips; tapping one opens it.
    struct LiveGroupChips: View {
        @Environment(LiveModel.self) private var live

        var body: some View {
            ScrollViewReader { proxy in
                Browse.Chips {
                    ForEach(Array(live.catalogue.groups.enumerated()), id: \.element) { index, group in
                        Browse.Chip(title: group.label, isSelected: group == live.group) {
                            live.show(group)
                        }
                        .id(group)
                        .accessibilityIdentifier("browse.group.\(index)")
                    }
                }
                .onAppear { proxy.scrollTo(live.group) }
            }
        }
    }

    /// What the iPhone line under the picture says about the playing channel.
    struct LiveNowPlayingLine: View {
        let channel: Channel
        @Environment(LiveModel.self) private var live

        var body: some View {
            TimelineView(.periodic(from: .now, by: LiveClock.tick)) { context in
                let text = live.nowText(for: channel, at: context.date)
                Browse.NowPlaying(title: text.title, detail: text.compact) {
                    Browse.Logo(url: channel.logoURL, initials: Channel.initials(for: channel.name), isSelected: true)
                } trailing: {
                    LiveFavoriteButton(channel: channel)
                }
            }
        }
    }
#endif
