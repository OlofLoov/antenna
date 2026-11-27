import AntennaCore
import SwiftUI

/// Where an expanded card reads a title's details. Set by the Apple TV
/// Movies and Series screen around its rows; where it is missing, as in
/// the genre grids, Search and on iPhone, iPad and Mac, no poster grows.
struct ExpandedCardSource: Equatable {
    /// Who answers, so a source made again in a redraw reads as the same
    /// and no poster redraws for it.
    let owner: ObjectIdentifier
    /// The title's details once the provider has answered, else nil. A card
    /// that reads it redraws only for its own title's answer.
    var details: @MainActor (ShelfTitle) -> ShelfDetails?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.owner == rhs.owner
    }
}

extension EnvironmentValues {
    @Entry var shelfExpandedCard: ExpandedCardSource?
    /// Set by each Apple TV row of posters, so the posters after a card move aside.
    @Entry var shelfCardRoom: ShelfCardRoom?
}

/// Makes room in a row for its card. Every poster keeps its slot in the
/// row's lazy stack; the row draws the card over the focused poster's slot,
/// above the stack, and the posters after it are offset by the card's extra
/// width, so a move along the row never lays the row out again and never
/// changes the stack's children
/// (movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv).
/// Each poster reads only its own place, so a step along the row redraws
/// the one poster whose place changes, and the card.
@MainActor
final class ShelfCardRoom {
    /// The row's posters in order, set by the row as its titles change.
    /// A new order places the posters on screen again.
    var order: [ShelfTitle] = [] {
        didSet {
            guard oldValue != order else { return }
            for (key, place) in places {
                place.index = key == Self.tail ? order.count : order.firstIndex { $0.id == key } ?? order.count
            }
            if let card = expanded { expanded = places[card.id].map { (card.id, $0.index) } }
            for place in places.values { settle(place) }
            show()
        }
    }
    /// The card the row draws, observed alone.
    let spot = ShelfCardSpot()
    private var places: [String: ShelfCardPlace] = [:]
    /// The poster that is a card, and its position.
    private var expanded: (id: String, index: Int)?

    nonisolated init() {}

    /// Puts a poster that came into view in its place: aside when it is
    /// after the card. A tile after the posters, such as See all, passes nil.
    func arrive(_ place: ShelfCardPlace, id: String?) {
        place.index = id.flatMap { id in order.firstIndex { $0.id == id } } ?? order.count
        places[id ?? Self.tail] = place
        settle(place)
    }

    func leave(_ place: ShelfCardPlace, id: String?) {
        if places[id ?? Self.tail] === place { places[id ?? Self.tail] = nil }
    }

    /// Makes `id` the card, or none, and moves the posters whose place
    /// changes. Call it inside the card's animation, so they slide with it.
    func expand(_ id: String, _ now: Bool) {
        if now, let index = places[id]?.index {
            expanded = (id, index)
        } else if !now, expanded?.id == id {
            expanded = nil
        } else {
            return
        }
        for place in places.values { settle(place) }
        show()
    }

    private func settle(_ place: ShelfCardPlace) {
        let aside = expanded.map { place.index > $0.index } ?? false
        if place.aside != aside { place.aside = aside }
    }

    /// Hands the card's title and slot to the row.
    private func show() {
        let card = expanded.flatMap { expanded in
            order.indices.contains(expanded.index) && order[expanded.index].id == expanded.id
                ? ShelfCardSpot.Card(title: order[expanded.index], index: expanded.index) : nil
        }
        if spot.card != card { spot.card = card }
    }

    /// The key of the tile after the posters, which no title id matches.
    private static let tail = "tail"
}

/// The card a row draws: its title and the slot it covers.
@MainActor @Observable
final class ShelfCardSpot {
    struct Card: Equatable {
        var title: ShelfTitle
        var index: Int
    }

    var card: Card?

    nonisolated init() {}
}

/// One poster's place in a row with a card: moved aside after the card.
@MainActor @Observable
final class ShelfCardPlace {
    var aside = false
    @ObservationIgnored var index = 0

    nonisolated init() {}
}

extension View {
    /// A poster or tile in a row that makes room for a card: offset by the
    /// card's extra width while it is after the card. Without a room, as
    /// off Apple TV, it stays a poster.
    func makesRoomForTheCard(_ title: ShelfTitle?) -> some View {
        modifier(CardRoomPlace(title: title))
    }
}

private struct CardRoomPlace: ViewModifier {
    let title: ShelfTitle?
    @Environment(\.shelfCardRoom) private var room
    @Environment(\.shelfMetrics) private var metrics
    @State private var place = ShelfCardPlace()

    func body(content: Content) -> some View {
        if let room {
            content
                .offset(x: place.aside ? ShelfExpandedCard.width - metrics.poster.width : 0)
                .onAppear { room.arrive(place, id: title?.id) }
                .onDisappear { room.leave(place, id: title?.id) }
        } else {
            content
        }
    }
}

