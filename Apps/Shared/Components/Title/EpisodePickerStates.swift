import AntennaCore
import SwiftUI

extension EpisodePicker {
    /// Three placeholder rows while the episodes are on their way.
    struct Loading: View {
        let type: Sizes

        var body: some View {
            VStack(spacing: type.spacing) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: type.corner, style: .continuous)
                        .fill(Palette.surface(0.06))
                        .frame(height: type.row)
                }
            }
            .padding(.horizontal, type.gutter)
            .overlay { ProgressView().tint(Palette.textMuted) }
            .accessibilityElement()
            .accessibilityLabel("Loading episodes")
            .accessibilityIdentifier("episodes.loading")
        }
    }

    /// A line of muted text in place of the list.
    struct Note: View {
        let type: Sizes
        let text: String
        let identifier: String

        var body: some View {
            Text(text)
                .font(.system(size: type.title))
                .foregroundStyle(Browse.textSecondary)
                .padding(.horizontal, type.gutter)
                .padding(.vertical, type.spacing)
                .accessibilityIdentifier(identifier)
        }
    }

    /// What failed and Retry, in place of the list.
    struct Failure: View {
        let type: Sizes
        let message: String
        @Environment(\.episodes) private var episodes

        var body: some View {
            VStack(alignment: .leading, spacing: type.spacing) {
                Text(message)
                    .font(.system(size: type.title))
                    .foregroundStyle(Browse.textSecondary)
                    .accessibilityIdentifier("episodes.error")
                Button {
                    episodes?.actions.retry()
                } label: {
                    Text("Retry")
                        .font(.system(size: type.title, weight: .semibold))
                        .padding(.horizontal, type.title * 1.2)
                        .frame(minHeight: max(44, type.chip))
                }
                .buttonStyle(ShelfBanner.BannerButtonStyle(fill: .secondary))
                .accessibilityIdentifier("episodes.retry")
            }
            .padding(.horizontal, type.gutter)
        }
    }
}

extension EpisodesContext {
    /// Episodes for previews: watched, up next part-way, no description,
    /// and no title or picture.
    static var preview: EpisodesContext {
        let episodes = [
            Episode(
                id: "e3", episodeID: 3, season: 2, number: 3, title: "The Weir", duration: 2_700,
                plot: "The generator fails on the first night. Ása goes out alone to the weir."),
            Episode(
                id: "e4", episodeID: 4, season: 2, number: 4, title: "Low Water", duration: 2_640,
                plot: "The tide drops further than the charts allow."),
            Episode(id: "e5", episodeID: 5, season: 2, number: 5, title: "Ice Road", duration: 2_460),
            Episode(id: "e6", episodeID: 6, season: 2, number: 6, title: "Episode 6", duration: 2_580),
        ]
        let rows = [
            Row(episode: episodes[0], status: "Watched", fraction: 1, upNext: false, label: "Episode 3, The Weir, 45 min, watched"),
            Row(
                episode: episodes[1], status: "44 min · 21 min left", fraction: 0.52, upNext: true,
                label: "Episode 4, Low Water, 44 min, 21 min left, up next"),
            Row(episode: episodes[2], status: "41 min", fraction: nil, upNext: false, label: "Episode 5, Ice Road, 41 min"),
            Row(episode: episodes[3], status: "43 min", fraction: nil, upNext: false, label: "Episode 6, 43 min"),
        ]
        let seasons = ["Season 1", "Season 2", "Season 3", "Specials"].map { title in
            Season(id: title, title: title, count: "8 episodes")
        }
        return EpisodesContext(
            state: State(
                seasons: seasons, picked: "Season 2", rows: rows, phase: .episodes,
                skipped: "1 episode could not be read from the provider's list."),
            actions: Actions(pick: { _ in }, play: { _ in }, retry: {}))
    }
}

#Preview("Episodes, iPhone", traits: .fixedLayout(width: 390, height: 560)) {
    EpisodePicker.Section(type: .phone)
        .environment(\.episodes, .preview)
        .background(Palette.ground)
}

#Preview("Episodes, iPad", traits: .fixedLayout(width: 914, height: 640)) {
    EpisodePicker.Section(type: .pad)
        .environment(\.episodes, .preview)
        .environment(\.shelfMetrics, .pad)
        .background(Palette.ground)
}

#Preview("Episodes, Apple TV", traits: .fixedLayout(width: 1920, height: 900)) {
    EpisodePicker.Section(type: .tv)
        .environment(\.episodes, .preview)
        .environment(\.shelfMetrics, .tv)
        .background(Palette.ground)
}

#Preview("Loading and failed episodes, iPhone", traits: .fixedLayout(width: 390, height: 520)) {
    VStack(alignment: .leading, spacing: 24) {
        EpisodePicker.Section(type: .phone)
            .environment(\.episodes, EpisodesContext(state: .init(seasons: [], rows: [], phase: .loading), actions: .preview))
        EpisodePicker.Section(type: .phone)
            .environment(
                \.episodes,
                EpisodesContext(state: .init(seasons: [], rows: [], phase: .failed("Could not load episodes")), actions: .preview))
        EpisodePicker.Section(type: .phone)
            .environment(\.episodes, EpisodesContext(state: .init(seasons: [], rows: [], phase: .empty), actions: .preview))
    }
    .background(Palette.ground)
}

extension EpisodesContext.Actions {
    /// Actions that do nothing, for previews.
    static var preview: Self { Self(pick: { _ in }, play: { _ in }, retry: {}) }
}
