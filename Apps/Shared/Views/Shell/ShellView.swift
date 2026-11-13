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
        @Environment(\.guideStore) private var guideStore
        @Environment(\.sourceRefresher) private var refresher
        @Query private var preferences: [PreferencesRecord]
        @Environment(\.modelContext) private var context
        @Environment(\.currentProfile) private var profile
        @Environment(\.switchProfile) private var switchProfile
        @State var zapBar = ZapBarModel(hideAfter: ZapBarModel.hideAfterAtLaunch)
        @State var numbers = NumberEntryModel()
        /// When the tab bar last went down; the press that lowered it does not also change channel.
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

        init(model: ShellModel) {
            self.model = model
        }

        var body: some View {
            ZStack(alignment: .topLeading) {
                picture
                ShellLiveLayer(model: model, focus: $focus)
                tabContent
                if zapBarShows, let channel = zapBar.channel {
                    ZapBarView(
                        channel: channel, catalogue: catalogue, list: overlay.currentList(catalogue, for: channel), guide: overlayGuide,
                        engine: model.engine, timeshift: model.player.timeshift
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
                if model.tab == .live, !model.barVisible, model.player.panel != nil, let channel = model.tuned {
                    PlayerTVPanel(player: model.player, channel: channel, catalogue: catalogue, guide: overlayGuide, focus: $focus)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .transition(reduceMotion ? .identity : .move(edge: .top))
                }
                if model.dimmed { ShellScrim() }
                // A title page hides the bar and clock, so swiping up from it reaches nothing
                // (tvos-shell/the-tab-bar-stays-hidden-on-a-title-page).
                if model.barVisible, shelves.page == nil {
                    ShellBarLayer(model: model, focus: $focus, barHasFocus: barHasFocus)
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
                ShellReminderBanner(model: model, catalogue: catalogue, overlay: overlay, focus: $focus)
                #if DEBUG
                    UITestingShell.Probe(engine: model.engine).id(model.multiViewEnds)
                #endif
            }
            .ignoresSafeArea()
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.barVisible)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.tab)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: zapBarShows)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: model.pickerOpen)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: model.player.panel != nil)
            .numberEntry(
                numbers, enabled: numbersEnabled,
                catalogue: catalogue, typing: { zapBar.dismiss() }, tune: { channel in Task { await model.pick(channel) } }
            )
            .onExitCommand(perform: menu)
            .onPlayPauseCommand {
                // Play/pause does nothing while the info panel is open.
                guard model.tab == .live, !model.barVisible, model.player.panel == nil else { return }
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
            .onChange(of: catalogueInputs, initial: true) {
                catalogue = .shell(
                    channels: model.channels, favorites: favorites, profile: profile, recents: shownRecents, rules: groupRules)
                overlayCatalogueChanged()
            }
            .onChange(of: model.recents) { _, _ in showLatestRecents() }
            .followsSubtitlePreference { model.languages.subtitles = $0 }
            .onChange(of: model.pickerOpen) { _, _ in showLatestRecents() }
            .onChange(of: model.tuned, initial: true) { _, channel in zapBar.channelChanged(to: channel) }
            .onChange(of: model.barVisible) { _, raised in
                if raised { zapBar.dismiss() }
            }
            .onMoveCommand(perform: move)
            .modifier(ShellTimeshift(timeshift: model.player.timeshift, zapBar: zapBar, active: fullScreenLive))
            .environment(\.shellNavigator, model.navigator.settingGroup { overlay.tuned(from: $0) })
            .fullScreenCover(isPresented: $model.settingsOpen, onDismiss: { focus = .settings }) {
                SettingsView()
                    .environment(\.loadedChannels, model.channels)
                    // Playback stops before "Who's watching?" (profiles/switching-profile).
                    .environment(\.switchProfile, stoppingFirst)
            }
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
                guard model.tab == .live, !model.barVisible, !model.pickerOpen else { return }
                focus = model.liveFocus
            }
            .onChange(of: focus) { old, new in
                locks?.touched()
                focusMoved(from: old, to: new)
            }
        }

        // MARK: Layers

        /// The same surface in every tab, so the player is never rebuilt (design-system/live-video-keeps-playing-under-overlays):
        /// full screen on Live, the 480 by 270 box on Guide, hidden behind
        /// Movies, Series and Search.
        private var picture: some View {
            ZStack {
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
                .padding(.top, model.tab == .guide ? 48 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .opacity(model.tab.isContent || model.tuned == nil ? 0 : 1)
                if model.tab == .live, model.tuned != nil, model.player.failure == nil {
                    // Stays focusable under the raised bar, so swiping down from the
                    // bar lands here and `move` lowers the bar.
                    Button {
                        guard !model.barVisible else { return }
                        if numbers.isOpen { return numbers.commit() }
                        // Select while the info bar shows hides it, then opens the list.
                        zapBar.dismiss()
                        let target = overlay.open(catalogue, playing: model.tuned)
                        model.openPicker()
                        focus = .overlay(target)
                    } label: {
                        Color.clear
                    }
                    .buttonStyle(HolderStyle())
                    // Holding select opens the info panel; a swipe down already changes channel.
                    .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in openPanel() })
                    .disabled(model.pickerOpen || model.player.panel != nil)
                    .accessibilityLabel("Live picture")
                    .accessibilityIdentifier("shell.picture")
                    .focused($focus, equals: .picture)
                }
            }
        }

        @ViewBuilder private var tabContent: some View {
            switch model.tab {
            case .live:
                EmptyView()
            case .guide:
                GuideScreen(
                    shell: model, catalogue: catalogue, overlay: overlay, guide: overlayGuide, focus: $focus,
                    toggleFavorite: { _ = FavoriteRecord.toggle($0, in: catalogue, profile: profile, context: context) }
                )
            case .movies:
                ShelfTVScreen(kind: .movie, focus: $focus)
            case .series:
                ShelfTVScreen(kind: .series, focus: $focus)
            case .search:
                SearchTVScreen(shell: model, catalogue: catalogue, overlayGuide: overlayGuide) { focus = .picture }
                    .environment(search)
            }
        }

        // MARK: Input

        /// Digits change channel on full-screen Live with nothing over the picture.
        private var numbersEnabled: Bool {
            model.tab == .live && !model.barVisible && !model.pickerOpen && model.tuned != nil && model.player.panel == nil
        }

        private var catalogueInputs: ShellCatalogueInputs {
            ShellCatalogueInputs(
                channels: model.channels, favorites: favorites.map(\.persistentModelID), profile: profile, rules: groupRules)
        }

        private var overlayGuide: OverlayGuide {
            #if DEBUG
                if let scripted = UITestingShell.guide() { return scripted }
            #endif
            return .store(guideStore)
        }

        /// The info bar shows on full-screen Live with nothing else over the picture.
        private var zapBarShows: Bool {
            zapBar.isVisible && model.tab == .live && !model.barVisible && !model.pickerOpen
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
            if zapBarShows {
                zapBar.dismiss()
                return
            }
            let origin: MenuOrigin =
                switch focus {
                case .tab, .settings, .profile: .bar
                case .content: .content
                case .picture, .retry, .signIn, .panel, .liveScreen, .overlay, nil: model.tab == .live ? .picture : .content
                }
            Task { focus = await model.menu(from: origin) }
        }

        /// Swiping up from a tab's content lands on the open tab, not the
        /// nearest pill. Focus leaving the raised bar downwards for the
        /// picture, a Live screen or the guide lowers the bar, whichever of
        /// this and `move` runs first.
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
                // Right from a group lands on the playing channel when the group holds it.
                if let entry = overlay.entry(catalogue, playing: model.tuned), entry != key {
                    focus = .overlay(.channel(entry))
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
            case (.content, .tab(let target)) where target != model.tab && model.tab.isContent:
                focus = .tab(model.tab)
            case (.content, .settings) where model.tab.isContent:
                focus = .tab(model.tab)
            case (.tab, .picture), (.tab, .retry), (.tab, .signIn), (.tab, .liveScreen), (.tab, .content), (.settings, .picture),
                (.settings, .retry), (.settings, .signIn), (.settings, .liveScreen), (.settings, .content):
                if model.barRaised, let target = model.swipeDown() {
                    focus = target
                    barLowered = .now
                }
            default:
                break
            }
        }

        private func move(_ direction: MoveCommandDirection) {
            if focus == .picture || focus == .retry || focus == .signIn, model.tab == .live, !model.barVisible, !model.pickerOpen {
                guard ContinuousClock.now - barLowered > .milliseconds(500) else { return }
                // The swipe preference (sources-and-settings/choose-how-the-app-behaves).
                guard PreferencesStore.current(preferences).swipe == .changesChannel else { return zapBar.playPause() }
                return zap(direction)
            }
            guard direction == .down, barHasFocus, let target = model.swipeDown() else { return }
            focus = target
            barLowered = .now
        }

    }

    extension ShellScreen {
        /// Up and down on the full-screen picture change channel within the
        /// current list; a list of one shows the bar again for the same channel.
        fileprivate func zap(_ direction: MoveCommandDirection) {
            numbers.cancel()
            let steps: Int
            switch direction {
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
            focus = .overlay(next)
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

    /// The player's layers and inputs: the spinner, the error, the info panel.
    extension ShellScreen {
        private var barHasFocus: Bool {
            switch focus {
            case .tab, .settings, .profile: true
            case .picture, .retry, .signIn, .panel, .liveScreen, .content, .overlay, nil: false
            }
        }

        private var overlayFocus: OverlayFocus? {
            if case .overlay(let target) = focus { return target }
            return nil
        }

        /// `switchProfile` after the engine stops; nil outside a profile gate.
        fileprivate var stoppingFirst: (@MainActor () -> Void)? {
            guard let switchProfile else { return nil }
            return { [model] in
                Task {
                    await model.engine.stop()
                    switchProfile()
                }
            }
        }

        /// The spinner or the error over the picture, sized to it: the full
        /// error with its buttons on Live, the short one in the Guide's box
        /// (player-controls-and-playback-errors/a-failed-stream-says-what-went-wrong).
        @ViewBuilder private var pictureStatus: some View {
            if model.tuned != nil {
                if let message = model.player.message {
                    if model.tab == .live {
                        PlayerTVFailure(player: model.player, message: message, focus: $focus, signIn: signIn)
                    } else {
                        PlayerStatus.Failure(channel: nil, title: message.title, explanation: message.explanation) { EmptyView() }
                    }
                } else {
                    PlayerWaitingLayer(player: model.player)
                        .environment(\.playerStatusMetrics, model.tab == .live ? .television : .compact)
                }
            }
        }

        /// Sign in on the error, nil when the failure is not about the login
        /// or the source has no login, as a playlist has none.
        private var signIn: (() -> Void)? {
            guard let failure = model.player.failure, failure == .loginNotOnDevice || failure == .notAllowed,
                let source = model.tuned?.sourceID, model.descriptors[source]?.credentialKey != nil
            else { return nil }
            return { model.signIn(to: source) }
        }

        /// Opens the info panel on Info with focus on its tab.
        private func openPanel() {
            guard !model.barVisible, !model.pickerOpen else { return }
            numbers.cancel()
            zapBar.dismiss()
            model.player.openPanel()
            if model.player.panel != nil { focus = .panel(.segment(.info)) }
        }

        /// The error takes focus from the picture; once it goes, focus is
        /// back on the picture.
        private func failureChanged(_ failed: Bool) {
            switch focus {
            case .picture where failed: focus = .retry
            case .retry where !failed, .signIn where !failed: focus = model.liveFocus
            default: break
            }
        }
    }
#endif
