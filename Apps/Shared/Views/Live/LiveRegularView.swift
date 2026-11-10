#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// Which columns an iPad or Mac window shows side by side
    /// (live-tv-on-iphone-ipad-mac/sidebar-list-and-picture-side-by-side).
    /// The others fold behind buttons; the list is never stacked with the picture.
    enum LiveColumns: Equatable {
        /// Sidebar 232, list 352, picture in the rest: 904 pt and wider.
        case all
        /// The sidebar folds below 904 pt.
        case listAndPicture
        /// The list folds below 672 pt.
        case picture

        init(width: CGFloat) {
            switch width {
            case 904...: self = .all
            case 672..<904: self = .listAndPicture
            default: self = .picture
            }
        }
    }

    /// A section of the iPad and Mac sidebar.
    enum LiveSection: Hashable, CaseIterable {
        case live, guide, movies, series, search, settings

        var title: String {
            switch self {
            case .live: "Live"
            case .guide: "Guide"
            case .movies: "Movies"
            case .series: "Series"
            case .search: "Search"
            case .settings: "Sources & Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .live: "tv"
            case .guide: "list.bullet.rectangle"
            case .movies: "film"
            case .series: "square.grid.2x2"
            case .search: "magnifyingglass"
            case .settings: "gearshape"
            }
        }

        /// `browse.section.<identifier>`.
        var identifier: String {
            switch self {
            case .live: "live"
            case .guide: "guide"
            case .movies: "movies"
            case .series: "series"
            case .search: "search"
            case .settings: "settings"
            }
        }
    }

    /// The iPad and Mac window (board `iPad`, `iPad-Collapsed`,
    /// `iPad-Collapsed-Narrow`): the sidebar, the channel list and the
    /// picture with its details side by side, folding as the window narrows.
    struct LiveRegularView: View {
        @Environment(LiveModel.self) private var live
        @State private var section: LiveSection = .live
        /// A folded column the user opened over the others.
        @State private var shown: Folded?

        enum Folded { case sidebar, list }

        var body: some View {
            if live.fullScreen {
                // The picture fills the window (live-tv-on-iphone-ipad-mac/full-screen);
                // Escape leaves (live-tv-on-iphone-ipad-mac/keyboard-shortcuts).
                LivePicture()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .ignoresSafeArea()
                    .environment(\.browseMetrics, .regular)
                    .background {
                        #if os(iOS)
                            LiveEscapeKey { live.setFullScreen(false) }
                                .frame(width: 0, height: 0)
                                .accessibilityHidden(true)
                        #else
                            Button("Exit full screen") { live.setFullScreen(false) }
                                .keyboardShortcut(.cancelAction)
                                .frame(width: 0, height: 0)
                                .opacity(0)
                                .accessibilityHidden(true)
                        #endif
                    }
            } else {
                columns
            }
        }

        private var columns: some View {
            GeometryReader { proxy in
                let columns = LiveColumns(width: proxy.size.width)
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        if columns == .all {
                            sidebar(columns)
                            divider
                        }
                        content(columns)
                    }
                    if shown != nil, columns != .all {
                        Palette.scrimTint.opacity(0.55)
                            .ignoresSafeArea()
                            .onTapGesture { shown = nil }
                            .accessibilityHidden(true)
                    }
                    if shown == .sidebar, columns != .all {
                        sidebar(columns)
                            .transition(.move(edge: .leading))
                    } else if shown == .list, columns == .picture {
                        LiveListColumn(leading: { EmptyView() }, picked: { shown = nil })
                            .frame(width: 352)
                            .background(Palette.ground)
                            .transition(.move(edge: .leading))
                    }
                }
                .animation(.easeOut(duration: 0.2), value: shown)
                .onChange(of: columns) { _, _ in shown = nil }
            }
            .background(Palette.ground)
            .environment(\.browseMetrics, .regular)
            .overlay {
                #if DEBUG
                    UITestingLive.Probe(engine: live.engine)
                #endif
            }
        }

        private var divider: some View {
            Rectangle().fill(Palette.surface(0.08)).frame(width: 1).ignoresSafeArea()
        }

        private func sidebar(_ columns: LiveColumns) -> some View {
            Browse.Sidebar {
                ForEach(LiveSection.allCases.filter { $0 != .settings }, id: \.self) { item in
                    sectionRow(item)
                }
            } groups: {
                ForEach(Array(live.catalogue.groups.enumerated()), id: \.element) { index, group in
                    Browse.GroupRow(
                        title: group.label, systemImage: group.systemImage, count: live.catalogue.count(of: group),
                        isSelected: section == .live && group == live.group
                    ) {
                        live.show(group)
                        section = .live
                        shown = columns == .picture ? .list : nil
                    }
                    .accessibilityIdentifier("browse.group.\(index)")
                }
            } footer: {
                sectionRow(.settings)
            }
        }

        private func sectionRow(_ item: LiveSection) -> some View {
            Browse.SectionRow(title: item.title, systemImage: item.systemImage, isSelected: section == item) {
                section = item
                shown = nil
            }
            .accessibilityIdentifier("browse.section.\(item.identifier)")
        }

        @ViewBuilder private func content(_ columns: LiveColumns) -> some View {
            switch section {
            case .live:
                if live.launched, live.sources.isEmpty {
                    LiveNoSources()
                } else {
                    HStack(spacing: 0) {
                        if columns != .picture {
                            LiveListColumn(leading: { sidebarButton(columns) }, picked: {})
                                .frame(width: 352)
                            divider
                        }
                        LiveDetailColumn {
                            if columns == .picture {
                                HStack(spacing: 4) {
                                    sidebarButton(columns)
                                    Browse.ToggleButton(title: "Show channel list", systemImage: "list.bullet") { shown = .list }
                                        .accessibilityIdentifier("browse.toggleList")
                                }
                            }
                        }
                    }
                }
            case .guide:
                folded(columns) { GuideView() }
            case .movies, .series, .search:
                folded(columns) {
                    ContentUnavailableView(section.title, systemImage: section.systemImage, description: Text("Not available yet."))
                }
            case .settings:
                folded(columns) { SettingsView() }
            }
        }

        /// Another section's screen, with the sidebar button over it while the sidebar is folded.
        private func folded<Content: View>(_ columns: LiveColumns, @ViewBuilder content: () -> Content) -> some View {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topLeading) {
                    sidebarButton(columns).padding(8)
                }
        }

        @ViewBuilder private func sidebarButton(_ columns: LiveColumns) -> some View {
            if columns != .all {
                Browse.ToggleButton(title: "Show sidebar", systemImage: "sidebar.left") { shown = .sidebar }
                    .accessibilityIdentifier("browse.toggleSidebar")
            }
        }
    }

    /// The channel list column: the group's name and count, then its channels.
    struct LiveListColumn<Leading: View>: View {
        @ViewBuilder var leading: Leading
        /// Called after a row is picked, so a list shown over the picture can close.
        let picked: () -> Void
        @Environment(LiveModel.self) private var live
        @FocusState private var filterFocused: Bool
        /// Where the arrow keys are in the list (live-tv-on-iphone-ipad-mac/keyboard-shortcuts).
        @State private var cursor: RowKey?

        var body: some View {
            @Bindable var live = live
            VStack(spacing: 0) {
                let count = live.catalogue.count(of: live.group)
                Browse.ListHeader(title: live.group.label, count: count == 1 ? "1 channel" : "\(count) channels") {
                    leading
                } filter: {
                    Browse.FilterField(text: $live.filter)
                        .focused($filterFocused)
                }
                if live.channels.isEmpty {
                    ProgressView("Loading channels…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    LiveChannelList(
                        picked: {
                            filterFocused = false
                            picked()
                        }, cursor: cursor)
                }
            }
            .background { shortcuts }
            .onChange(of: live.group) { _, _ in cursor = nil }
            .onChange(of: live.filter) { _, _ in cursor = nil }
        }

        /// The list's keys as key commands, so they work wherever focus is.
        /// Outside the filter field, the arrows move the ring, Return plays
        /// its channel and Space pauses; Command-F jumps to the filter.
        private var shortcuts: some View {
            ZStack {
                Button("Find a channel") { filterFocused = true }
                    .keyboardShortcut("f", modifiers: .command)
                Group {
                    Button("Next channel") { move(1) }
                        .keyboardShortcut(.downArrow, modifiers: [])
                    Button("Previous channel") { move(-1) }
                        .keyboardShortcut(.upArrow, modifiers: [])
                    Button("Play the channel") { playCursor() }
                        .keyboardShortcut(.return, modifiers: [])
                    Button("Pause or play") { live.playPause() }
                        .keyboardShortcut(.space, modifiers: [])
                }
                .disabled(filterFocused)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }

        private func playCursor() {
            guard let cursor, let channel = live.catalogue.channel(for: cursor) else { return }
            live.pick(channel)
            picked()
        }

        /// Moves the focus ring by `step` rows without switching channel,
        /// starting from the playing row or the top.
        private func move(_ step: Int) {
            let rows = live.rows
            guard !rows.isEmpty else { return }
            let start = cursor ?? live.playing.flatMap(RowKey.init)
            guard let start, let index = rows.firstIndex(of: start) else {
                cursor = rows[step > 0 ? 0 : rows.count - 1]
                return
            }
            cursor = rows[min(max(index + step, 0), rows.count - 1)]
        }
    }

    /// The picture with the playing channel's details and what comes next.
    struct LiveDetailColumn<Toggles: View>: View {
        @ViewBuilder var toggles: Toggles
        @Environment(LiveModel.self) private var live

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    toggles
                    LivePicture()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            if live.playing == nil {
                                RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.surface(0.08))
                            }
                        }
                    if let channel = live.playing {
                        LiveDetails(channel: channel)
                    }
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The details panel for the playing channel, with up to three
    /// programmes after the current one.
    struct LiveDetails: View {
        let channel: Channel
        @Environment(LiveModel.self) private var live

        var body: some View {
            TimelineView(.periodic(from: .now, by: LiveClock.tick)) { context in
                let text = live.nowText(for: channel, at: context.date)
                Browse.Panel(
                    channel: channel.name,
                    now: .init(
                        title: text.title, times: text.times, meta: text.meta, summary: text.summary,
                        progress: text.progress),
                    next: text.next.map { .init(time: LiveModel.time($0.start), title: $0.title) }
                ) {
                    Browse.Logo(url: channel.logoURL, initials: Channel.initials(for: channel.name), isSelected: true)
                } trailing: {
                    LiveFavoriteButton(channel: channel)
                        .environment(\.browseMetrics, .regular)
                }
            }
        }
    }
#endif
