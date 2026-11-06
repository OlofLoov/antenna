#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// The Apple TV window root (spec 0015): the picture full screen, the tab
    /// bar on Menu, the tabs and Settings. Builds its model once from the
    /// environment's loader and guide store, or from `UITestingShell` in a
    /// Debug build launched for UI tests.
    struct ShellView: View {
        @Environment(\.sourceLoader) private var loader
        @Environment(\.guideStore) private var guideStore
        @State private var model: ShellModel?

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
                model = ShellModel(dependencies())
            }
        }

        private func dependencies() -> ShellModel.Dependencies {
            #if DEBUG
                if let scripted = UITestingShell.dependencies() { return scripted }
            #endif
            return .live(loader: loader, guide: guideStore)
        }
    }

    extension ShellModel.Dependencies {
        /// The engine, loader, Keychain check and clock the app runs on.
        static func live(loader: SourceLoader, guide: AppGuideStore?) -> Self {
            // Both routes play on Apple's player until the demuxing engine exists.
            let player = AVPlayerEngine()
            return .init(
                engine: RoutedEngine(system: player, demuxer: player),
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
        @FocusState private var focus: ShellFocus?
        @Environment(\.scenePhase) private var scenePhase
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        init(model: ShellModel) {
            self.model = model
        }

        var body: some View {
            ZStack(alignment: .topLeading) {
                picture
                liveScreen
                tabContent
                if model.dimmed { ShellScrim() }
                if model.barVisible { bar }
                if model.pickerOpen {
                    ChannelPicker(channels: model.channels, focus: $focus) { channel in
                        Task {
                            await model.pick(channel)
                            focus = .picture
                        }
                    }
                }
                #if DEBUG
                    UITestingShell.Probe(engine: model.engine)
                #endif
            }
            .ignoresSafeArea()
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.barVisible)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.tab)
            .onExitCommand(perform: menu)
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
                        model.openPicker()
                        focus = .picker(0)
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
            case .picture, .liveScreen, .content, .picker, nil: false
            }
        }

        private func look(for tab: ShellTab) -> ShellTabBar.Look {
            guard tab == model.tab else { return .plain }
            return barHasFocus ? .currentInBar : .currentInContent
        }

        private func menu() {
            if model.pickerOpen {
                model.closePicker()
                focus = .picture
                return
            }
            let origin: MenuOrigin =
                switch focus {
                case .tab, .settings: .bar
                case .content: .content
                case .picture, .liveScreen, .picker, nil: model.tab == .live ? .picture : .content
                }
            Task { focus = await model.menu(from: origin) }
        }

        /// Swiping up from a tab's content lands on the open tab, not the
        /// nearest pill. Focus leaving the raised bar downwards for the
        /// picture, a Live screen or the guide lowers the bar, whichever of
        /// this and `move` runs first.
        private func focusMoved(from old: ShellFocus?, to new: ShellFocus?) {
            switch (old, new) {
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
