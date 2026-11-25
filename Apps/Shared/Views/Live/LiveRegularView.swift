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

    /// The iPad and Mac window (board `iPad`, `iPad-Collapsed`,
    /// `iPad-Collapsed-Narrow`): the sidebar, the channel list and the
    /// picture with its details side by side, folding as the window narrows.
    struct LiveRegularView: View {
        @Environment(LiveModel.self) private var live
        @Environment(ShelfLibrary.self) private var shelves
        @Environment(ShelfActivity.self) private var activity
        @Environment(SearchModel.self) private var search
        @Environment(GuideBoardModel.self) private var guide
        @State private var section: LiveSection = .live
        /// Movies' or Series' rows or grid; picking a section resets it.
        @State private var browse = ShelfBrowse()
        /// What the user typed over the sidebar's groups; another section clears it.
        @State private var groupQuery = ""
        /// A folded column the user opened over the others.
        @State private var shown: Folded?
        /// The columns the window showed last, kept while the picture is full screen.
        @State private var layout = LiveColumns.all
        @Query private var records: [SourceRecord]
        @Environment(\.sourceRefresher) private var refresher
        /// The last session's section was opened once, at the first appearance.
        @State private var restored = false
        @Environment(\.onboardingHandoff) private var handoff
        @Query private var preferences: [PreferencesRecord]

        enum Folded { case sidebar, list }

        var body: some View {
            Group {
                screen
            }
            .environment(\.openChannelGroups, openGroups)
            // keyboard-commands/menu-items-follow-the-screen-in-front
            .menuCommand(\.playbackCommands, section == .live || live.fullScreen ? LivePlaybackCommands(live: live).commands : nil)
            .menuCommand(\.sectionCommands, sectionCommands)
        }

        /// The Go menu: the sidebar's sections, picked as from the sidebar (keyboard-commands/go-to-a-section).
        private var sectionCommands: SectionCommands {
            SectionCommands(offered: sections + [.settings]) { item in
                live.setFullScreen(false)
                section = item
                browse = ShelfBrowse()
                shown = nil
            }
        }

        @ViewBuilder private var screen: some View {
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
                    .onDisappear(perform: leaveMultiView)
            }
        }

        /// An iPad window turning compact swaps these columns for the tab
        /// bar, which has no grid, so multi-view ends and keeps the selected
        /// tile (multi-view/start-multi-view-on-an-ipad).
        private func leaveMultiView() {
            #if os(iOS)
                guard let multiView = live.multiView else { return }
                Task { await multiView.leave() }
            #endif
        }

        private var columns: some View {
            GeometryReader { proxy in
                let columns = LiveColumns(width: live.multiView == nil ? proxy.size.width : min(proxy.size.width, 903))
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
                .onChange(of: columns, initial: true) { _, new in layout = new }
                // Movies or Series goes when no source offers it.
                .onChange(of: shelves.offer) { _, offer in
                    if !section.isOffered(by: offer) { section = .live }
                }
                .onChange(of: section) { _, new in
                    live.opened(new.session)
                    groupQuery = ""
                }
                // Opens on the section the user left (session-restore-and-recently-watched/reopen-on-the-same-tab-and-group).
                .onAppear {
                    guard !restored else { return }
                    restored = true
                    let offer = TitleOffer(records: records, refresher: refresher)
                    let picked: LiveSection? = handoff?.takeMovies() == true ? .titles(offer) : .launch(preferences, offer: offer)
                    section = live.launchWins(picked) ?? LiveSection(live.restoredTab, offer: offer)
                    live.screenRestored(section.session)
                }
            }
            .background(Palette.ground)
            .environment(\.browseMetrics, .regular)
            .environment(\.shellNavigator, navigator)
            .modifier(IntentRequests(navigator: navigator))
            .reminderBanner(live: live, watch: { watch($0) }, showLive: { section = .live })
            .overlay {
                #if DEBUG
                    UITestingLive.Probe(engine: live.engine, player: live.player)
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
        private var eyebrow: LocalizedStringResource {
            switch section {
            case .movies, .series: "Genres"
            case .search: "Recent"
            default: "Groups"
            }
        }

        /// Movies and Series each only when a source offers it
        /// (m3u-playlists/movies-and-series-show-by-what-the-sources-offer).
        private var sections: [LiveSection] {
            LiveSection.allCases.filter { item in
                item != .settings && item.isOffered(by: shelves.offer)
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

        /// The search field over the groups, then the groups it matches
        /// (live-tv-on-iphone-ipad-mac/find-a-group-among-many, `iPad-Live-Groups-Search`).
        @ViewBuilder private func liveGroups(_ columns: LiveColumns) -> some View {
            let choices = GroupChoices(live.catalogue, query: groupQuery) { live.catalogue.label(of: $0) }
            Browse.FilterField.groupSearch($groupQuery)
                .padding(.bottom, 8)
            if choices.isEmpty {
                Text("No groups match")
                    .font(.callout)
                    .foregroundStyle(Palette.textMuted)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 36)
                    .accessibilityIdentifier("browse.groups.empty")
            }
            ForEach(choices.builtIn + choices.groups, id: \.self) { choice in
                let group = choice.group
                let index = choice.index ?? 0
                Browse.GroupRow(
                    title: .verbatim(live.catalogue.label(of: group)), systemImage: group.systemImage,
                    count: live.catalogue.count(of: group),
                    isSelected: (section == .live || section == .guide) && group == live.group
                ) {
                    live.show(group)
                    if section != .guide { section = .live }
                    shown = columns == .picture ? .list : nil
                }
                .groupSpokenLabel(group, count: live.catalogue.count(of: group))
                .accessibilityIdentifier(group == .new ? "groups.new" : "browse.group.\(index)")
            }
            LockedGroupRows(groups: choices.locked.map(\.group))
            ForEach(live.sources.filter { $0.state == .waitingForLogin }) { source in
                Text(source.waitingTag)
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
                GuideRegularScreen { sidebarButton(columns) }
                    .environment(\.guideBoardOpenLive, GuideOpenLiveAction { section = .live })
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

        /// A channel or programme plays in Live; a movie or series opens its
        /// page, as from the Movies section
        /// (search/pick-a-channel-or-title-to-watch).
        private var searchPicks: SearchPicks {
            SearchPicks(
                channel: { watch($0) },
                programme: { hit, channel in
                    guard !hit.isOnNow, navigator.showLater(hit.programme, on: channel) else { return watch(channel) }
                },
                title: { shelves.openPage($0, from: .search, in: $0.kind) },
                person: { shelves.openPerson($0, fromSearchIn: .movie) })
        }

        /// Opens Search, the Guide at a programme, or Live, and sets the shared group.
        private var navigator: ShellNavigator { .window(live: live, guide: guide) { section = LiveSection($0) } }

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

    extension LiveRegularView {
        /// Channels on the player's error: full screen ends and a folded
        /// sidebar opens on the groups. Nil while the sidebar and the list are
        /// both beside the picture
        /// (player-controls-and-playback-errors/go-to-another-group-from-the-error).
        fileprivate var openGroups: OpenChannelGroupsAction? {
            guard live.fullScreen || layout != .all else { return nil }
            return OpenChannelGroupsAction {
                live.setFullScreen(false)
                if layout != .all { shown = .sidebar }
            }
        }
    }

    /// The picture with the playing channel's details and what comes next.
    struct LiveDetailColumn<Toggles: View>: View {
        @ViewBuilder var toggles: Toggles
        @Environment(LiveModel.self) private var live

        var body: some View {
            if let multiView = live.multiView {
                MultiViewWindow(model: multiView)
            } else {
                details
            }
        }

        private var details: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    toggles
                    LivePicture()
                        .clipShape(cornerShape(.medium))
                        .overlay {
                            if live.playing == nil {
                                cornerShape(.medium).strokeBorder(Palette.surface(0.08))
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
#endif
