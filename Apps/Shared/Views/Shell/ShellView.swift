#if os(tvOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// The shell's layers, inputs and focus over one `ShellModel`.
    struct ShellScreen: View {
        @Bindable var model: ShellModel
        @Query(sort: SourceRecord.displayOrder) private var records: [SourceRecord]
        @Query(sort: \FavoriteRecord.sortOrder) private var favorites: [FavoriteRecord]
        @FocusState var focus: ShellFocus?
        @Environment(\.scenePhase) private var scenePhase
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.layoutDirection) private var layoutDirection
        @Environment(\.guideStore) private var guideStore
        @Environment(\.sourceRefresher) private var refresher
        @Query private var preferences: [PreferencesRecord]
        @Environment(\.modelContext) private var context
        @Environment(\.currentProfile) private var profile
        @Environment(\.switchProfile) var switchProfile
        @State var zapBar = ZapBarModel(hideAfter: ZapBarModel.hideAfterAtLaunch)
        @State var numbers = NumberEntryModel()
        /// When focus last came down from the tab bar; the press that brought it does not also change channel.
        @State private var barLowered = ContinuousClock.now - .seconds(10)
        @State private var overlay = ChannelOverlayModel()
        @State private var catalogue = Catalogue<PersistentIdentifier>(channels: [], groupOrder: [:], favorites: [])
        /// The recents the catalogue lists; Recents open in the overlay keeps its order
        /// (session-restore-and-recently-watched/the-list-holds-still-while-you-use-it).
        @State private var shownRecents: [LastChannelKey] = []
        @State private var groupRules = GroupRules()
        @Environment(GroupLocks.self) private var locks: GroupLocks?
        @Environment(ShelfLibrary.self) private var shelves
        /// Search keeps its query while the app runs.
        @State private var search = SearchModel()
        @Namespace private var pages

        init(model: ShellModel) {
            self.model = model
        }

        var body: some View {
            ZStack(alignment: .topLeading) {
                picture
                tabView
                #if DEBUG
                    UITestingShell.Probe(engine: model.engine).id(model.multiViewEnds)
                #endif
            }
            .ignoresSafeArea()
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.dimmed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: zapBarShows)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: model.pickerOpen)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: model.player.panel != nil)
            .numberEntry(
                numbers, enabled: numbersEnabled,
                catalogue: catalogue, typing: { zapBar.dismiss() }, tune: { channel in Task { await model.pick(channel) } }
            )
            .onPlayPauseCommand {
                // Play/pause does nothing while the info panel is open.
                guard model.liveInFront, model.player.panel == nil else { return }
                // Play/pause on the error is Try again (player-controls-and-playback-errors/try-again-or-recover-on-its-own).
                // It still shows the info bar, as play/pause in full-screen live TV does.
                if model.player.failure != nil, !model.pickerOpen {
                    numbers.cancel()
                    zapBar.playPause()
                    return model.player.retry()
                }
                guard !model.pickerOpen else {
                    Task { await model.togglePlayback() }
                    return
                }
                // Play/pause in full-screen live TV drops half-typed digits, shows the info bar
                // and pauses or plays (timeshift-catch-up-and-start-over/pause-live-tv-and-pick-up-where-you-left-off).
                numbers.cancel()
                zapBar.playPause()
                guard !model.player.timeshift.takeHeldPress() else { return }
                Task { await model.togglePlayback() }
            }
            .onChange(of: catalogueInputs, initial: true) { old, new in
                catalogue = new.catalogue(after: old, current: catalogue, favorites: favorites, recents: shownRecents)
                overlayCatalogueChanged()
            }
            .onChange(of: model.recents) { _, _ in showLatestRecents() }
            .followsSubtitlePreference { model.languages.subtitles = $0 }
            .onChange(of: model.pickerOpen) { _, _ in showLatestRecents() }
            .onChange(of: model.tuned, initial: true) { _, channel in zapBar.channelChanged(to: channel) }
            // Watch on the channel already in the Guide's small picture shows the info bar as a tune does.
            .onChange(of: model.guidePicks) { _, _ in zapBar.channelChanged(to: model.tuned) }
            .onChange(of: model.barFocused) { _, focused in
                if focused { zapBar.dismiss() }
            }
            .modifier(ShellTimeshift(timeshift: model.player.timeshift, zapBar: zapBar, active: fullScreenLive))
            .environment(\.shellNavigator, model.navigator.settingGroup { overlay.tuned(from: $0) })
            .controlHintsLegend()
            .environment(\.shellBarFocused, model.barFocused)
            .fullScreenCover(item: $model.signInRequest, onDismiss: { focus = model.liveFocus }) { request in
                SignInView(request: request) { username, password in
                    try model.saveLogin(for: request, username: username, password: password)
                }
            }
            .onChange(of: model.player.failure != nil) { _, failed in
                failureChanged(failed)
            }
            .onChange(of: model.player.panel == nil) { _, closed in
                if closed, case .panel = focus { focus = model.liveFocus }
            }
            .task(id: records.compactMap(\.descriptor)) {
                model.sourcesChanged(records.compactMap(\.descriptor))
            }
            .task { await model.player.run() }
            .task { await model.trackSession() }
            .modifier(SourceDeletions(removed: model.sourceDeleted, defaults: model.session.store.defaults))
            .modifier(ShellGroupLocks(model: model, catalogue: catalogue) { groupRules = $0 })
            .modifier(multiViewHost)
            .modifier(TopShelfSync(model: model, catalogue: catalogue))
            .onChange(of: scenePhase) { _, phase in
                // Leaving the app stops the ten-second count.
                guard phase == .active else { return model.session.interrupt() }
                Task { await model.becameActive() }
                // Sources past their refresh interval load again (sources-and-settings/sources-refresh-on-a-schedule).
                refresher?.refreshDue(interval: PreferencesStore.current(preferences).refresh.duration)
            }
            .onChange(of: model.liveScreen, initial: true) { _, _ in
                guard model.liveInFront, !model.pickerOpen else { return }
                focus = model.liveFocus
            }
            .onChange(of: focus) { old, new in
                locks?.touched()
                focusMoved(from: old, to: new)
            }
        }

        // MARK: Layers

        /// The same surface behind every tab, so the player is never rebuilt (design-system/live-video-keeps-playing-under-overlays):
        /// full screen behind Live's clear page, the 480 by 270 box on Guide,
        /// hidden behind Movies, Series, Search and Settings.
        private var picture: some View {
            ZStack {
                PlayerSurfaceView(engine: model.engine).id(model.multiViewEnds)
                    .overlay { PlayerSubtitles(engine: model.engine) }
                    .accessibilityElement()
                    .accessibilityLabel("Picture")
                    .accessibilityValue(model.dimmed ? "dimmed" : "full")
                    .accessibilityIdentifier("shell.player")
                pictureStatus
            }
            .frame(
                width: model.tab == .guide ? 480 : nil,
                height: model.tab == .guide ? 270 : nil
            )
            .frame(maxWidth: model.tab == .guide ? nil : .infinity, maxHeight: model.tab == .guide ? nil : .infinity)
            .clipShape(RoundedRectangle(cornerRadius: model.tab == .guide ? 14 : 0))
            .padding(.leading, model.tab == .guide ? 64 : 0)
            .padding(.top, model.tab == .guide ? GuideGrid.pictureTop : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .opacity(model.tab.showsPicture && model.tuned != nil ? 1 : 0)
        }

        /// The system tab bar over the pages (tvos-shell/the-tabs-in-order; `TV-Shell-TabView`).
        /// Live's page is clear, so the picture shows through it.
        private var tabView: some View {
            TabView(selection: Binding(get: { model.tab }, set: { model.choose($0) })) {
                ForEach(model.tabs, id: \.self) { tab in
                    // Search is the system's search tab, drawn as a magnifying glass.
                    Tab(value: tab, role: tab == .search ? .search : nil) {
                        page(tab)
                            // Inside the page, where the focus engine lets it take the highlight.
                            .overlay {
                                if tab == model.tab {
                                    ShellReminderBanner(model: model, catalogue: catalogue, overlay: overlay, focus: $focus)
                                }
                            }
                            .focusScope(pages)
                            .toolbarVisibility(barVisibility(on: tab), for: .tabBar)
                    } label: {
                        Group {
                            if tab == .search {
                                Label(tab.title, systemImage: "magnifyingglass")
                            } else {
                                Text(tab.title)
                            }
                        }
                        .accessibilityIdentifier(tab.elementName)
                        .accessibilityAddTraits(tab == model.tab ? .isSelected : [])
                    }
                }
            }
            .modifier(ShellFocusKeeper(model: model, focus: $focus, pages: pages))
        }

        /// The bar stays out of the way over the picture and the guide until
        /// Menu brings the highlight to it, and while a title page is open
        /// (tvos-shell/the-tab-bar-stays-hidden-on-a-title-page). Elsewhere
        /// the system shows it while it has the highlight.
        private func barVisibility(on tab: ShellTab) -> Visibility {
            switch tab {
            case .live, .guide: model.barFocused ? .visible : .hidden
            case .movies, .series, .search: shelves.top == nil ? .automatic : .hidden
            case .settings: .automatic
            }
        }

        @ViewBuilder private func page(_ tab: ShellTab) -> some View {
            switch tab {
            case .live:
                livePage
            case .guide:
                GuideScreen(
                    shell: model, catalogue: catalogue, overlay: overlay, guide: overlayGuide, focus: $focus,
                    toggleFavorite: { _ = FavoriteRecord.toggle($0, in: catalogue, profile: profile, context: context) }
                )
                .overlay { if model.dimmed { ShellScrim() } }
                .ignoresSafeArea()
            case .movies:
                ShelfTVScreen(kind: .movie, focus: $focus).ignoresSafeArea()
            case .series:
                ShelfTVScreen(kind: .series, focus: $focus).ignoresSafeArea()
            case .search:
                SearchTVScreen(shell: model, catalogue: catalogue, overlayGuide: overlayGuide) { focus = .picture }
                    .environment(search)
                    .ignoresSafeArea()
            case .settings:
                SettingsView()
                    .environment(\.loadedChannels, model.channels)
                    // Playback stops before "Who's watching?" (profiles/switching-profile).
                    .environment(\.switchProfile, stoppingFirst)
            }
        }

        /// Live's page: clear over the picture, with the loading and empty
        /// screens, the error, the info bar, the info panel and the channel overlay.
        private var livePage: some View {
            ZStack(alignment: .topLeading) {
                ShellLiveLayer(model: model, focus: $focus)
                if model.dimmed { ShellScrim() }
                if model.tuned != nil, let message = model.player.message {
                    PlayerTVFailure(player: model.player, message: message, focus: $focus, signIn: signIn)
                }
                pictureHolder
                if zapBarShows, let channel = zapBar.channel {
                    ZapBarView(
                        channel: channel, catalogue: catalogue, list: overlay.currentList(catalogue, for: channel), guide: overlayGuide,
                        engine: model.engine, timeshift: model.player.timeshift
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    // The system tab bar holds no clock, so the info bar shows it top right (`TV-Shell-TabView`).
                    TimelineView(.everyMinute) { context in
                        TVClock(date: context.date, identifier: "zapBar.clock")
                    }
                    .padding(.top, 58)
                    .padding(.trailing, 80)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
                if model.player.panel != nil, let channel = model.tuned {
                    PlayerTVPanel(player: model.player, channel: channel, catalogue: catalogue, guide: overlayGuide, focus: $focus)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .transition(reduceMotion ? .identity : .move(edge: .top))
                }
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
                        openSearch: { Task { await model.show(.search) } }, multiView: model.multiViewOffer,
                        startOver: overlayStartOver
                    )
                    .transition(reduceMotion ? .opacity : .move(edge: .leading))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            // Menu closes what is open over the picture; with nothing open the
            // system takes it to the tab bar (tvos-shell/menu-shows-the-tab-bar-over-the-picture).
            .onExitCommand(perform: liveMenu)
            .onMoveCommand(perform: move)
        }

        /// The full-screen picture's focus holder: select opens the channel
        /// overlay, holding select opens the info panel.
        @ViewBuilder private var pictureHolder: some View {
            if model.tuned != nil, model.player.failure == nil {
                // Holding select opens the info panel; a swipe down already changes channel.
                HoldButton {
                    if numbers.isOpen { return numbers.commit() }
                    // Select while the info bar shows hides it, then opens the list.
                    zapBar.dismiss()
                    let target = overlay.open(catalogue, playing: model.tuned)
                    model.openPicker()
                    focus = .overlay(target)
                } hold: {
                    openPanel()
                } label: {
                    Color.clear
                }
                .buttonStyle(FocusHolderStyle())
                .disabled(model.pickerOpen || model.player.panel != nil)
                .accessibilityLabel("Live picture")
                .accessibilityIdentifier("shell.picture")
                .focused($focus, equals: .picture)
                .controlHints(.live(swipe: PreferencesStore.current(preferences).swipe, infoBar: zapBarShows))
            }
        }

    }

    // MARK: Input

    extension ShellScreen {

        /// Digits change channel on full-screen Live with nothing over the picture.
        private var numbersEnabled: Bool {
            model.liveInFront && !model.pickerOpen && model.tuned != nil && model.player.panel == nil
        }

        private var catalogueInputs: ShellCatalogueInputs {
            ShellCatalogueInputs(
                channels: model.channels, favorites: favorites.map(\.persistentModelID), profile: profile, rules: groupRules,
                seen: model.seen)
        }

        private var overlayGuide: OverlayGuide {
            #if DEBUG
                if let scripted = UITestingStoreShots.guide(launched: UITestingShell.launched) ?? UITestingShell.guide() { return scripted }
            #endif
            return .store(guideStore)
        }

        /// The info bar shows on full-screen Live with nothing else over the picture.
        private var zapBarShows: Bool {
            zapBar.isVisible && model.liveInFront && !model.pickerOpen
        }

        /// Menu while something is open over the picture; nil leaves Menu to the system.
        private var liveMenu: (() -> Void)? {
            guard model.player.panel != nil || numbers.isOpen || model.pickerOpen || zapBarShows else { return nil }
            return menu
        }

        private func menu() {
            // Menu closes the info panel and goes no further.
            if model.player.panel != nil {
                model.player.closePanel()
                focus = model.liveFocus
                return
            }
            if numbers.isOpen { return numbers.cancel() }
            if model.pickerOpen {
                model.closePicker()
                focus = model.liveFocus
                return
            }
            // Menu hides the info bar and goes no further.
            if zapBarShows { zapBar.dismiss() }
        }

        /// Moves focus inside the overlay and the info panel by their rules.
        private func focusMoved(from old: ShellFocus?, to new: ShellFocus?) {
            switch (old, new) {
            case (_, .panel(.segment(let tab))):
                // Moving onto Audio or Subtitles opens that tab.
                model.player.panel = tab
            case (.overlay(.channel), .overlay(.group(let group))) where group != overlay.group:
                // Left from the channels lands on the group they belong to.
                focus = .overlay(.group(overlay.group))
            case (_, .overlay(.group(let group))):
                overlay.show(group)
            case (.overlay(.group), .overlay(.channel(let key))):
                // Right from a group lands on the row last highlighted in its list, else the playing channel or the first row.
                if let target = overlay.target(catalogue, playing: model.tuned), target != key {
                    focus = .overlay(.channel(target))
                } else {
                    overlay.highlight(key)
                }
            case (.overlay(.watch), .overlay(.channel(let key))), (.overlay(.favorite), .overlay(.channel(let key))),
                (.overlay(.next), .overlay(.channel(let key))):
                // Left from the panel comes back to the channel it describes.
                if let highlighted = overlay.highlighted, highlighted != key {
                    focus = .overlay(.channel(highlighted))
                }
            case (_, .overlay(.channel(let key))):
                overlay.highlight(key)
            case (.overlay(.channel), .overlay(.favorite)), (.overlay(.channel), .overlay(.next)):
                // Right from a channel reaches Watch first; up from Watch reaches the programmes that follow.
                focus = .overlay(.watch)
            case (nil, .picture), (nil, .retry), (nil, .signIn):
                // Swiping down from the tab bar onto the picture does not also change channel.
                if model.tab == .live { barLowered = .now }
            default:
                break
            }
        }

        private func move(_ direction: MoveCommandDirection) {
            guard focus == .picture || focus == .retry || focus == .signIn, model.liveInFront, !model.pickerOpen else { return }
            guard ContinuousClock.now - barLowered > .milliseconds(500) else { return }
            // The swipe preference (sources-and-settings/choose-how-the-app-behaves).
            guard PreferencesStore.current(preferences).swipe == .changesChannel else { return zapBar.playPause() }
            zap(direction)
        }

    }

    extension ShellScreen {
        /// Up and down on the full-screen picture change channel within the
        /// current list; a list of one shows the bar again for the same channel.
        fileprivate func zap(_ direction: MoveCommandDirection) {
            numbers.cancel()
            let steps: Int
            switch direction.reading(layoutDirection) {
            case .up: steps = 1
            case .down: steps = -1
            // Behind live or paused, left and right skip (timeshift-catch-up-and-start-over/skip-scan-and-drag).
            case .left where model.player.timeshift.showsRewindRow: return model.player.timeshift.skip(forward: false)
            case .right where model.player.timeshift.showsRewindRow: return model.player.timeshift.skip(forward: true)
            case .left: return previousChannel()
            case .right: return openRecents()
            default: return
            }
            guard let tuned = model.tuned, let next = overlay.step(catalogue, from: tuned, by: steps) else { return }
            guard next != tuned else { return zapBar.playPause() }
            Task { await model.pick(next) }
        }

        /// Swipe left on the full-screen picture plays the most recent
        /// other channel in Recents; with none, nothing happens.
        private func previousChannel() {
            guard focus == .picture, let tuned = model.tuned, let previous = overlay.previous(catalogue, from: tuned) else { return }
            Task { await model.pick(previous) }
        }

        /// Swipe right on the full-screen picture opens the overlay on
        /// Recents, or as usual when Recents is not listed. Playback carries on.
        private func openRecents() {
            guard focus == .picture else { return }
            showLatestRecents()
            let target = overlay.openRecents(catalogue) ?? overlay.open(catalogue, playing: model.tuned)
            zapBar.dismiss()
            model.openPicker()
            focus = .overlay(target)
        }

        /// The favorite button in the overlay's panel. Removing the shown
        /// channel from Favorites while Favorites is shown moves to a neighbor.
        private func toggleFavorite(_ channel: Channel, _ key: RowKey) {
            let before = catalogue
            let isFavorite = FavoriteRecord.toggle(channel, in: catalogue, profile: profile, context: context)
            guard !isFavorite, let next = overlay.removedFromFavorites(key, before: before) else { return }
            // After the removed row has left the list, or the focus engine puts the highlight nowhere.
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                focus = .overlay(next)
            }
        }

        /// Multi-view over Live; the channel it hands back shows the info bar.
        fileprivate var multiViewHost: ShellMultiViewHost {
            ShellMultiViewHost(
                model: model, catalogue: catalogue, guide: overlayGuide, overlay: overlay, focus: $focus, toggleFavorite: toggleFavorite
            ) { zapBar.channelChanged(to: model.tuned) }
        }

        /// Lists the newest recents, except in Recents open in the overlay.
        private func showLatestRecents() {
            guard shownRecents != model.recents, !(model.pickerOpen && overlay.group == .recents) else { return }
            shownRecents = model.recents
            catalogue = catalogue.replacingRecents(shownRecents)
            overlayCatalogueChanged()
        }

        private func overlayCatalogueChanged() {
            guard model.pickerOpen, let moved = overlay.catalogueChanged(catalogue, focused: overlayFocus) else { return }
            focus = .overlay(moved)
        }
    }

#endif
