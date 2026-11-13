#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// Feeds Search on iPhone, iPad and Mac from Live's channels, the guide
    /// and the Movies and Series library, and keeps the index current while
    /// Search shows. The window root provides `picks`.
    struct SearchSupply: ViewModifier {
        let picks: SearchPicks
        @Environment(SearchModel.self) private var model
        @AppStorage(GroupDefaults.searchHidden) private var searchHidden = false
        @Environment(LiveModel.self) private var live
        @Environment(ShelfLibrary.self) private var shelves
        @Environment(ShelfActivity.self) private var activity
        @Environment(\.guideStore) private var guideStore

        func body(content: Content) -> some View {
            let corpus = corpus
            content
                .environment(\.searchFeed, feed)
                .task(id: corpus.signature(now: .now)) { await model.load(corpus) }
                // Movies and series load the first time Search opens.
                .task { shelves.open() }
                // A programme that starts or ends updates within seconds
                // (search/seven-days-of-guide).
                .task {
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(5))
                        model.refresh()
                    }
                }
                // A page opened from a result closes when Search goes away.
                .onDisappear {
                    if shelves.page?.origin == .search { shelves.closePage() }
                }
        }

        private var feed: SearchFeed {
            let live = live
            let activity = activity
            return SearchFeed(
                model: model, channel: { live.catalogue.channel(for: $0) }, onNow: { live.programmes.current($0, $1)?.title },
                picks: picks, remember: { activity.recordSearch($0) }, text: SearchText())
        }

        private var corpus: SearchCorpus {
            let order = Dictionary(live.sources.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
            let shelfSources = shelves.movies.opened ? shelves.movies.sources + shelves.series.sources : []
            let finished = live.sources.map { $0.state != .loading } + shelfSources.map { $0.state != .loading }
            return SearchCorpus(
                catalogue: live.catalogue, sourceOrder: order, guide: guide, titles: shelves.movies.titles + shelves.series.titles,
                hasTitles: shelves.offer.any, sources: SearchSources(finished: finished), includeHidden: searchHidden)
        }

        private var guide: GuideIndex {
            #if DEBUG
                if let scripted = UITestingSearch.guide(channels: live.channels, overlay: live.programmes, at: UITestingLive.launched) {
                    return scripted
                }
            #endif
            return guideStore?.index ?? GuideIndex()
        }
    }

    /// Search on iPhone and in a narrow iPad window (boards `iPhone-Search`,
    /// `iPhone-Search-Recents`, `iPhone-Search-Empty`): the field with Cancel,
    /// the chips once there are results, then the results, recent searches
    /// with an empty field, or a message. A series picked here opens its
    /// page over Search.
    struct SearchCompactScreen: View {
        /// Cancel: back to the tab the user came from.
        let cancel: () -> Void
        @Environment(SearchModel.self) private var model
        @AppStorage(GroupDefaults.searchHidden) private var searchHidden = false
        @Environment(ShelfLibrary.self) private var library
        @Environment(ShelfActivity.self) private var activity
        @FocusState private var focused: Bool

        var body: some View {
            let page = library.page.flatMap { $0.origin == .search ? $0 : nil }
            ZStack {
                search
                    .opacity(page == nil ? 1 : 0)
                    .accessibilityHidden(page != nil)
                    .disabled(page != nil)
                if let page {
                    TitleScreen(route: page) {
                        TitlePage.Phone(plotLines: page.title.kind == .movie ? 4 : 2) { EpisodePicker.Section(type: .phone) }
                    }
                    .simultaneousGesture(edgeSwipe)
                    .environment(\.shelfMetrics, .phone)
                    .environment(\.shelfPrefix, page.title.kind.prefix)
                }
            }
            .background(Palette.ground)
            .environment(\.searchMetrics, .phone)
        }

        /// A swipe in from the left edge goes back to Search, as a pushed
        /// page does (title-detail-and-episode-picker/back-to-where-you-were).
        private var edgeSwipe: some Gesture {
            DragGesture(minimumDistance: 20)
                .onEnded { drag in
                    guard drag.startLocation.x < 28, drag.translation.width > 80,
                        abs(drag.translation.height) < drag.translation.width
                    else { return }
                    library.closePage()
                }
        }

        private var search: some View {
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        SearchParts.Field(text: query, clear: model.clear, submit: model.submit)
                            .focused($focused)
                        Button("Cancel") {
                            focused = false
                            model.run("")
                            cancel()
                        }
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.accent)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("search.cancel")
                    }
                    .padding(.horizontal, 16)
                    if !model.results.isEmpty {
                        SearchChips(model: model)
                            .padding(.horizontal, -16)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 4)
                .overlay(alignment: .bottom) { Rectangle().fill(Palette.surface(0.08)).frame(height: 1) }
                ScrollView {
                    content
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .task { focused = true }
            .onChange(of: model.focusRequests) { _, _ in focused = true }
        }

        @ViewBuilder private var content: some View {
            if model.query.isEmpty {
                recents
            } else if let message = searchMessage(model) {
                SearchParts.Message(title: message.title, lines: message.lines)
                    .padding(.top, 80)
                    .accessibilityIdentifier(model.sources == .loading ? "search.loading" : "search.empty")
            } else {
                SearchLayout.Phone()
            }
        }

        @ViewBuilder private var recents: some View {
            if !activity.searches.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("RECENT")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(Palette.textMuted)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.horizontal, 16)
                    ForEach(Array(activity.searches.enumerated()), id: \.offset) { index, text in
                        SearchRow.Recent(text: text) { model.run(text) }
                            .accessibilityIdentifier("search.recent.\(index)")
                    }
                    .padding(.horizontal, 8)
                }
                .padding(.top, 14)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("search.recents")
            }
        }

        private var query: Binding<String> {
            Binding(get: { model.query }, set: { model.type($0) })
        }
    }
#endif
