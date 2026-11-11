import AntennaCore
import SwiftUI

/// A title page over its section (title-detail-and-episode-picker). Loads
/// the details while it shows, says what Play, My list and each episode do,
/// and closes when the user goes back or the title's source is deleted. The
/// host screen picks the arrangement with `page`.
struct TitleScreen<Page: View>: View {
    let route: TitleRoute
    @ViewBuilder var page: Page
    @Environment(ShelfLibrary.self) private var library
    @Environment(ShelfActivity.self) private var activity
    @Environment(ShelfPlayback.self) private var playback
    @Environment(\.openURL) private var openURL
    @State private var expanded = false
    @State private var attempt = 0

    private var model: TitleModel { route.model }

    var body: some View {
        page
            .environment(\.titlePage, context)
            .environment(\.episodes, route.title.kind == .series ? episodes : nil)
            .task(id: attempt) { await model.load() }
            .onChange(of: model.sourceExists) { _, exists in
                // A deleted source closes the page (title-detail-and-episode-picker/open-a-movie-s-page).
                if !exists { library.closePage() }
            }
            #if os(tvOS)
                .onExitCommand { library.closePage() }
                .sheet(isPresented: $expanded) {
                    PlotSheet(name: model.metadata.name, text: model.metadata.description ?? "")
                }
            #else
                .background { keys }
            #endif
    }

    private var context: TitlePageContext {
        let metadata = model.metadata
        return TitlePageContext(
            state: .init(
                metadata: metadata, posterURL: route.title.posterURL, loading: model.phase == .loading, play: play,
                isOnMyList: activity.isOnMyList(route.title), problem: problem, expanded: expandsInPlace && expanded,
                section: route.section.sectionTitle),
            actions: .init(
                back: { library.closePage() }, play: start, toggleMyList: { activity.toggleMyList(route.title) },
                retry: { attempt += 1 }, expand: { expanded = true },
                trailer: metadata.trailerURL.map { url in { openURL(url) } }))
    }

    /// iPhone, iPad and Mac show the whole description in place; Apple TV opens a sheet.
    private var expandsInPlace: Bool {
        #if os(tvOS)
            false
        #else
            true
        #endif
    }

    /// A movie's failure shows under the buttons; a series' shows in place of its episodes.
    private var problem: String? {
        guard route.title.kind == .movie, case .failed(let problem) = model.phase else { return nil }
        return problem.message(.movie)
    }

    // MARK: Episodes

    private var episodes: EpisodesContext {
        let groups = model.groups
        let target = target
        let picked =
            model.pickedSeason ?? target.flatMap { target in groups.first { $0.episodes.contains(target.episode) }?.id }
            ?? groups.first?.id
        let progress = seriesProgress
        let rows = (groups.first { $0.id == picked }?.episodes ?? []).map { episode in
            let saved = progress[episode.id]
            let upNext = target?.episode.id == episode.id
            return EpisodesContext.Row(
                episode: episode, status: EpisodeText.status(episode, progress: saved), fraction: EpisodeText.fraction(saved),
                upNext: upNext, label: EpisodeText.accessibilityLabel(episode, progress: saved, upNext: upNext))
        }
        let phase: EpisodesContext.Phase =
            switch model.phase {
            case .loading: .loading
            case .failed(let problem): .failed(problem.message(.series))
            case .loaded: groups.isEmpty ? .empty : .episodes
            }
        return EpisodesContext(
            state: .init(
                seasons: groups.map { .init(id: $0.id, title: $0.title, count: $0.countLabel) }, picked: picked, rows: rows, phase: phase,
                skipped: model.phase == .loaded ? EpisodeText.skipped(model.skipped) : nil, dwell: dwell),
            actions: .init(pick: { model.pickedSeason = $0 }, play: playEpisode, retry: { attempt += 1 }))
    }

    /// On Apple TV a season shows after focus rests on its chip for 300 ms.
    private var dwell: Duration? {
        #if os(tvOS)
            .milliseconds(300)
        #else
            nil
        #endif
    }

    /// The picked season moved by `steps`, for the arrow keys.
    private func moveSeason(_ steps: Int) {
        let ids = model.groups.map(\.id)
        guard let current = episodes.state.picked, let index = ids.firstIndex(of: current) else { return }
        model.pickedSeason = ids[min(max(0, index + steps), ids.count - 1)]
    }

    #if !os(tvOS)
        /// Left and right pick the season before or after, Return presses Play.
        private var keys: some View {
            ZStack {
                Button("Previous season") { moveSeason(-1) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("Next season") { moveSeason(1) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                Button("Play") { start() }
                    .keyboardShortcut(.return, modifiers: [])
            }
            .opacity(0)
            .accessibilityHidden(true)
        }
    #endif

    // MARK: Play

    /// The series' saved positions by episode id.
    private var seriesProgress: [String: WatchProgress] {
        ContinueWatching.episodeProgress(activity.progress, seriesID: route.title.id, sourceID: route.title.sourceID)
    }

    /// The episode Play starts, for a series once its episodes are in.
    private var target: SeriesPlayTarget? {
        SeriesPlayTarget.resolve(episodes: model.episodes, progress: seriesProgress)
    }

    private var play: TitlePageContext.PlayState {
        switch route.title.kind {
        case .movie:
            let saved = activity.progress(of: route.title)
            guard let saved, saved.state == .inProgress else { return .init(label: PlayLabel.text(resumes: false), enabled: true) }
            return .init(
                label: PlayLabel.text(resumes: true), enabled: true, fraction: EpisodeText.fraction(saved), remaining: ShelfText.left(saved)
            )
        case .series:
            guard let target else { return .init(label: PlayLabel.text(resumes: false), enabled: false) }
            let saved = target.resumes ? seriesProgress[target.episode.id] : nil
            return .init(
                label: target.label, enabled: true, fraction: saved.flatMap(EpisodeText.fraction), remaining: saved.flatMap(ShelfText.left))
        }
    }

    /// Plays the movie or the episode Play names. Without the login on this
    /// device nothing plays and the waiting line shows.
    private func start() {
        guard model.checkLogin() else { return }
        switch route.title.kind {
        case .movie:
            playback.play(model.playable, library: library, activity: activity)
        case .series:
            guard let target else { return }
            playback.play(target.episode, of: route.title, from: target.position, library: library, activity: activity)
        }
    }

    /// Plays an episode from where the user stopped, with its season kept
    /// for the return (title-detail-and-episode-picker/play-an-episode-and-come-back).
    private func playEpisode(_ episode: Episode) {
        guard model.checkLogin() else { return }
        model.pickedSeason = model.groups.first { $0.episodes.contains(episode) }?.id
        let from = seriesProgress[episode.id]?.resumePosition ?? 0
        playback.play(episode, of: route.title, from: from, library: library, activity: activity)
    }
}

#if os(tvOS)
    /// The whole description on Apple TV, which More opens.
    private struct PlotSheet: View {
        let name: String
        let text: String

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(name)
                        .font(.system(size: 48, weight: .bold))
                    Text(text)
                        .font(.system(size: 30))
                        .lineSpacing(8)
                }
                .foregroundStyle(Palette.text)
                .frame(maxWidth: 1200, alignment: .leading)
                .padding(80)
            }
            .focusable()
            .accessibilityIdentifier("title.plotSheet")
        }
    }
#endif
