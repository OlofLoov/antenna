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

        var body: some View {
            VStack(spacing: 0) {
                let count = live.catalogue.count(of: live.group)
                Browse.ListHeader(title: live.group.label, count: count == 1 ? "1 channel" : "\(count) channels") {
                    leading
                } filter: {
                    EmptyView()
                }
                if live.channels.isEmpty {
                    ProgressView("Loading channels…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    LiveChannelList(picked: picked)
                }
            }
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

    /// The details panel for the playing channel, refreshed each minute.
    struct LiveDetails: View {
        let channel: Channel
        @Environment(LiveModel.self) private var live

        var body: some View {
            TimelineView(.everyMinute) { context in
                let panel = live.programmes.panel(for: channel, at: context.date)
                let number = RowKey(channel).flatMap(live.catalogue.number(for:))
                Browse.Panel(channel: channel.name, now: now(panel, number: number), next: panel.next.map(Self.next)) {
                    Browse.Logo(url: channel.logoURL, initials: Channel.initials(for: channel.name), isSelected: true)
                } trailing: {
                    EmptyView()
                }
            }
        }

        private func now(_ panel: OverlayGuide.Panel, number: Int?) -> Browse.PanelNow {
            var meta = [channel.name, number.map(String.init)].compactMap(\.self)
            guard case .programme(let title, let progress, let remaining) = panel.line, let programme = panel.now else {
                return .init(title: panel.line.text, meta: meta.joined(separator: " · "))
            }
            meta.append(remaining)
            return .init(
                title: title, times: "\(Self.time(programme.start)) – \(Self.time(programme.stop))", meta: meta.joined(separator: " · "),
                summary: programme.summary, progress: progress)
        }

        private static func next(_ programme: Programme) -> Browse.PanelNext {
            .init(time: time(programme.start), title: programme.title)
        }

        private static func time(_ date: Date) -> String {
            date.formatted(date: .omitted, time: .shortened)
        }
    }
#endif
