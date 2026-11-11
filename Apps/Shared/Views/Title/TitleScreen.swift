import AntennaCore
import SwiftUI

/// A title page over its section (title-detail-and-episode-picker). Loads
/// the details while it shows, says what Play and My list do, and closes
/// when the user goes back or the title's source is deleted. The host
/// screen picks the arrangement with `page`.
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

    private var problem: String? {
        guard case .failed(let problem) = model.phase else { return nil }
        return problem.message(route.title.kind)
    }

    // MARK: Play

    /// The episode Play starts, for a series once its episodes are in.
    private var target: SeriesPlayTarget? {
        let progress = ContinueWatching.episodeProgress(activity.progress, seriesID: route.title.id, sourceID: route.title.sourceID)
        return SeriesPlayTarget.resolve(episodes: model.episodes, progress: progress)
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
            let saved = target.resumes ? episodeProgress(target.episode) : nil
            return .init(
                label: target.label, enabled: true, fraction: saved.flatMap(EpisodeText.fraction), remaining: saved.flatMap(ShelfText.left))
        }
    }

    private func episodeProgress(_ episode: Episode) -> WatchProgress? {
        activity.progress.first { $0.titleID == episode.id && $0.sourceID == route.title.sourceID }
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
