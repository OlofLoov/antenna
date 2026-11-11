import AntennaCore
import SwiftUI

/// What a title page's parts share: the words, the Play button's state and
/// what the buttons do (title-detail-and-episode-picker). The screen sets it.
struct TitlePageContext {
    struct State {
        var metadata: TitleMetadata
        /// Shown until a backdrop arrives, and on Apple TV behind the copy.
        var posterURL: URL?
        /// True while the details are on their way.
        var loading: Bool
        var play: PlayState
        var isOnMyList: Bool
        /// "Could not load details", the offline message or the waiting
        /// line, under the buttons; nil when nothing failed.
        var problem: String?
        /// The description shows in full.
        var expanded: Bool
        /// Where Back leads: "Movies" or "Series".
        var section: String
    }

    /// The Play button: its words, and for something part-way the bar and
    /// the minutes left.
    struct PlayState: Equatable {
        var label: String
        var enabled: Bool
        /// 0 to 1; nil hides the bar.
        var fraction: Double?
        /// "52 min left".
        var remaining: String?
    }

    struct Actions {
        var back: () -> Void
        var play: () -> Void
        var toggleMyList: () -> Void
        var retry: () -> Void
        /// Shows the whole description.
        var expand: () -> Void
        /// Opens the trailer outside the app; nil without a link.
        var trailer: (() -> Void)?
    }

    var state: State
    var actions: Actions
}

extension EnvironmentValues {
    /// Set by the title screen around the page.
    @Entry var titlePage: TitlePageContext?
}

/// A movie's or series' page, one arrangement per board (`iPhone-Title`,
/// `iPad-Title`, `TV-Title` and their Series boards). Identifiers start
/// with `title.`.
enum TitlePage {
    /// The boards' type and button sizes.
    struct Sizes: Equatable {
        var eyebrow: CGFloat
        var name: CGFloat
        var meta: CGFloat
        var badge: CGFloat
        var plot: CGFloat
        var button: CGFloat
        var buttonHeight: CGFloat
        var spacing: CGFloat
        var progress: CGFloat

        static let phone = Sizes(
            eyebrow: 11, name: 28, meta: 13, badge: 10, plot: 14, button: 15, buttonHeight: 44, spacing: 10, progress: 3)
        static let pad = Sizes(
            eyebrow: 12, name: 40, meta: 14, badge: 11, plot: 15, button: 15, buttonHeight: 44, spacing: 12, progress: 4)
        static let tv = Sizes(
            eyebrow: 20, name: 72, meta: 24, badge: 17, plot: 26, button: 26, buttonHeight: 70, spacing: 22, progress: 6)
    }

    /// The board's placeholder color behind missing artwork.
    static let placeholder = Color(red: 0x22 / 255, green: 0x30 / 255, blue: 0x4A / 255)

    /// The first backdrop scaled to fill. Without one the poster sits on
    /// the placeholder, and without a poster its name tile does.
    struct Backdrop: View {
        /// The poster's size when there is no backdrop.
        let poster: CGSize
        @Environment(\.titlePage) private var page
        @Environment(\.posterLoader) private var loader
        @State private var image: Poster?

        var body: some View {
            let backdrop = page?.state.metadata.backdropURL
            ZStack {
                placeholder
                if let image = image?.image {
                    Image(decorative: image, scale: 1).resizable().scaledToFill()
                } else if backdrop == nil, let page {
                    ShelfView.PosterArt(name: page.state.metadata.name, url: page.state.posterURL)
                        .frame(width: poster.width, height: poster.height)
                        .accessibilityIdentifier("title.poster")
                }
            }
            .clipped()
            .accessibilityHidden(true)
            .accessibilityIdentifier("title.backdrop")
            .task(id: backdrop) {
                image = nil
                guard let backdrop, let loader else { return }
                image = await loader.load(backdrop)
            }
        }
    }

    /// "MOVIE · THRILLER" in the accent color, as design.md allows.
    struct Eyebrow: View {
        let type: Sizes
        @Environment(\.titlePage) private var page

        var body: some View {
            if let text = page?.state.metadata.eyebrow {
                Text(text.uppercased())
                    .font(.system(size: type.eyebrow, weight: .semibold))
                    .tracking(type.eyebrow / 8)
                    .foregroundStyle(Palette.accent)
                    .lineLimit(1)
                    .accessibilityLabel(text)
                    .accessibilityIdentifier("title.eyebrow")
            }
        }
    }

    struct Name: View {
        let type: Sizes
        @Environment(\.titlePage) private var page

        var body: some View {
            if let name = page?.state.metadata.name {
                Text(name)
                    .font(.system(size: type.name, weight: .heavy))
                    .foregroundStyle(Palette.text)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("title.name")
            }
        }
    }

    /// Year, length or seasons, genre and rating between dots, then the
    /// badges; wraps at large text sizes. A loading bar while the details
    /// are on their way.
    struct Meta: View {
        let type: Sizes
        @Environment(\.titlePage) private var page

