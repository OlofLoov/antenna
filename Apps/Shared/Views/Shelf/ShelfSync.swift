import AntennaCore
import SwiftData
import SwiftUI

/// Feeds the Movies and Series library from the store and the system: the
/// sources, the current profile's progress and My list, and returns to the
/// foreground. Applied once at the window root,
/// above every layout.
struct ShelfSync: ViewModifier {
    let library: ShelfLibrary
    let playback: ShelfPlayback
    @Query(sort: SourceRecord.displayOrder) private var records: [SourceRecord]
    @Query private var preferences: [PreferencesRecord]
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Environment(\.currentProfile) private var profile
    @Environment(\.showsAdultContent) private var showsAdult
    @Environment(\.sourceRefresher) private var refresher
    @State private var activity = ShelfActivity()
    @Environment(\.displayScale) private var scale
    /// The largest the window has been, which every backdrop decodes for.
    @State private var window = CGSize.zero
    #if !os(tvOS)
        @Environment(\.publishesMenuCommands) private var publishesMenuCommands
    #endif

    func body(content: Content) -> some View {
        content
            .disabled(playback.playing != nil)
            #if !os(tvOS)
                // The player in front publishes the menu items, the screen under it none.
                .environment(\.publishesMenuCommands, publishesMenuCommands && playback.playing == nil)
            #endif
            .overlay {
                if let target = playback.playing {
                    ShelfPlayerView(playback: playback, target: target)
                }
            }
            // "No episodes available" with OK, or "Could not load episodes"
            // with Try again (movies-and-series-browsing/play-a-series-from-the-next-episode).
            .alert(Text(playback.problem?.message ?? ""), isPresented: showsProblem, presenting: playback.problem) { problem in
                if problem.retries {
                    Button("Try again") { playback.retry(problem.series, library: library, activity: activity) }
                    Button("Cancel", role: .cancel) {}
                } else {
                    Button("OK", role: .cancel) {}
                }
            }
            .followsSubtitlePreference { playback.subtitles = $0 }
            .environment(library)
            .environment(playback)
            .environment(activity)
            .task(id: profile) {
                // Continue watching and Up Next read these series' episodes
                // (movies-and-series-browsing/browsing-stays-responsive).
                library.series.keepsEpisodes = { [activity] in activity.seriesWithProgress.contains($0) }
                await activity.follow(ActivityStore(context: context, profile: profile))
            }
            .environment(\.posterLoader, Self.posters)
            .environment(\.posterPrefetcher, Self.loadsAhead ? Self.prefetcher : nil)
            .environment(\.artFit, PosterFit(width: window.width, height: window.height, scale: scale))
            .environment(\.shelfWindowWidth, window.width)
            // Only growing changes it, so a window being resized does not
            // load every picture again at each step.
            .onGeometryChange(for: CGSize.self) {
                $0.size
            } action: { size in
                let grown = CGSize(width: max(window.width, size.width), height: max(window.height, size.height))
                if grown != window { window = grown }
            }
            .environment(\.logoLoader, Self.logos)
            .modifier(TrailerOpener())
            .task(id: records.compactMap(\.descriptor)) {
                library.sourcesChanged(records.compactMap(\.descriptor))
                // A deleted source's matches go (title-metadata/matches-are-kept-on-the-device).
                await TitleLookups.app?.keepSources(Set(records.compactMap(\.descriptor).map(\.id)))
            }
            // title-metadata/lookups-can-be-turned-off, on this device or from another
            .task(id: PreferencesStore.current(preferences).lookupsEnabled) {
                await TitleLookups.app?.setEnabled(PreferencesStore.current(preferences).lookupsEnabled)
            }
            .onChange(of: TitleOffer(records: records, refresher: refresher), initial: true) { _, offer in
                library.offer = offer
            }
            // adult-content/adult-content-that-is-playing-stops
            .onChange(of: showsAdult, initial: true) { _, shows in
                library.showsAdult = shows
                if !shows, let playing = playback.playing, playing.title.isAdultContent {
                    Task { await playback.close() }
                }
            }
            // The poster a title played from takes focus back
            // (title-detail-and-episode-picker/back-to-where-you-were).
            .onChange(of: playback.playing == nil) { _, ended in
                if ended { library.playbackEnded() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { library.becameActive() }
                if phase == .background { playback.background() }
            }
    }

    /// One loader each for the app's life. A loader made in `body` is a new
    /// closure on every redraw, which SwiftUI reads as a changed environment
    /// and redraws every poster and logo for.
    private static let posters = ShelfView.PosterLoader(
        load: { await PosterCache.shared.poster(for: $0, fitting: $1) }, kept: { PosterCache.shared.kept($0, fitting: $1) })
    private static let prefetcher = PosterPrefetcher(
        prefetch: { await PosterCache.shared.prefetch($0, fitting: $1, group: $2) },
        retarget: { await PosterCache.shared.prefetch($0, fitting: $1, group: $2, replacing: true) },
        stop: { await PosterCache.shared.stopPrefetching($0) })

    private static var loadsAhead: Bool {
        #if DEBUG
            UITestingShelf.loadsAhead
        #else
            true
        #endif
    }
    private static let logos = LogoLoader(cached: { LogoCache.shared.cached($0) }, load: { await LogoCache.shared.logo(for: $0) })

    private var showsProblem: Binding<Bool> {
        Binding(get: { playback.problem != nil }, set: { if !$0 { playback.problem = nil } })
    }
}

/// In a Debug build launched for UI tests, links the title page opens are
/// recorded instead of leaving the app. Otherwise nothing changes.
private struct TrailerOpener: ViewModifier {
    func body(content: Content) -> some View {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains(UITestingShelf.argument) {
                content
                    .environment(\.openURL, UITestingShelf.Opened.shared.action)
                    .overlay { UITestingShelf.OpenedProbe() }
            } else {
                content
            }
        #else
            content
        #endif
    }
}

extension ShelfLibrary {
    /// The library for the app: scripted in a Debug build launched for UI
    /// tests, otherwise reading through `loader`'s session and Keychain.
    static func app(_ loader: SourceLoader) -> ShelfLibrary {
        #if DEBUG
            if let scripted = UITestingShelf.library() { return scripted }
        #endif
        return .live(ShelfLoader(session: loader.session, credentials: loader.credentials, playlists: loader))
    }
}

extension ShelfPlayback {
    /// Playback for the app: a scripted engine in a Debug build launched for
    /// UI tests, otherwise the routed engine with addresses built from the
    /// Keychain login. `willPlay` stops live TV.
    static func app(_ loader: SourceLoader, willPlay: @escaping @MainActor () async -> Void) -> ShelfPlayback {
        #if DEBUG
            if let scripted = UITestingShelf.playback(willPlay: willPlay) { return scripted }
        #endif
        let shelf = ShelfLoader(session: loader.session, credentials: loader.credentials, playlists: loader)
        return ShelfPlayback(
            .init(
                engine: RoutedEngine.app(),
                address: { source, target in
                    switch target {
                    case .movie(let movie): try shelf.movieURL(source, movie: movie)
                    case .episode(let episode, _): try shelf.episodeURL(source, episode: episode)
                    case .trailer(let url, _): url
                    }
                },
                willPlay: willPlay))
    }
}
