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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Environment(\.currentProfile) private var profile
    @Environment(\.sourceRefresher) private var refresher
    @State private var activity = ShelfActivity()

    func body(content: Content) -> some View {
        content
            .disabled(playback.playing != nil)
            .overlay {
                if let target = playback.playing {
                    ShelfPlayerView(playback: playback, target: target)
                }
            }
            // "No episodes available" with OK, or "Could not load episodes"
            // with Retry (movies-and-series-browsing/play-a-series-from-the-next-episode).
            .alert(playback.problem?.message ?? "", isPresented: showsProblem, presenting: playback.problem) { problem in
                if problem.retries {
                    Button("Retry") { playback.retry(problem.series, library: library, activity: activity) }
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
                await activity.follow(ActivityStore(context: context, profile: profile))
            }
            .environment(\.posterLoader, ShelfView.PosterLoader { await PosterCache.shared.poster(for: $0) })
            .modifier(TrailerOpener())
            .task(id: records.compactMap(\.descriptor)) {
                library.sourcesChanged(records.compactMap(\.descriptor))
            }
            .onChange(of: TitleOffer(records: records, refresher: refresher), initial: true) { _, offer in
                library.offer = offer
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { library.becameActive() }
                if phase == .background { playback.background() }
            }
    }

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
                    }
                },
                willPlay: willPlay))
    }
}