        var body: some View {
            if let page {
                let meta = page.state.metadata
                if page.state.loading {
                    ProgressView()
                        .tint(Palette.textMuted)
                        .frame(height: type.meta * 1.4)
                        .accessibilityLabel("Loading details")
                        .accessibilityIdentifier("title.loading")
                } else if !(meta.facts.isEmpty && meta.badges.isEmpty) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: type.meta / 2) { parts(meta) }
                        VStack(alignment: .leading, spacing: type.meta / 3) { parts(meta) }
                    }
                    .font(.system(size: type.meta))
                    .foregroundStyle(Browse.textSecondary)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        (meta.facts.map { $0.replacingOccurrences(of: "★ ", with: "rating ") } + meta.badges).joined(separator: ", ")
                    )
                    .accessibilityIdentifier("title.meta")
                }
            }
        }

        @ViewBuilder private func parts(_ meta: TitleMetadata) -> some View {
            if let line = meta.detailsLine {
                Text(line)
            }
            if !meta.badges.isEmpty {
                HStack(spacing: type.meta / 2) {
                    ForEach(meta.badges, id: \.self) { badge in
                        ShelfBanner.Badge(text: badge, size: type.badge)
                    }
                }
                .accessibilityIdentifier("title.badges")
            }
        }
    }

    /// The description cut to `lines`, with More when it runs over. More
    /// expands it in place; on Apple TV the screen opens it in a sheet.
    struct Plot: View {
        let type: Sizes
        let lines: Int
        @Environment(\.titlePage) private var page
        @State private var cutHeight: CGFloat = 0
        @State private var fullHeight: CGFloat = 0

        var body: some View {
            if let page, let text = page.state.metadata.description {
                VStack(alignment: .leading, spacing: type.spacing / 2) {
                    styled(text)
                        .lineLimit(page.state.expanded ? nil : lines)
                        .fixedSize(horizontal: false, vertical: true)
                        .background {
                            // Both heights, to tell whether the cut hides anything.
                            ZStack {
                                styled(text).lineLimit(lines).fixedSize(horizontal: false, vertical: true)
                                    .onGeometryChange(for: CGFloat.self) {
                                        $0.size.height
                                    } action: {
                                        cutHeight = $0
                                    }
                                styled(text).fixedSize(horizontal: false, vertical: true)
                                    .onGeometryChange(for: CGFloat.self) {
                                        $0.size.height
                                    } action: {
                                        fullHeight = $0
                                    }
                            }
                            .hidden()
                        }
                        .accessibilityIdentifier("title.plot")
                    if fullHeight > cutHeight + 1, !page.state.expanded {
                        More(type: type)
                    }
                }
            }
        }

        private func styled(_ text: String) -> some View {
            Text(text)
                .font(.system(size: type.plot))
                .lineSpacing(type.plot * 0.3)
                .foregroundStyle(Browse.textSecondary)
        }
    }

    /// Opens the whole description: in place, or a sheet on Apple TV.
    struct More: View {
        let type: Sizes
        @Environment(\.titlePage) private var page

        var body: some View {
            Button {
                page?.actions.expand()
            } label: {
                Text("More")
                    .font(.system(size: type.plot, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More description")
            .accessibilityIdentifier("title.more")
        }
    }

    /// "Cast Mira Holt, …" and "Director Sanna Weiss", each up to two lines.
    struct Credits: View {
        let type: Sizes
        @Environment(\.titlePage) private var page

        var body: some View {
            if let meta = page?.state.metadata, meta.cast != nil || meta.director != nil {
                VStack(alignment: .leading, spacing: type.spacing / 2) {
                    if let cast = meta.cast { line("Cast", cast, identifier: "title.cast") }
                    if let director = meta.director { line("Director", director, identifier: "title.director") }
                }
            }
        }

        private func line(_ label: String, _ names: String, identifier: String) -> some View {
            Text("\(Text(label).foregroundStyle(Palette.textMuted)) \(Text(names).foregroundStyle(Browse.textSecondary))")
                .font(.system(size: type.plot * 0.9))
                .lineLimit(2)
                .accessibilityIdentifier(identifier)
        }
    }

    /// The white Play or Resume button, styled as on the Movies banner.
    struct PlayButton: View {
        let type: Sizes
        @Environment(\.titlePage) private var page

        var body: some View {
            if let play = page?.state.play {
                Button {
                    page?.actions.play()
                } label: {
                    Label(play.label, systemImage: "play.fill")
                        .font(.system(size: type.button, weight: .bold))
                        .lineLimit(1)
                        .padding(.horizontal, type.button * 1.3)
                        .frame(maxWidth: .infinity, minHeight: type.buttonHeight)
                }
                .buttonStyle(ShelfBanner.BannerButtonStyle(fill: .primary))
                .disabled(!play.enabled)
                .opacity(play.enabled ? 1 : 0.5)
                .accessibilityIdentifier("title.play")
            }
        }
    }

    /// Plus to add, check to remove (title-detail-and-episode-picker/my-list-from-the-page).
    struct MyListButton: View {
        let type: Sizes
        @Environment(\.titlePage) private var page

        var body: some View {
            let added = page?.state.isOnMyList ?? false
            Button {
                page?.actions.toggleMyList()
            } label: {
                Image(systemName: added ? "checkmark" : "plus")
                    .font(.system(size: type.button + 2, weight: .bold))
                    .frame(width: type.buttonHeight, height: type.buttonHeight)
            }
            .buttonStyle(ShelfBanner.BannerButtonStyle(fill: .secondary))
            .accessibilityLabel(added ? "Remove from my list" : "Add to my list")
            .accessibilityValue(added ? "On My list" : "Not on My list")
            .accessibilityIdentifier("title.myList")
        }
    }

    /// Opens the provider's trailer link outside the app
    /// (title-detail-and-episode-picker/trailer). Absent without a link.
    struct TrailerButton: View {
        let type: Sizes
        @Environment(\.titlePage) private var page

        var body: some View {
            if let trailer = page?.actions.trailer {
                Button(action: trailer) {
                    Label("Trailer", systemImage: "play.rectangle")
                        .font(.system(size: type.button, weight: .semibold))
                        .lineLimit(1)
                        .padding(.horizontal, type.button * 1.1)
                        .frame(minHeight: type.buttonHeight)
                }
                .buttonStyle(ShelfBanner.BannerButtonStyle(fill: .secondary))
                .accessibilityIdentifier("title.trailer")
            }
        }
    }

    /// The bar and "52 min left", shown only while Play reads Resume.
    struct Progress: View {
        let type: Sizes
        @Environment(\.titlePage) private var page

        var body: some View {
            if let play = page?.state.play, let fraction = play.fraction {
                HStack(spacing: type.spacing) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Palette.surface(0.22))
                            Capsule().fill(Palette.accent).frame(width: proxy.size.width * min(1, max(0, fraction)))
                        }
                    }
                    .frame(width: type.buttonHeight * 3, height: type.progress)
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("title.progress")
                    if let remaining = play.remaining {
                        Text(remaining)
                            .font(.system(size: type.meta))
                            .foregroundStyle(Browse.textSecondary)
                            .accessibilityIdentifier("title.remaining")
                    }
                }
            }
        }
    }

    /// What failed and Retry, under the buttons.
    struct Problem: View {
        let type: Sizes
        @Environment(\.titlePage) private var page

        var body: some View {
            if let page, let problem = page.state.problem {
                VStack(alignment: .leading, spacing: type.spacing / 2) {
                    Text(problem)
                        .font(.system(size: type.meta))
                        .foregroundStyle(Browse.textSecondary)
                        .accessibilityIdentifier("title.error")
                    Button(action: page.actions.retry) {
                        Text("Retry")
                            .font(.system(size: type.button, weight: .semibold))
                            .padding(.horizontal, type.button * 1.2)
                            .frame(minHeight: type.buttonHeight)
                    }
                    .buttonStyle(ShelfBanner.BannerButtonStyle(fill: .secondary))
                    .accessibilityIdentifier("title.retry")
                }
            }
        }
    }
}

