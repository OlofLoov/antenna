#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// The Apple TV window root (tvos-shell capability): the picture full screen, the tab
    /// bar on Menu, the tabs and Settings. Builds its model once from the
    /// environment's loader and guide store, or from `UITestingShell` in a
    /// Debug build launched for UI tests.
    struct ShellView: View {
        @Environment(\.sourceLoader) private var loader
        @Environment(\.guideStore) private var guideStore
        @State private var model: ShellModel?
        @State private var lifecycle: PlaybackLifecycle?

        var body: some View {
            ZStack {
                Palette.ground.ignoresSafeArea()
                if let model {
                    ShellScreen(model: model)
                }
            }
            .guideRefreshTriggers()
            .task {
                guard model == nil else { return }
                let model = ShellModel(dependencies())
                let engine = model.engine
                let lifecycle = PlaybackLifecycle(engine: engine) {
                    engine.continuesInPictureInPicture
                }
                lifecycle.start()
                self.model = model
                self.lifecycle = lifecycle
            }
        }

        private func dependencies() -> ShellModel.Dependencies {
            #if DEBUG
                if let scripted = UITestingShell.dependencies() { return scripted }
                if let seeded = UITestingScreenshots.dependencies() { return seeded }
            #endif
            return .live(loader: loader, guide: guideStore)
        }
    }

    extension ShellModel.Dependencies {
        /// The engine, loader, Keychain check and clock the app runs on.
        @MainActor static func live(loader: SourceLoader, guide: AppGuideStore?) -> Self {
            .init(
                engine: RoutedEngine.app(),
                load: { try await loader.load($0) },
                hasLogin: { loader.hasLogin($0) },
                lastChannel: LastChannelStore(),
                sleep: { try await Task.sleep(for: $0) },
                guide: guide)
        }
    }

    private struct ShellScreen: View {
        @Bindable var model: ShellModel
        @Query(sort: SourceRecord.displayOrder) private var records: [SourceRecord]
        @Query(sort: \FavoriteRecord.sortOrder) private var favorites: [FavoriteRecord]
        @FocusState private var focus: ShellFocus?
        @Environment(\.scenePhase) private var scenePhase
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.guideStore) private var guideStore
        @Environment(\.modelContext) private var context
        @State private var zapBar = ZapBarModel()
        @State private var overlay = ChannelOverlayModel()
        @State private var catalogue = Catalogue<PersistentIdentifier>(channels: [], groupOrder: [:], favorites: [])

        init(model: ShellModel) {
            self.model = model
        }

        var body: some View {
            ZStack(alignment: .topLeading) {
                picture
                liveScreen
                tabContent
                if zapBarShows, let channel = zapBar.channel {
                    ZapBarView(
                        channel: channel, catalogue: catalogue, list: overlay.currentList(catalogue, for: channel), guide: overlayGuide,
                        engine: model.engine
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
                if model.dimmed { ShellScrim() }
                if model.barVisible { bar }
                if model.pickerOpen {
                    ChannelOverlayView(
                        catalogue: catalogue, playing: model.tuned, guide: overlayGuide, model: overlay, focus: $focus,
                        pick: { channel, group in
                            overlay.tuned(from: group)
                            Task {
                                await model.pickFromOverlay(channel)
                                focus = .picture
                            }
                        },
                        toggleFavorite: toggleFavorite,
                        openSearch: { Task { await model.show(.search) } }
                    )
                    .transition(reduceMotion ? .opacity : .move(edge: .leading))
                }
                #if DEBUG
                    UITestingShell.Probe(engine: model.engine)
                #endif
            }
            .ignoresSafeArea()
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.barVisible)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.tab)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: zapBarShows)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: model.pickerOpen)
            .onExitCommand(perform: menu)
            .onPlayPauseCommand {
                guard model.tab == .live, !model.barVisible else { return }
                guard !model.pickerOpen else { return togglePlayback() }
                // Play/pause in full-screen live TV shows the info bar; the video plays on.
                zapBar.playPause()
            }
            .onChange(of: CatalogueInputs(channels: model.channels, favorites: favorites.map(\.persistentModelID)), initial: true) {
                catalogue = .shell(channels: model.channels, favorites: favorites)
                guard model.pickerOpen, let moved = overlay.catalogueChanged(catalogue, focused: overlayFocus) else { return }
                focus = .overlay(moved)
            }
            .onChange(of: model.tuned, initial: true) { _, channel in
                zapBar.channelChanged(to: channel)
            }
            .onChange(of: model.barVisible) { _, raised in
                if raised { zapBar.dismiss() }
            }
            .onMoveCommand(perform: move)
            .environment(\.shellNavigator, model.navigator)
            .fullScreenCover(isPresented: $model.settingsOpen, onDismiss: { focus = .settings }) {
                SettingsView()
            }
            .task(id: records.compactMap(\.descriptor)) {
                model.sourcesChanged(records.compactMap(\.descriptor))
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await model.becameActive() }
            }
            .onChange(of: model.liveScreen, initial: true) { _, _ in
                guard model.tab == .live, !model.barVisible, !model.pickerOpen else { return }
                focus = model.liveFocus
            }
            .onChange(of: focus) { old, new in
                focusMoved(from: old, to: new)
            }
        }

        // MARK: Layers

        /// The same surface in every tab, so the player is never rebuilt (design-system/live-video-keeps-playing-under-overlays):
        /// full screen on Live, the 480 by 270 box on Guide, hidden behind
        /// Movies, Series and Search.
        private var picture: some View {
            ZStack {
                PlayerSurfaceView(engine: model.engine)
                    .frame(
                        width: model.tab == .guide ? 480 : nil,
                        height: model.tab == .guide ? 270 : nil
                    )
                    .frame(maxWidth: model.tab == .guide ? nil : .infinity, maxHeight: model.tab == .guide ? nil : .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: model.tab == .guide ? 14 : 0))
                    .padding(.leading, model.tab == .guide ? 64 : 0)
                    .padding(.top, model.tab == .guide ? 48 : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .opacity(model.tab.isContent || model.tuned == nil ? 0 : 1)
                    .accessibilityElement()
                    .accessibilityLabel("Picture")
                    .accessibilityValue(model.dimmed ? "dimmed" : "full")
                    .accessibilityIdentifier("shell.player")
                if model.tab == .live, model.tuned != nil {
                    // Stays focusable under the raised bar, so swiping down from the
                    // bar lands here and `move` lowers the bar.
                    Button {
                        guard !model.barVisible else { return }
                        // Select while the info bar shows hides it, then opens the list.
                        zapBar.dismiss()
                        let target = overlay.open(catalogue, playing: model.tuned)
                        model.openPicker()
                        focus = .overlay(target)
                    } label: {
                        Color.clear
                    }
                    .buttonStyle(HolderStyle())
                    .disabled(model.pickerOpen)
                    .accessibilityLabel("Live picture")
                    .accessibilityIdentifier("shell.picture")
                    .focused($focus, equals: .picture)
                }
            }
        }

        @ViewBuilder private var liveScreen: some View {
            if model.tab == .live {
                switch model.liveScreen {
                case .playing:
                    EmptyView()
                case .loading:
                    ShellLoading.Screen(rows: model.sources.map(\.loadingRow))
                        .focusable()
                        .focusEffectDisabled()
                        .focused($focus, equals: .liveScreen)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("shell.loading")
                case .empty:
                    ShellEmpty.Screen(lines: model.sources.filter(\.state.addedNothing).map(\.emptyLine)) {
                        ShellEmpty.RetryButton {
                            model.retry()
                            focus = .liveScreen
                        }
                        .focused($focus, equals: .liveScreen)
                        .accessibilityIdentifier("shell.retry")
                    }
                }
            }
        }

        @ViewBuilder private var tabContent: some View {
            switch model.tab {
            case .live:
                EmptyView()
            case .guide:
                TimelineView(.everyMinute) { context in
                    GuideStandIn(date: context.date, focus: $focus)
                }
            case .movies:
                ContentStandIn(text: "Movies are not available yet.", identifier: "movies.standIn", focus: $focus)
            case .series:
                ContentStandIn(text: "Series are not available yet.", identifier: "series.standIn", focus: $focus)
            case .search:
                ContentStandIn(text: "Search is not available yet.", identifier: "search.standIn", focus: $focus)
            }
        }

        private var bar: some View {
            ShellTabBar.Bar {
                ForEach(model.tabs, id: \.self) { tab in
                    ShellTabBar.Pill(title: tab.title, look: look(for: tab)) {
                        Task { focus = await model.select(tab) }
                    }
                    .focused($focus, equals: .tab(tab))
                    .accessibilityIdentifier("shell.tab.\(tab.identifier)")
                }
            } settings: {
                ShellTabBar.SettingsButton { model.settingsOpen = true }
                    .focused($focus, equals: .settings)
                    .accessibilityIdentifier("shell.settings")
            } trailing: {
                if model.tab == .guide {
                    ShellTabBar.ClockSlot()
                } else {
                    TimelineView(.everyMinute) { context in
                        ShellTabBar.Clock(date: context.date)
                    }
                }
            }
            .focusSection()
        }

        // MARK: Input

        private var barHasFocus: Bool {
            switch focus {
            case .tab, .settings: true
            case .picture, .liveScreen, .content, .overlay, nil: false
            }
        }

        private func look(for tab: ShellTab) -> ShellTabBar.Look {
            guard tab == model.tab else { return .plain }
            return barHasFocus ? .currentInBar : .currentInContent
        }

        /// The favorite button in the overlay's panel. Removing the shown
        /// channel from Favorites while Favorites is shown moves to a neighbor.
        private func toggleFavorite(_ channel: Channel, _ key: RowKey) {
            let before = catalogue
            let isFavorite = FavoriteRecord.toggle(channel, in: catalogue, context: context)
            guard !isFavorite, let next = overlay.removedFromFavorites(key, before: before) else { return }
            focus = .overlay(next)
        }

        private var overlayGuide: OverlayGuide {
            #if DEBUG
                if let scripted = UITestingShell.guide() { return scripted }
            #endif
            return .store(guideStore)
        }

        private var overlayFocus: OverlayFocus? {
            if case .overlay(let target) = focus { return target }
            return nil
        }

        /// Play/pause with the overlay open pauses or resumes the video; the overlay stays.
        private func togglePlayback() {
            Task {
                if await model.engine.state == .paused {
                    await model.engine.play()
                } else {
                    await model.engine.pause()
                }
            }
        }

        /// The info bar shows on full-screen Live with nothing else over the picture.
        private var zapBarShows: Bool {
            zapBar.isVisible && model.tab == .live && !model.barVisible && !model.pickerOpen
        }

        private func menu() {
            if model.pickerOpen {
                model.closePicker()
                focus = .picture
                return
            }
            // Menu hides the info bar and goes no further.
            if zapBarShows {
                zapBar.dismiss()
                return
            }
            let origin: MenuOrigin =
                switch focus {
                case .tab, .settings: .bar
                case .content: .content
                case .picture, .liveScreen, .overlay, nil: model.tab == .live ? .picture : .content
                }
            Task { focus = await model.menu(from: origin) }
        }

        /// Swiping up from a tab's content lands on the open tab, not the
        /// nearest pill. Focus leaving the raised bar downwards for the
        /// picture, a Live screen or the guide lowers the bar, whichever of
        /// this and `move` runs first.
        private func focusMoved(from old: ShellFocus?, to new: ShellFocus?) {
            switch (old, new) {
            case (.overlay(.channel), .overlay(.group(let group))) where group != overlay.group:
                // Left from the channels lands on the group they belong to.
                focus = .overlay(.group(overlay.group))
            case (_, .overlay(.group(let group))):
                overlay.show(group)
            case (.overlay(.group), .overlay(.channel(let key))):
                // Right from a group lands on the playing channel when the group holds it.
                if let entry = overlay.entry(catalogue, playing: model.tuned), entry != key {
                    focus = .overlay(.channel(entry))
                } else {
                    overlay.highlight(key)
                }
            case (.overlay(.watch), .overlay(.channel(let key))), (.overlay(.favorite), .overlay(.channel(let key))):
                // Left from the panel comes back to the channel it describes.
                if let highlighted = overlay.highlighted, highlighted != key {
                    focus = .overlay(.channel(highlighted))
                }
            case (_, .overlay(.channel(let key))):
                overlay.highlight(key)
            case (.overlay(.channel), .overlay(.favorite)):
                // Right from a channel reaches Watch first.
                focus = .overlay(.watch)
            case (.content, .tab(let target)) where target != model.tab && model.tab.isContent:
                focus = .tab(model.tab)
            case (.content, .settings) where model.tab.isContent:
                focus = .tab(model.tab)
            case (.tab, .picture), (.tab, .liveScreen), (.tab, .content), (.settings, .picture), (.settings, .liveScreen),
                (.settings, .content):
                if model.barRaised, let target = model.swipeDown() { focus = target }
            default:
                break
            }
        }

        private func move(_ direction: MoveCommandDirection) {
            guard direction == .down, barHasFocus, let target = model.swipeDown() else { return }
            focus = target
        }
    }

    /// What the overlay's catalogue is built from; it is rebuilt when either changes.
    private struct CatalogueInputs: Equatable {
        let channels: [Channel]
        let favorites: [PersistentIdentifier]
    }

    /// Draws the label only: the full-screen picture holds focus with no
    /// visible card.
    private struct HolderStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.contentShape(Rectangle())
        }
    }

    extension ShellTab {
        var title: String {
            switch self {
            case .live: "Live"
            case .guide: "Guide"
            case .movies: "Movies"
            case .series: "Series"
            case .search: "Search"
            }
        }

        /// The element name design-system/accessibility-identifiers-follow-the-board asks for: `shell.tab.<identifier>`.
        var identifier: String {
            switch self {
            case .live: "live"
            case .guide: "guide"
            case .movies: "movies"
            case .series: "series"
            case .search: "search"
            }
        }
    }
#endif
