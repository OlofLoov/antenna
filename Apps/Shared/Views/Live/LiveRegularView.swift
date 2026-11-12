#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftData
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
        @Environment(ShelfLibrary.self) private var shelves
        @Environment(ShelfActivity.self) private var activity
        @Environment(ShelfPlayback.self) private var playback
        @Environment(SearchModel.self) private var search
        @State private var section: LiveSection = .live
        /// Movies' or Series' rows or grid; picking a section resets it.
        @State private var browse = ShelfBrowse()
        /// A folded column the user opened over the others.
        @State private var shown: Folded?
        @Query private var records: [SourceRecord]
        /// The last session's section was opened once, at the first appearance.
        @State private var restored = false
        @Environment(\.onboardingHandoff) private var handoff

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
                    .environment(\.playerFailureMetrics, .regular)
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
                // Movies and Series go with the last Xtream source.
                .onChange(of: shelves.hasXtream) { _, has in
                    if !has, section == .movies || section == .series { section = .live }
                }
                .onChange(of: section) { _, new in live.opened(new.session) }
                // Opens on the section the user left (session-restore-and-recently-watched/reopen-on-the-same-tab-and-group).
                .onAppear {
                    guard !restored else { return }
                    restored = true
                    section = LiveSection(live.restoredTab, hasXtream: records.contains { $0.kind == .xtream })
                    // Browse movies in onboarding opens Movies.
                    if handoff?.takeMovies() == true { section = .movies }
                }
            }
            .background(Palette.ground)
            .environment(\.browseMetrics, .regular)
            .environment(\.playerFailureMetrics, .regular)
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
            Browse.Sidebar(eyebrow: eyebrow) {
                ForEach(sections, id: \.self) { item in
                    sectionRow(item)
                }
            } groups: {
                switch section {
                case .movies: genres(.movie, columns)
                case .series: genres(.series, columns)
                case .search: SearchSidebarRecents()
                default: liveGroups(columns)
                }
            } footer: {
                sectionRow(.settings)
            }
        }

        /// "Genres" on Movies and Series, "Recent" on Search, "Groups" elsewhere.
        private var eyebrow: String {
            switch section {
            case .movies, .series: "Genres"
            case .search: "Recent"
            default: "Groups"
            }
        }

        /// Movies and Series only with an Xtream source
        /// (movies-and-series-browsing/movies-and-series-appear-when-your-provider-has-them).
        private var sections: [LiveSection] {
            LiveSection.allCases.filter { item in
                item != .settings && (shelves.hasXtream || (item != .movies && item != .series))
            }
        }

        /// My list, All movies or All series, then each genre with its count; the one
        /// whose grid shows is filled
        /// (movies-and-series-browsing/browse-a-genre-or-sort-the-lot).
        @ViewBuilder private func genres(_ kind: ShelfTitle.Kind, _ columns: LiveColumns) -> some View {
            let model = shelves.model(kind)
            genreRow(.myList, count: activity.myList(model).count, kind: kind)
            genreRow(.all, count: model.titles.count, kind: kind)
            ForEach(Shelf.genres(model.rows)) { genre in
                genreRow(.genre(genre.name), count: genre.count, kind: kind)
            }
        }

        private func genreRow(_ list: ShelfList, count: Int, kind: ShelfTitle.Kind) -> some View {
            Browse.GroupRow(title: list.name(kind), systemImage: nil, count: count, isSelected: browse.list == list) {
                browse.pick(list)
                shown = nil
            }
            .accessibilityIdentifier("\(kind.prefix).genres.\(list.identifier)")
        }

        @ViewBuilder private func liveGroups(_ columns: LiveColumns) -> some View {
            ForEach(Array(live.catalogue.groups.enumerated()), id: \.element) { index, group in
                Browse.GroupRow(
                    title: group.label, systemImage: group.systemImage, count: live.catalogue.count(of: group),
                    isSelected: section == .live && group == live.group
                ) {
                    live.show(group)
                    section = .live
                    shown = columns == .picture ? .list : nil
                }
                .groupSpokenLabel(group, count: live.catalogue.count(of: group))
                .accessibilityIdentifier("browse.group.\(index)")
            }
            ForEach(live.sources.filter { $0.state == .waitingForLogin }) { source in
                Text("\(source.name) · waiting for login")
                    .font(.callout)
                    .foregroundStyle(Palette.textMuted)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 36)
                    .accessibilityIdentifier("browse.group.waiting.\(source.id.uuidString)")
            }
        }

        private func sectionRow(_ item: LiveSection) -> some View {
            Browse.SectionRow(title: item.title, systemImage: item.systemImage, isSelected: section == item) {
                section = item
                browse = ShelfBrowse()
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
                    liveColumns(columns)
                        .onAppear { live.appeared() }
                        .onDisappear { live.restore.liveShown = false }
                }
            case .guide:
                folded(columns) { GuideView() }
            case .movies:
                ShelfRegularScreen(kind: .movie, browse: $browse) { sidebarButton(columns) }
                    .environment(\.openSearch, searchOpener)
            case .series:
                ShelfRegularScreen(kind: .series, browse: $browse) { sidebarButton(columns) }
                    .environment(\.openSearch, searchOpener)
            case .search:
                SearchRegularScreen { sidebarButton(columns) }
                    .modifier(SearchSupply(picks: searchPicks))
            case .settings:
                folded(columns) { SettingsView() }
            }
        }

        /// A channel or programme plays in Live; a movie plays and a series
        /// opens its page, as from the Movies section
        /// (search/pick-a-channel-or-title-to-watch).
        private var searchPicks: SearchPicks {
            SearchPicks(
                channel: { watch($0) },
                programme: { hit, channel in
                    guard !hit.isOnNow else { return watch(channel) }
                    watch(channel)
                    live.pick(channel, later: hit.programme)
                },
                title: { title in
                    switch title.kind {
                    case .movie: playback.play(title, library: shelves, activity: activity)
                    case .series: shelves.openPage(title, from: .search, in: title.kind)
                    }
                })
        }

        /// Typing in the Movies or Series toolbar field opens Search set to
        /// that kind with the text carried over.
        private var searchOpener: SearchOpener {
            SearchOpener { kind, text in
                search.start(kind == .movie ? .movies : .series, text: text)
                section = .search
            }
        }

        /// Shows Live with `channel` playing, in All channels when the open
        /// group does not hold it. Search keeps its query.
        private func watch(_ channel: Channel) {
            if let key = RowKey(channel), !live.catalogue.rows(in: live.group).contains(key) { live.show(.all, picked: false) }
            live.pick(channel)
            section = .live
        }

        /// The channel list and the picture with its details.
        private func liveColumns(_ columns: LiveColumns) -> some View {
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
                switch live.status {
                case .channels(let banner, _):
                    let count = live.catalogue.count(of: live.group)
                    if let banner {
                        Browse.FailureBanner(text: banner, retry: live.retry, dismiss: live.dismissBanner)
                            .padding(EdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 16))
                    }
                    Browse.ListHeader(title: live.group.label, count: count == 1 ? "1 channel" : "\(count) channels") {
                        leading
                    } filter: {
                        Browse.FilterField(text: $live.filter)
                            .focused($filterFocused)
                    }
                    LiveChannelList(
                        picked: {
                            filterFocused = false
                            picked()
                        }, cursor: cursor)
                case let status:
                    HStack { leading }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(EdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 16))
                    LiveStatusMessage(status: status)
                }
            }
            .background { shortcuts }
            .onChange(of: live.group) { _, _ in cursor = nil }
            .onChange(of: live.filter) { _, _ in cursor = nil }
            .onChange(of: filterFocused) { _, focused in live.typing = focused }
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
                        LiveLaterRow()
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
