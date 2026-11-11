import AntennaCore
import SwiftUI

/// What the season picker and the episode list share
/// (title-detail-and-episode-picker/pick-a-season,
/// title-detail-and-episode-picker/what-each-episode-shows). The title
/// screen sets it for a series.
struct EpisodesContext {
    struct State {
        /// Every group, for the picker; one group shows no picker.
        var seasons: [Season]
        /// The picked group's id.
        var picked: String?
        /// The picked group's episodes.
        var rows: [Row]
        var phase: Phase
        /// "1 episode could not be read from the provider's list."
        var skipped: String?
        /// On Apple TV, how long focus rests on a chip before its season
        /// shows; nil picks on select only.
        var dwell: Duration?
        /// The episode to bring into view, the one just played.
        var reveal: String?
    }

    /// Where the list stands.
    enum Phase: Equatable {
        case loading
        case episodes
        /// "No episodes available".
        case empty
        /// What failed, with Retry.
        case failed(String)
    }

    struct Season: Equatable, Identifiable {
        var id: String
        var title: String
        /// "8 episodes".
        var count: String
    }

    struct Row: Equatable, Identifiable {
        var episode: Episode
        /// "Watched", "44 min · 21 min left" or "44 min".
        var status: String?
        /// 0 to 1; nil looks unwatched.
        var fraction: Double?
        var upNext: Bool
        /// What VoiceOver reads.
        var label: String

        var id: String { episode.id }
    }

    struct Actions {
        var pick: (String) -> Void
        var play: (Episode) -> Void
        var retry: () -> Void
    }

    var state: State
    var actions: Actions
}

extension EnvironmentValues {
    /// Set by the title screen around a series page.
    @Entry var episodes: EpisodesContext?
}

/// The season chips and the episode rows under a series page (boards
/// `iPhone-Series`, `iPad-Series`, `TV-Series`). Identifiers start with
/// `episodes.`.
enum EpisodePicker {
    struct Sizes: Equatable {
        var chip: CGFloat
        var chipText: CGFloat
        var row: CGFloat
        var thumbnail: CGSize
        var corner: CGFloat
        var title: CGFloat
        var line: CGFloat
        var number: CGFloat
        var badge: CGFloat
        var progress: CGFloat
        var gutter: CGFloat
        var spacing: CGFloat

        /// `iPhone-Series`: 30 pt chips with a 44 pt target, 84 pt rows.
        static let phone = Sizes(
            chip: 30, chipText: 13, row: 84, thumbnail: CGSize(width: 112, height: 63), corner: 10, title: 15, line: 13, number: 15,
            badge: 10, progress: 3, gutter: 16, spacing: 10)
        /// `iPad-Series`: 34 pt chips with a 44 pt target, 96 pt rows.
        static let pad = Sizes(
            chip: 34, chipText: 14, row: 96, thumbnail: CGSize(width: 136, height: 76), corner: 12, title: 16, line: 14, number: 22,
            badge: 11, progress: 4, gutter: 24, spacing: 12)
        /// `TV-Series`: 64 pt chips, 128 pt rows.
        static let tv = Sizes(
            chip: 64, chipText: 24, row: 128, thumbnail: CGSize(width: 192, height: 108), corner: 14, title: 26, line: 22, number: 32,
            badge: 17, progress: 6, gutter: 96, spacing: 20)
    }

    /// The picker over the list, the list or its state, and the count of
    /// unreadable episodes under it.
    struct Section: View {
        let type: Sizes
        @Environment(\.episodes) private var episodes

        var body: some View {
            if let episodes {
                VStack(alignment: .leading, spacing: type.spacing) {
                    Seasons(type: type)
                    switch episodes.state.phase {
                    case .loading:
                        Loading(type: type)
                    case .empty:
                        Note(type: type, text: "No episodes available", identifier: "episodes.empty")
                    case .failed(let message):
                        Failure(type: type, message: message)
                    case .episodes:
                        List(type: type)
                    }
                    if let skipped = episodes.state.skipped {
                        Text(skipped)
                            .font(.system(size: type.line))
                            .foregroundStyle(Palette.textMuted)
                            .padding(.horizontal, type.gutter)
                            .accessibilityIdentifier("episodes.skipped")
                    }
                }
            }
        }
    }

