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
        @State private var model: ShellModel?
        @State private var shelves: ShelfLibrary?
        @State private var playback: ShelfPlayback?
        @State private var lifecycle: PlaybackLifecycle?

        var body: some View {
            ZStack {
                Palette.ground.ignoresSafeArea()
                if let model, let shelves, let playback {
                    ShellScreen(model: model)
                        .modifier(ShelfSync(library: shelves, playback: playback))
                }
            }
            .guideRefreshTriggers()
            // Leaving the shell, as when the profile changes, stops what plays.
            .onDisappear { Task { [engine = model?.engine] in await engine?.stop() } }
            .task {
                guard model == nil else { return }
                let model = ShellModel(dependencies())
                let engine = model.engine
                let lifecycle = PlaybackLifecycle(engine: engine) {
                    engine.continuesInPictureInPicture
                }
                lifecycle.start()
                #if DEBUG
                    UITestingShell.requestGuide(from: model)
                #endif
                self.model = model
                if handoff?.request != nil {
                    handoff?.apply(to: model)
                } else {
                    model.openOnLaunch(in: launchContext)
                }
                refresher?.attach { [weak model] in model?.reload($0) }
                self.shelves = .app(loader)
                self.playback = .app(loader) { await engine.stop() }
                self.lifecycle = lifecycle
            }
        }

        private func dependencies() -> ShellModel.Dependencies {
            #if DEBUG
                if let scripted = UITestingShell.dependencies() { return scripted }
                if let seeded = UITestingScreenshots.dependencies() { return seeded }
                if let scripted = UITestingOnboarding.loader() { return .live(loader: scripted, guide: nil, profile: profile) }
            #endif
            return .live(loader: loader, guide: guideStore, profile: profile, refresher: refresher)
        }
    }

    /// What the overlay's catalogue is built from; it is rebuilt when either changes.
    struct CatalogueInputs: Equatable {
        let channels: [Channel]
        let favorites: [PersistentIdentifier]
        let profile: UUID
    }

    /// Draws the label only: the full-screen picture holds focus with no
    /// visible card.
    struct HolderStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.contentShape(Rectangle())
        }
    }
#endif