extension ShelfExpandedCard {
    /// The row's card over the focused poster's slot, drawn over the row's
    /// stack rather than in it, so the stack's children stay as they are
    /// while the card moves. Each title's card fades in and out on its own.
    struct InRow: View {
        let spot: ShelfCardSpot
        @Environment(\.shelfExpandedCard) private var source
        @Environment(\.shelfMetrics) private var metrics

        var body: some View {
            if let card = spot.card, let source {
                Lifted(title: card.title, source: source)
                    .offset(x: CGFloat(card.index) * (metrics.poster.width + metrics.gap))
                    .id(card.title.id)
                    .transition(.opacity)
            }
        }
    }
}

/// The landscape card a focused poster grows into on Apple TV, the height
/// of a poster (`TV-Movies-Expanded`, `TV-Movies-Expanded-Loading`,
/// `TV-Movies-Expanded-Poster-Only`;
/// movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv).
/// It draws over the poster's slot, outside its button, so it has no
/// focus of its own; the poster's button keeps the highlight.
enum ShelfExpandedCard {
    /// The card's width; its height is the poster's.
    static let width: CGFloat = 566
    /// How a poster grows into the card and back, and how the posters after
    /// it move aside. Reduce Motion changes the sizes without it.
    static let grow = Animation.easeOut(duration: 0.25)
    /// The card's type.
    static let type = ShelfBanner.Sizes(
        eyebrow: 16, title: 34, facts: 20, badge: 15, description: 20, button: 20, buttonHeight: 44, spacing: 8)

    /// How much the card is lifted while it has the highlight. The system
    /// card style lifts a poster by an eighth; a wider view it lifts less,
    /// and at an eighth the card's copy would start left of the safe area.
    static let lift: CGFloat = 1.06
    /// The poster's size under its card, so with the system's lift it
    /// stays inside the card.
    static let under: CGFloat = 0.9

    /// A poster's face. While its button has focus, where the screen
    /// provides a source and a row's `ShelfCardRoom`, the row draws the
    /// card over its slot (`InRow`). The
    /// slot keeps the poster's size, so the row's lazy stack does not lay
    /// out again as the card grows, and the posters after it move aside by
    /// an offset. The card sits outside the button because the system card
    /// style clips its label to the label's frame; it draws the lift and
    /// shadow that style gives a focused poster.
    struct Expanding<Poster: View>: View {
        let title: ShelfTitle
        @ViewBuilder var poster: Poster
        @Environment(\.isFocused) private var focused
        @Environment(\.shelfExpandedCard) private var source
        @Environment(\.shelfCardRoom) private var room
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var expanded = false

        var body: some View {
            // Under the card, the poster shrinks inside the button's lift so
            // no edge of it shows. It stays drawn: at no opacity the button
            // would leave the accessibility tree.
            poster
                .scaleEffect(expanded ? ShelfExpandedCard.under : 1)
                // In a transaction of its own, so the posters after it slide aside with it.
                .onChange(of: focused && source != nil && room != nil, initial: true) { _, now in
                    guard now != expanded else { return }
                    withAnimation(reduceMotion ? nil : ShelfExpandedCard.grow) {
                        expanded = now
                        room?.expand(title.id, now)
                    }
                }
        }
    }

    /// The card over a focused poster's slot, lifted as the poster was.
    struct Lifted: View {
        let title: ShelfTitle
        let source: ExpandedCardSource
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            let details = source.details(title)
            Television(text: BannerText(preview: title, details: details), poster: title.posterURL, backdrop: details?.backdropURL)
                .shadow(color: .black.opacity(0.45), radius: 24, y: 16)
                .scaleEffect(ShelfExpandedCard.lift)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("\(prefix).card.focused")
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
            // Opaque, since the lifted poster stays under it.
            .background(Palette.ground)
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

        /// The poster if the cache holds it at the row's size.
        private var kept: Shown? {
            guard let loader, let poster,
                let fit = PosterFit(width: metrics.poster.width, height: metrics.poster.height, scale: scale),
                let image = loader.kept(poster, fit)?.image
            else { return nil }
            return Shown(url: poster, image: image)
        }

        var body: some View {
            // The poster from memory in the card's first frame, so a card
            // does not draw twice as it shows.
            let picture = shown ?? kept
            Palette.surface(0.06)
                .overlay {
                    if let picture {
                        FittedArt(image: picture.image, background: TitlePage.placeholder)
                            .id(picture.url)
                            .transition(.opacity)
                    }
                }
                .clipped()
                .accessibilityHidden(true)
                .task(id: backdrop) {
                    guard let loader else { return }
                    let posterFit = PosterFit(width: metrics.poster.width, height: metrics.poster.height, scale: scale)
                    if shown == nil, let kept {
                        shown = kept
                    } else if shown == nil, let poster, let fit = posterFit {
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