    /// One chip per group, the picked one on the 0.12 surface at weight
    /// 600, and the picked group's count at the trailing edge. Hidden with
    /// one group.
    struct Seasons: View {
        let type: Sizes
        @Environment(\.episodes) private var episodes

        var body: some View {
            if let episodes, episodes.state.seasons.count > 1 {
                HStack(spacing: type.spacing) {
                    ScrollView(.horizontal) {
                        HStack(spacing: type.spacing / 2) {
                            ForEach(episodes.state.seasons) { season in
                                SeasonChip(
                                    type: type, season: season, isPicked: season.id == episodes.state.picked,
                                    dwell: episodes.state.dwell
                                ) {
                                    episodes.actions.pick(season.id)
                                }
                            }
                        }
                        .padding(.horizontal, type.gutter)
                        .padding(.vertical, 6)
                    }
                    .scrollIndicators(.hidden)
                    .scrollClipDisabled()
                    if let count = episodes.state.seasons.first(where: { $0.id == episodes.state.picked })?.count {
                        Text(count)
                            .font(.system(size: type.line))
                            .foregroundStyle(Palette.textMuted)
                            .fixedSize()
                            .padding(.trailing, type.gutter)
                            .accessibilityIdentifier("episodes.count")
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("episodes.seasons")
            }
        }
    }

    /// A season chip. `isPicked` names the data, the picked season.
    struct SeasonChip: View {
        let type: Sizes
        let season: EpisodesContext.Season
        let isPicked: Bool
        let dwell: Duration?
        let pick: () -> Void
        @FocusState private var focused: Bool

        var body: some View {
            Button(action: pick) {
                Text(season.title)
                    .font(.system(size: type.chipText, weight: isPicked ? .semibold : .regular))
                    .lineLimit(1)
                    .padding(.horizontal, type.chipText)
                    .frame(height: type.chip)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ChipStyle(isPicked: isPicked, height: type.chip))
            .accessibilityValue(isPicked ? "Selected, \(season.count)" : season.count)
            .accessibilityAddTraits(isPicked ? .isSelected : [])
            .accessibilityIdentifier("episodes.season.\(season.id)")
            .focused($focused)
            .task(id: focused) {
                // Resting on a chip picks its season.
                guard focused, !isPicked, let dwell else { return }
                try? await Task.sleep(for: dwell)
                guard !Task.isCancelled else { return }
                pick()
            }
        }
    }

    /// The 0.12 surface when picked, the white card when focused on Apple TV.
    private struct ChipStyle: ButtonStyle {
        let isPicked: Bool
        let height: CGFloat

        func makeBody(configuration: Configuration) -> some View {
            ChipLabel(label: configuration.label, isPicked: isPicked, height: height, isPressed: configuration.isPressed)
        }
    }

    private struct ChipLabel<Label: View>: View {
        let label: Label
        let isPicked: Bool
        let height: CGFloat
        let isPressed: Bool
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            label
                .foregroundStyle(isFocused ? Palette.ground : isPicked ? Palette.text : Browse.textSecondary)
                .background {
                    Capsule()
                        .fill(isFocused ? Palette.focus : isPicked ? Palette.surface(0.12) : .clear)
                        .frame(height: height)
                }
                .scaleEffect(isFocused ? 1.06 : 1)
                .opacity(isPressed ? 0.7 : 1)
                .animation(.easeOut(duration: 0.15), value: isFocused)
        }
    }

    /// The picked season's episodes in order. Rows build as they scroll in,
    /// so pictures load only for rows near the screen.
    struct List: View {
        let type: Sizes
        @Environment(\.episodes) private var episodes

