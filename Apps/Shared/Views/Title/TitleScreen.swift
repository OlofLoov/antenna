import AntennaCore
import SwiftData
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
    @Environment(\.layoutDirection) private var layoutDirection
    @Query private var preferences: [PreferencesRecord]
    @State private var expanded = false
    /// The About page over the title page: the whole description on Apple
    /// TV, or an episode's Description anywhere.
    @State private var about: TitleAboutText?
    /// What opened the About page, so focus goes back to it when it closes.
    @State private var aboutOpener: TitlePageContext.AboutOpener?
    @State private var attempt = 0

    private var model: TitleModel { route.model }

    var body: some View {
        page
            .environment(\.titlePage, context)
            .environment(\.episodes, route.title.kind == .series ? episodes : nil)
            .task(id: attempt) { await model.load(refresh: attempt > 0) }
            .onChange(of: PreferencesStore.current(preferences).lookupsEnabled) { _, on in
                Task { await model.lookupsChanged(on) }
            }
            .onChange(of: model.sourceExists) { _, exists in
                // A deleted source closes the page (title-detail-and-episode-picker/open-a-movie-s-page).
                if !exists { library.closeAll() }
            }
            .onChange(of: playback.playing) { _, playing in
                // Episodes that Up next started come back into view
                // (title-detail-and-episode-picker/play-an-episode-and-come-back).
                if case .episode(let episode, let series) = playing, series.id == route.title.id { model.played(episode) }
            }
            #if os(tvOS)
                .controlHints(.titlePage)
                .onExitCommand { library.closePage() }
                .fullScreenCover(item: $about, onDismiss: { aboutOpener = nil }) { text in
                    TitleAbout(text: text) { about = nil }
                    .presentationBackground { CoverBackdrop() }
                }
            #else
                .background { keys }
                .sheet(item: $about, onDismiss: { aboutOpener = nil }) { text in
                    TitleAbout(text: text) { about = nil }
                }
            #endif
            #if os(iOS)
                // iPadOS keeps Escape unless a key command asks for priority.
                .background { LiveEscapeKey { library.closePage() } }
            #endif
    }

    private var context: TitlePageContext {
        let metadata = model.metadata
        return TitlePageContext(
            state: .init(
                metadata: metadata, posterURL: route.title.posterURL, loading: model.phase == .loading, play: play,
                isOnMyList: activity.isOnMyList(route.title), problem: problem, expanded: expandsInPlace && expanded,
                section: backTitle, aboutOpen: aboutOpener,
                chips: model.credits.chips, returningChip: returningChip),
            actions: .init(
                back: { library.closePage() }, play: start, toggleMyList: { activity.toggleMyList(route.title) },
                retry: { attempt += 1 }, expand: expand,
                trailer: ShelfActions.trailer(metadata.trailerURL, of: route.title, playback: playback, openURL: openURL),
                openPerson: { library.openPerson($0.name, chip: $0.id) }, restored: { library.restored() }))
    }

    /// Where Back leads: the person's name over a person's page, else the section.
    private var backTitle: LocalizedStringResource {
        if let index = library.stack.firstIndex(of: .title(route)), index > 0, case .person(let person) = library.stack[index - 1] {
            return .verbatim(person.name.display)
        }
        return route.section.sectionTitle
    }

    /// The chip whose person's page just closed over this page.
    private var returningChip: String? {
        guard case .person(let person)? = library.popped, library.page == route else { return nil }
        return person.chip
    }

    /// More: the About page on Apple TV, the whole text in place elsewhere.
    private func expand() {
        if expandsInPlace {
            expanded = true
        } else {
            aboutOpener = .more
            about = TitleAboutText(model.metadata)
        }
    }

    /// iPhone, iPad and Mac show the whole description in place; Apple TV opens the About page.
    private var expandsInPlace: Bool {
        #if os(tvOS)
            false
        #else
            true
        #endif
    }

    /// A movie's failure shows under the buttons; a series' shows in place of its episodes.
    private var problem: LocalizedStringResource? {
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
                skipped: model.phase == .loaded ? EpisodeText.skipped(model.skipped) : nil, dwell: dwell,
                reveal: playback.playing == nil ? model.lastPlayed : nil, aboutOpen: aboutOpener),
            actions: .init(
                pick: { model.pickedSeason = $0 }, play: playEpisode, retry: { attempt += 1 },
                describe: { episode in
                    aboutOpener = .episode(episode.id)
                    about = TitleAboutText(episode)
                }))
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
        /// Left and right pick the season before or after, in the reading
        /// direction, and Return presses Play.
        private var keys: some View {
            ZStack {
                Button("Previous season") { moveSeason(-1) }
                    .keyboardShortcut(layoutDirection.leadingArrow, modifiers: [])
                Button("Next season") { moveSeason(1) }
                    .keyboardShortcut(layoutDirection.trailingArrow, modifiers: [])
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
        case .movie: .movie(activity.progress(of: route.title))
        case .series: .series(target, progress: seriesProgress)
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
            _ = model.willPlay(target.episode, progress: seriesProgress)
            playback.play(target.episode, of: route.title, from: target.position, library: library, activity: activity)
        }
    }

    /// Plays an episode from where the user stopped, with its season kept
    /// for the return (title-detail-and-episode-picker/play-an-episode-and-come-back).
    private func playEpisode(_ episode: Episode) {
        guard model.checkLogin() else { return }
        let from = model.willPlay(episode, progress: seriesProgress)
        playback.play(episode, of: route.title, from: from, library: library, activity: activity)
    }
}

extension TitlePageContext.PlayState {
    /// A movie's button: Resume with the bar and minutes left while it is
    /// in progress, else Play from the start
    /// (title-detail-and-episode-picker/play-or-resume-a-movie).
    static func movie(_ saved: WatchProgress?) -> Self {
        guard let saved, saved.state == .inProgress else { return Self(label: PlayLabel.text(resumes: false), enabled: true) }
        return Self(
            label: PlayLabel.text(resumes: true), enabled: true, fraction: EpisodeText.fraction(saved), remaining: ShelfText.left(saved))
    }

    /// A series' button, naming the episode Play starts; disabled until
    /// there is one (title-detail-and-episode-picker/play-starts-the-right-episode).
    static func series(_ target: SeriesPlayTarget?, progress: [String: WatchProgress]) -> Self {
        guard let target else { return Self(label: PlayLabel.text(resumes: false), enabled: false) }
        let saved = target.resumes ? progress[target.episode.id] : nil
        return Self(
            label: target.label, enabled: true, fraction: saved.flatMap(EpisodeText.fraction),
            remaining: saved.flatMap { ShelfText.left($0) })
    }
}
