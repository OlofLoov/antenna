import AntennaCore
import SwiftUI

/// Where an expanded card reads a title's details. Set by the Apple TV
/// Movies and Series screen around its rows; where it is missing, as in
/// the genre grids, Search and on iPhone, iPad and Mac, no poster grows.
struct ExpandedCardSource {
    /// The title's details once the provider has answered, else nil. A card
    /// that reads it redraws only for its own title's answer.
    var details: @MainActor (ShelfTitle) -> ShelfDetails?
}

extension EnvironmentValues {
    @Entry var shelfExpandedCard: ExpandedCardSource?
}

/// The landscape card a focused poster grows into on Apple TV, the height
/// of a poster (`TV-Movies-Expanded`, `TV-Movies-Expanded-Loading`,
/// `TV-Movies-Expanded-Poster-Only`;
/// movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv).
/// It draws inside the poster's button, so it has no focus of its own.
enum ShelfExpandedCard {
    /// The card's width; its height is the poster's.
    static let width: CGFloat = 566
    /// How a poster grows into the card and back, and how the posters after
    /// it move aside. Reduce Motion changes the sizes without it.
    static let grow = Animation.easeOut(duration: 0.25)
    /// The card's type.
    static let type = ShelfBanner.Sizes(
        eyebrow: 16, title: 34, facts: 20, badge: 15, description: 20, button: 20, buttonHeight: 44, spacing: 8)

    /// A poster's face: the poster, which grows into the card while its
    /// button has focus, where the screen provides a source. Without one it
    /// stays a poster.
    struct Expanding<Poster: View>: View {
        let title: ShelfTitle
        @ViewBuilder var poster: Poster
        @Environment(\.isFocused) private var focused
        @Environment(\.shelfExpandedCard) private var source
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var expanded = false

        var body: some View {
            Group {
                if expanded, let source {
                    let details = source.details(title)
                    Television(text: BannerText(preview: title, details: details), poster: title.posterURL, backdrop: details?.backdropURL)
                } else {
                    poster
                }
            }
            // In a transaction of its own, so the posters after it slide aside with it.
            .onChange(of: focused && source != nil, initial: true) { _, now in
                guard now != expanded else { return }
                withAnimation(reduceMotion ? nil : ShelfExpandedCard.grow) { expanded = now }
            }
        }
    }

    /// The picture, a scrim from clear at 30% of the height to the ground
    /// at the foot, and the copy at the foot's leading corner: the
    /// category, the name, the facts and two lines of plot.
    struct Television: View {
        let text: BannerText
        let poster: URL?
        let backdrop: URL?
        @Environment(\.shelfPrefix) private var prefix
        @Environment(\.shelfMetrics) private var metrics

        var body: some View {
            ZStack(alignment: .bottomLeading) {
                Picture(poster: poster, backdrop: backdrop)
                LinearGradient(
                    stops: [
                        .init(color: Palette.ground.opacity(0), location: 0.3), .init(color: Palette.ground.opacity(0.6), location: 0.6),
                        .init(color: Palette.ground.opacity(0.92), location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                Copy(text: text)
                    // Clear of a whole poster at the trailing side until a backdrop fills the card.
                    .frame(width: backdrop == nil ? 330 : ShelfExpandedCard.width - 48, alignment: .leading)
                    .padding(.leading, 24)
                    .padding(.bottom, 20)
            }
            .frame(width: ShelfExpandedCard.width, height: metrics.poster.height)
            .clipShape(RoundedRectangle(cornerRadius: metrics.corner, style: .continuous))
            .environment(\.shelfBanner, .still(text: text, art: nil))
        }
    }

    private struct Copy: View {
        let text: BannerText
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                if !text.eyebrow.isEmpty {
                    Text(text.eyebrow.uppercased())
                        .font(.boardStyle(ShelfExpandedCard.type.eyebrow, weight: .semibold))
                        .letterSpacing(2)
                        .foregroundStyle(Palette.textMuted)
                        .lineLimit(1)
                }
                Text(text.title)
                    .font(.boardStyle(ShelfExpandedCard.type.title, weight: .heavy))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityIdentifier("\(prefix).card.focused.title")
                Group {
                    ShelfBanner.Facts(type: ShelfExpandedCard.type)
                        .accessibilityIdentifier("\(prefix).card.focused.facts")
                    ShelfBanner.Description(type: ShelfExpandedCard.type, lines: 2)
                        .accessibilityIdentifier("\(prefix).card.focused.plot")
                }
                .transition(.opacity)
            }
            .animation(ShelfBanner.crossfade, value: text)
        }
    }

