#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// Search in the iPad and Mac content column (boards `iPad-Search`,
    /// `iPad-Search-OneCharacter`, `iPad-Search-Loading`,
    /// `iPad-Search-GuideLoading`, `iPad-Search-Capped`): the field and the
    /// chips over the results. The sidebar lists recent searches. A series
    /// picked here opens its page in place of the column.
    struct SearchRegularScreen<Leading: View>: View {
        /// The sidebar button while the sidebar is folded.
        @ViewBuilder var leading: Leading
        @Environment(SearchModel.self) private var model
        @Environment(ShelfLibrary.self) private var library
        @Environment(ShelfActivity.self) private var activity
        @Environment(\.searchFeed) private var feed
        @FocusState private var focused: Bool
        @Environment(\.layoutDirection) private var layoutDirection

        var body: some View {
            let page = library.top.flatMap { $0.origin == .search ? $0 : nil }
            ZStack {
                search
                    .opacity(page == nil ? 1 : 0)
                    .accessibilityHidden(page != nil)
                    .disabled(page != nil)
                if let page {
                    LibraryPageView(page: page) { page in
                        TitlePage.Pad(plotLines: page.title.kind == .movie ? 5 : 2) { EpisodePicker.Section(type: .pad) }
                    } person: {
                        PersonPageLayout.Pad()
                    }
                    .environment(\.shelfMetrics, .pad)
                    .environment(\.shelfPrefix, page.section.prefix)
                }
            }
            .background(Palette.ground)
            .environment(\.searchMetrics, .pad)
        }

        private var search: some View {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        leading
                        SearchParts.Field(text: query, clear: model.clear, submit: model.submit)
                            .focused($focused)
                            .onKeyPress(.downArrow) {
                                // Down from the field moves into the results.
                                guard !model.items.isEmpty else { return .ignored }
                                focused = false
                                model.moveCursor(1)
                                return .handled
                            }
                            .onKeyPress(.escape) {
                                escape()
                                return .handled
                            }
                    }
                    if !model.results.isEmpty {
                        SearchChips(model: model)
                            .padding(.horizontal, -16)
                    }
                }
                .padding(EdgeInsets(top: 18, leading: 24, bottom: 10, trailing: 24))
                ScrollViewReader { proxy in
                    ScrollView {
                        content
                    }
                    .onChange(of: model.cursor) { _, cursor in
                        if let cursor { withAnimation { proxy.scrollTo(cursor) } }
                    }
                }
            }
            .background { keys }
            .menuCommand(\.findCommand, MenuCommand(title: KeyCommand.findTitle(on: .search)) { model.focus() })
            .task { focused = true }
            .onChange(of: model.focusRequests) { _, _ in focused = true }
            .onChange(of: focused) { _, isFocused in
                if isFocused { model.cursor = nil }
            }
        }

        @ViewBuilder private var content: some View {
            if let message = searchMessage(model) {
                StatusView(
                    symbol: message.symbol, verbatimTitle: message.title, verbatimLines: message.lines,
                    identifier: model.sources == .loading ? "search.loading" : "search.empty"
                )
                .padding(.top, 120)
            } else if model.results.query.isSearchable {
                SearchLayout.Pad()
            }
        }

        /// The arrows, Return and Escape as key commands, so they work
        /// wherever focus is (search/search-with-a-keyboard). Command-F is
        /// Search in the Edit menu. The sideways arrows follow the reading
        /// direction: in Arabic the next result is drawn to the left.
        private var keys: some View {
            ZStack {
                FindKey { model.focus() }
                // Down also leaves the field for the first result.
                Button("Next result") {
                    focused = false
                    move(1)
                }
                .keyboardShortcut(.downArrow, modifiers: [])
                .disabled(model.items.isEmpty && model.recentCursor == nil)
                Button("Clear the search") { escape() }
                    .keyboardShortcut(.cancelAction)
                Button("Open the result") { enter() }
                    .keyboardShortcut(.return, modifiers: [])
                Group {
                    Button("Previous result") { move(-1) }
                        .keyboardShortcut(.upArrow, modifiers: [])
                    Button("Next result across") { move(1) }
                        .keyboardShortcut(layoutDirection.trailingArrow, modifiers: [])
                    Button("Previous result across") { move(-1) }
                        .keyboardShortcut(layoutDirection.leadingArrow, modifiers: [])
                }
                .disabled(focused)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }

        /// Moves through the recent searches once Escape went there, else
        /// through the results.
        private func move(_ step: Int) {
            guard let index = model.recentCursor else { return model.moveCursor(step) }
            model.recentCursor = max(0, min(activity.searches.count - 1, index + step))
        }

        /// Return runs the recent search or picks the result under the
        /// cursor; in the field it searches without waiting for the pause.
        private func enter() {
            if let index = model.recentCursor, activity.searches.indices.contains(index) {
                model.run(activity.searches[index])
            } else if model.cursor != nil {
                feed?.pickCursor()
            } else {
                model.submit()
            }
        }

        /// Escape clears the field, or with an empty field moves to the
        /// recent searches in the sidebar.
        private func escape() {
            if model.query.isEmpty {
                focused = false
                if !activity.searches.isEmpty { model.cursorOnRecents() }
            } else {
                model.clear()
            }
        }

        private var query: Binding<String> {
            Binding(get: { model.query }, set: { model.type($0) })
        }
    }

    /// The recent searches under the sidebar's sections while Search shows
    /// (`iPad-Search`, "Recent"); picking one runs it (search/recent-searches).
    struct SearchSidebarRecents: View {
        @Environment(SearchModel.self) private var model
        @Environment(ShelfActivity.self) private var activity

        var body: some View {
            ForEach(Array(activity.searches.enumerated()), id: \.offset) { index, text in
                SearchParts.SidebarRecent(text: text, isCursor: model.recentCursor == index) { model.run(text) }
                    .accessibilityIdentifier("search.recent.\(index)")
            }
        }
    }
#endif