extension TitlePageContext {
    /// A page for previews, built from fixed words and no artwork.
    static func preview(
        _ metadata: TitleMetadata, play: PlayState = PlayState(label: "Play", enabled: true), loading: Bool = false,
        problem: String? = nil, onMyList: Bool = false, trailer: Bool = true
    ) -> TitlePageContext {
        TitlePageContext(
            state: State(
                metadata: metadata, posterURL: nil, loading: loading, play: play, isOnMyList: onMyList, problem: problem,
                expanded: false, section: "Movies"),
            actions: Actions(back: {}, play: {}, toggleMyList: {}, retry: {}, expand: {}, trailer: trailer ? {} : nil))
    }
}

enum TitlePreviewFixtures {
    static let movie = ShelfTitle(
        id: "xtream#fixture#vod#1", kind: .movie, sourceID: ShelfFixtures.source, name: "The Long Harbor 2160p", category: "Thriller")
    static let full = TitleMetadata(
        movie: movie,
        info: VODInfo(
            plot: "A harbour pilot uncovers a smuggling ring the night before the port is sold. One tide to decide who gets out. "
                + "With the buyers arriving at dawn and her own crew split down the middle, she has until the water turns to choose.",
            year: 2024, duration: 7_680, genre: "Thriller", ageRating: "15", cast: "Mira Holt, Jonas Reeve, Adaeze Okafor",
            director: "Sanna Weiss", rating: 7.4))
    static let sparse = TitleMetadata(
        movie: ShelfTitle(id: "xtream#fixture#vod#2", kind: .movie, sourceID: ShelfFixtures.source, name: "Salt Road", category: "Action"),
        info: VODInfo(duration: 5_520))
    static let resume = TitlePageContext.PlayState(label: "Resume", enabled: true, fraction: 0.6, remaining: "52 min left")
}