        var body: some View {
            if let episodes {
                ScrollViewReader { proxy in
                    LazyVStack(alignment: .leading, spacing: type.spacing) {
                        ForEach(episodes.state.rows) { row in
                            EpisodeRow(type: type, row: row) { episodes.actions.play(row.episode) }
                                .id(row.id)
                        }
                    }
                    .padding(.horizontal, type.gutter)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("episodes.list")
                    .task(id: episodes.state.reveal) {
                        // Back from playback, the episode just played is in view.
                        guard let reveal = episodes.state.reveal else { return }
                        proxy.scrollTo(reveal, anchor: .center)
                    }
                }
            }
        }
    }

    /// The picture with its bar, the number, the title with UP NEXT, the
    /// length or Watched, and one line of description. Missing parts are
    /// left out; with no picture the tile shows the number.
    struct EpisodeRow: View {
        let type: Sizes
        let row: EpisodesContext.Row
        let play: () -> Void

        var body: some View {
            let episode = row.episode
            Button(action: play) {
                HStack(spacing: type.spacing) {
                    Thumbnail(type: type, url: episode.thumbnailURL, number: episode.number)
                        .overlay(alignment: .bottom) {
                            if let fraction = row.fraction {
                                Bar(fraction: fraction, height: type.progress)
                                    .accessibilityIdentifier("episodes.row.\(episode.id).progress")
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: type.corner * 0.7, style: .continuous))
                    if let number = episode.number {
                        Text("\(number)")
                            .font(.system(size: type.number, weight: .bold).monospacedDigit())
                            .foregroundStyle(Palette.textMuted)
                            .frame(minWidth: type.number * 1.2)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: type.spacing / 2) {
                            Text(episode.title)
                                .font(.system(size: type.title, weight: .semibold))
                                .foregroundStyle(Palette.text)
                                .lineLimit(1)
                            if row.upNext {
                                Text("UP NEXT")
                                    .font(.system(size: type.badge, weight: .bold))
                                    .tracking(1)
                                    .foregroundStyle(Palette.ground)
                                    .padding(.vertical, type.badge / 5)
                                    .padding(.horizontal, type.badge / 2)
                                    .background(Palette.accent, in: RoundedRectangle(cornerRadius: 4))
                                    .fixedSize()
                                    .accessibilityIdentifier("episodes.row.\(episode.id).upNext")
                            }
                        }
                        if let status = row.status {
                            Text(status)
                                .font(.system(size: type.line))
                                .foregroundStyle(Browse.textSecondary)
                                .lineLimit(1)
                        }
                        if let plot = episode.plot {
                            Text(plot)
                                .font(.system(size: type.line))
                                .foregroundStyle(Palette.textMuted)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(type.spacing * 0.8)
                .frame(minHeight: type.row)
                .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: type.corner, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(ShelfView.CardStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(row.label)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("episodes.row.\(episode.id)")
        }
    }

    /// The episode's picture, or its number on the placeholder.
    struct Thumbnail: View {
        let type: Sizes
        let url: URL?
        let number: Int?
        @Environment(\.posterLoader) private var loader
        @State private var poster: Poster?

        var body: some View {
            ZStack {
                TitlePage.placeholder
                if let image = poster?.image {
                    Image(decorative: image, scale: 1).resizable().scaledToFill()
                } else if let number {
                    Text("\(number)")
                        .font(.system(size: type.number, weight: .bold))
                        .foregroundStyle(Palette.textMuted)
                }
            }
            .frame(width: type.thumbnail.width, height: type.thumbnail.height)
            .clipped()
            .accessibilityHidden(true)
            .task(id: url) {
                poster = nil
                guard let url, let loader else { return }
                poster = await loader.load(url)
            }
        }
    }

    /// A 0 to 1 progress bar in the accent color along the picture's foot.
    struct Bar: View {
        let fraction: Double
        let height: CGFloat

        var body: some View {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Palette.surface(0.22))
                    Rectangle().fill(Palette.accent).frame(width: proxy.size.width * min(1, max(0, fraction)))
                }
            }
            .frame(height: height)
            .accessibilityHidden(true)
        }
    }
}