    /// The poster whole at the trailing side over a blurred copy of itself,
    /// from memory since its card already showed it, then the backdrop
    /// faded in once it has loaded.
    private struct Picture: View {
        let poster: URL?
        let backdrop: URL?
        @Environment(\.posterLoader) private var loader
        @Environment(\.shelfMetrics) private var metrics
        @Environment(\.displayScale) private var scale
        @State private var shown: Shown?

        private struct Shown: Equatable {
            var url: URL
            var image: CGImage?
        }

        var body: some View {
            Palette.surface(0.06)
                .overlay {
                    if let shown {
                        FittedArt(image: shown.image, background: TitlePage.placeholder)
                            .id(shown.url)
                            .transition(.opacity)
                    }
                }
                .clipped()
                .accessibilityHidden(true)
                .task(id: backdrop) {
                    guard let loader else { return }
                    let posterFit = PosterFit(width: metrics.poster.width, height: metrics.poster.height, scale: scale)
                    if shown == nil, let poster, let fit = posterFit {
                        let image = await loader.load(poster, fit)?.image
                        guard !Task.isCancelled else { return }
                        shown = Shown(url: poster, image: image)
                    }
                    guard let backdrop, backdrop != shown?.url,
                        let fit = PosterFit(width: ShelfExpandedCard.width, height: metrics.poster.height, scale: scale)
                    else { return }
                    let image = await loader.load(backdrop, fit)?.image
                    guard !Task.isCancelled, image != nil else { return }
                    withAnimation(ShelfBanner.crossfade) { shown = Shown(url: backdrop, image: image) }
                }
        }
    }
}

extension BannerContext {
    /// A banner context with no actions, so the card can draw the banner's
    /// facts and plot.
    static func still(text: BannerText, art: BannerArt?) -> BannerContext {
        BannerContext(
            state: .init(text: text, art: art, isOnMyList: false, index: 0, count: 1),
            actions: .init(play: {}, moreInfo: {}, toggleMyList: {}, page: { _ in }, show: { _ in }, interacting: { _ in }))
    }
}

extension BannerText {
    /// Quiet Engines in Thriller, for previews. `loading` leaves out the
    /// facts and plot, as before the info call answers.
    static func expandedCardPreview(loading: Bool) -> BannerText {
        let title = ShelfTitle(
            id: "xtream#preview#vod#5", kind: .movie, sourceID: ShelfFixtures.source, name: "Quiet Engines", category: "Thriller")
        let details = ShelfDetails(
            year: 2023, duration: 114 * 60,
            plot: "A night-shift mechanic finds a stolen prototype in a car left at her garage, and the people who want it back "
                + "know where she lives.",
            ageRating: "15")
        return BannerText(preview: title, details: loading ? nil : details)
    }
}

#Preview("Expanded card, Apple TV, backdrop", traits: .fixedLayout(width: 700, height: 420)) {
    ShelfExpandedCard.Television(
        text: .expandedCardPreview(loading: false), poster: PreviewArt.address, backdrop: PreviewArt.address
    )
    .environment(\.posterLoader, PreviewArt.loader(PreviewArt.backdrop))
    .environment(\.shelfMetrics, .tv)
    .padding(40)
    .background(Palette.ground)
}

#Preview("Expanded card, Apple TV, loading", traits: .fixedLayout(width: 700, height: 420)) {
    ShelfExpandedCard.Television(text: .expandedCardPreview(loading: true), poster: PreviewArt.address, backdrop: nil)
        .environment(\.posterLoader, PreviewArt.loader(PreviewArt.tallPoster))
        .environment(\.shelfMetrics, .tv)
        .padding(40)
        .background(Palette.ground)
}

#Preview("Expanded card, Apple TV, poster only", traits: .fixedLayout(width: 700, height: 420)) {
    ShelfExpandedCard.Television(text: .expandedCardPreview(loading: false), poster: PreviewArt.address, backdrop: nil)
        .environment(\.posterLoader, PreviewArt.loader(PreviewArt.tallPoster))
        .environment(\.shelfMetrics, .tv)
        .padding(40)
        .background(Palette.ground)
}
