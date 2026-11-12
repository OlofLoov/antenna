#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// The Search tab on Apple TV (boards `TV-Search`, `TV-Search-Recents`):
    /// the system search field and keyboard under the tab bar, recent
    /// searches while the field is empty, then every section with every
    /// programme. A series picked here opens its page full screen.
    struct SearchTVScreen: View {
        let shell: ShellModel
        let catalogue: Catalogue<PersistentIdentifier>
        let overlayGuide: OverlayGuide
        /// Runs once a picked channel plays, so the shell can focus the picture.
        let watching: @MainActor () -> Void
        @Environment(SearchModel.self) private var model
        @AppStorage(GroupDefaults.searchHidden) private var searchHidden = false
        @Environment(ShelfLibrary.self) private var library
        @Environment(ShelfActivity.self) private var activity
        @Environment(ShelfPlayback.self) private var playback
        @Environment(\.guideStore) private var guideStore

        var body: some View {
            let page = library.page.flatMap { $0.origin == .search ? $0 : nil }
            let corpus = corpus
            ZStack {
                search
                    .opacity(page == nil ? 1 : 0)
                    .accessibilityHidden(page != nil)
                    .disabled(page != nil)
                if let page {
                    TitleScreen(route: page) {
                        TitlePage.Television(
                            plotLines: page.title.kind == .movie ? 4 : 2, artHeight: page.title.kind == .movie ? 1080 : 520
                        ) {
                            EpisodePicker.Section(type: .tv)
                        }
                    }
                    .environment(\.shelfMetrics, .tv)
                    .environment(\.shelfPrefix, page.title.kind.prefix)
                }
            }
            .environment(\.searchMetrics, .tv)
            .environment(\.searchFeed, feed)
            .task(id: corpus.signature(now: .now)) { await model.load(corpus) }
            .task { library.open() }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5))
                    model.refresh()
                }
            }
            .onDisappear {
                if library.page?.origin == .search { library.closePage() }
            }
        }

        private var search: some View {
            NavigationStack {
                ScrollView {
                    content
                        .padding(.horizontal, 64)
                        .padding(.bottom, 64)
                }
                .searchable(text: query, prompt: SearchText.placeholder)
                .background(Palette.ground)
                .accessibilityIdentifier("search.results")
            }
            .padding(.top, 104)
        }

        @ViewBuilder private var content: some View {
            if model.query.isEmpty {
                recents
            } else if let message = searchMessage(model) {
                SearchParts.Message(title: message.title, lines: message.lines)
                    .padding(.top, 60)
                    .focusable()
                    .accessibilityIdentifier(model.sources == .loading ? "search.loading" : "search.empty")
            } else {
                SearchLayout.Television()
            }
        }

        @ViewBuilder private var recents: some View {
            if !activity.searches.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    SearchParts.Header(title: "Recent searches", count: "\(activity.searches.count)") { EmptyView() }
                    ForEach(Array(activity.searches.enumerated()), id: \.offset) { index, text in
                        SearchRow.Recent(text: text) { model.run(text) }
                            .frame(maxWidth: 800, alignment: .leading)
                            .accessibilityIdentifier("search.recent.\(index)")
                    }
                }
                .padding(.top, 30)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("search.recents")
            }
        }

        private var query: Binding<String> {
            Binding(get: { model.query }, set: { model.type($0) })
        }

        private var feed: SearchFeed {
            let catalogue = catalogue
            let overlayGuide = overlayGuide
            let activity = activity
            return SearchFeed(
                model: model, channel: { catalogue.channel(for: $0) }, onNow: { overlayGuide.current($0, $1)?.title },
                picks: .shell(shell, library: library, activity: activity, playback: playback, watching: watching),
                remember: { activity.recordSearch($0) }, text: SearchText())
        }

        private var corpus: SearchCorpus {
            let order = Dictionary(shell.sources.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
            let shelfSources = library.movies.opened ? library.movies.sources + library.series.sources : []
            let finished = shell.sources.map { $0.state != .loading } + shelfSources.map { $0.state != .loading }
            return SearchCorpus(
                catalogue: catalogue, sourceOrder: order, guide: guide, titles: library.movies.titles + library.series.titles,
                hasTitles: library.hasXtream, sources: SearchSources(finished: finished), includeHidden: searchHidden)
        }

        private var guide: GuideIndex {
            #if DEBUG
                if let scripted = UITestingSearch.guide(channels: shell.channels, overlay: overlayGuide, at: UITestingShell.launched) {
                    return scripted
                }
            #endif
            return guideStore?.index ?? GuideIndex()
        }
    }

    extension SearchPicks {
        /// Apple TV: a channel or a programme on now plays full screen, a
        /// later programme opens the Guide at it, a movie plays and a series
        /// opens its page (search/pick-a-channel-or-title-to-watch,
        /// search/pick-a-programme). `watching` runs once a channel plays.
        @MainActor static func shell(
            _ shell: ShellModel, library: ShelfLibrary, activity: ShelfActivity, playback: ShelfPlayback,
            watching: @escaping @MainActor () -> Void
        ) -> SearchPicks {
            let watch: @MainActor (Channel) -> Void = { channel in
                Task {
                    await shell.pickFromOverlay(channel)
                    watching()
                }
            }
            return SearchPicks(
                channel: watch,
                programme: { hit, channel in
                    guard !hit.isOnNow else { return watch(channel) }
                    let key = ProgrammeKey(guideKey: hit.id.guideKey, start: hit.id.start)
                    Task { await shell.show(.guide(programmeKey: key)) }
                },
                title: { title in
                    switch title.kind {
                    case .movie: playback.play(title, library: library, activity: activity)
                    case .series: library.openPage(title, from: .search, in: title.kind)
                    }
                })
        }
    }

    extension SearchLayout {
        /// Apple TV: channels as a row of cards, every programme two across,
        /// then posters (`TV-Search`). No chips; every section shows.
        struct Television: View {
            @Environment(\.searchFeed) private var feed

            var body: some View {
                if let feed {
                    let results = feed.model.results
                    LazyVStack(alignment: .leading, spacing: 28) {
                        if !results.channels.isEmpty {
                            section(.channels, count: "\(results.count(.channels))") {
                                ScrollView(.horizontal) {
                                    LazyHStack(spacing: 20) {
                                        ForEach(Array(results.shownChannels.enumerated()), id: \.element.id) { index, hit in
                                            SearchChannelResult(hit: hit, index: index)
                                                .frame(width: 340)
                                        }
                                    }
                                    .padding(.vertical, 20)
                                }
                                .scrollClipDisabled()
                            }
                        }
                        if !results.programmes.isEmpty || feed.model.guideLoading {
                            let count =
                                results.programmes.isEmpty
                                ? "loading" : "\(SearchText.nextSevenDays) · \(results.count(.guide))"
                            section(.guide, count: count) {
                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)], spacing: 12) {
                                    // Apple TV lists every programme (search/very-long-result-lists).
                                    ForEach(results.programmes.indices, id: \.self) { index in
                                        SearchProgrammeResult(hit: results.programmes[index], index: index)
                                    }
                                }
                            }
                        }
                        if !results.titles.isEmpty {
                            section(.titles, count: "\(results.titles.count)") {
                                ScrollView(.horizontal) {
                                    LazyHStack(alignment: .top, spacing: 20) {
                                        ForEach(Array(results.titles.enumerated()), id: \.element.id) { index, hit in
                                            SearchTitleResult(hit: hit, index: index)
                                        }
                                    }
                                    .padding(.vertical, 20)
                                }
                                .scrollClipDisabled()
                            }
                        }
                    }
                    .padding(.top, 30)
                }
            }

            private func section<Content: View>(
                _ kind: SearchSectionKind, count: String, @ViewBuilder content: () -> Content
            ) -> some View {
                VStack(alignment: .leading, spacing: 14) {
                    SearchParts.Header(title: kind.title, count: count) { EmptyView() }
                    content()
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("search.section.\(kind.identifier)")
            }
        }
    }
#endif
