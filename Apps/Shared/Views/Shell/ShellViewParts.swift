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
        @Environment(\.currentProfile) private var profile
        @Environment(\.onboardingHandoff) private var handoff
        @Environment(\.sourceRefresher) private var refresher
        @Environment(\.modelContext) private var launchContext
        @Environment(TopShelfInbox.self) private var shelfLinks: TopShelfInbox?
        @State private var model: ShellModel?
        @State private var shelves: ShelfLibrary?
        @State private var playback: ShelfPlayback?
        @State private var lifecycle: PlaybackLifecycle?

        var body: some View {
            ZStack {
                Palette.ground.ignoresSafeArea()
                if let model, let shelves, let playback {
                    ShellScreen(model: model)
                        .modifier(TopShelfLinks(model: model, library: shelves, playback: playback))
                        .modifier(ShelfSync(library: shelves, playback: playback))
                        .modifier(
                            LaunchTitleRestore(launch: model.launchTitle, library: shelves) { title, key in
                                reopen(title, key, model, shelves, playback)
                            })
                }
            }
            .guideRefreshTriggers()
            // Leaving the shell, as when the profile changes, stops what plays.
            .onDisappear { Task { [engine = model?.engine] in await engine?.stop() } }
            .task {
                guard model == nil else { return }
                let model = ShellModel(dependencies())
                // A shelf link at launch holds the last-channel tune (tvos-shell/play-or-resume-from-a-shelf-link).
                if let id = shelfLinks?.take() { model.holdShelfItem(id) }
                let engine = model.engine
                let lifecycle = PlaybackLifecycle(engine: engine) {
                    engine.continuesInPictureInPicture
                }
                lifecycle.follow(model.player.timeshift)
                lifecycle.start()
                #if DEBUG
                    UITestingShell.requestGuide(from: model)
                    UITestingShell.openURLWhenRunning(into: shelfLinks, model: model)
                #endif
                self.model = model
                if handoff?.request != nil {
                    handoff?.apply(to: model)
                } else {
                    model.openOnLaunch(in: launchContext)
                }
                refresher?.attach { [weak model] in model?.reload($0) }
                self.shelves = .app(loader)
                let playback = ShelfPlayback.app(loader) { await engine.stop() }
                playback.recordsWatched(in: model.session.store)
                self.playback = playback
                self.lifecycle = lifecycle
            }
        }

        /// Opens the page of the title watched last over its tab, unless a
        /// page or a title is already up
        /// (session-restore-and-recently-watched/reopen-on-the-title-watched-last).
        private func reopen(
            _ title: ShelfTitle, _ key: LastWatched.Title, _ model: ShellModel, _ shelves: ShelfLibrary, _ playback: ShelfPlayback
        ) {
            guard shelves.top == nil, playback.playing == nil else { return model.launchTitle.drop() }
            shelves.reopen(title, episode: key.episodeID)
            Task { await model.launchTitleOpened(in: title.kind == .movie ? .movies : .series) }
        }

        private func dependencies() -> ShellModel.Dependencies {
            #if DEBUG
                if let scripted = UITestingShell.dependencies() { return scripted }
                if let seeded = UITestingScreenshots.dependencies() { return seeded }
                if UITestingShelf.scenario() != nil {
                    // What was watched last survives a relaunch only with -ui-testing-keep-session.
                    var shelf = ShellModel.Dependencies.live(loader: loader, guide: guideStore, profile: profile, refresher: refresher)
                    shelf.recents = UITestingRecents.store { _ in UITestingShelf.homeID }
                    shelf.watchSleep = UITestingRecents.sleep
                    return shelf
                }
                if let scripted = UITestingOnboarding.loader() {
                    return .live(loader: scripted, guide: nil, profile: profile, refresher: refresher)
                }
            #endif
            return .live(loader: loader, guide: guideStore, profile: profile, refresher: refresher)
        }
    }
#endif
