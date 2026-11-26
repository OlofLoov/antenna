import AntennaCore
import SwiftUI

extension TitlePage {
    /// The first backdrop, whole at its own proportions in the part of the
    /// frame `insets` leave (title-detail-and-episode-picker/what-the-title-is-about).
    /// `TitleArtPlacement` says where it sits; a blurred copy of it fills the
    /// rest of the frame. Without a backdrop the poster sits on black, and
    /// without a poster its name tile does.
    struct Backdrop: View {
        /// The poster's size when there is no backdrop.
        let poster: CGSize
        /// What of the frame the picture keeps clear of, such as the status
        /// bar on iPhone.
        var insets = EdgeInsets()
        var alignment = TitleArtPlacement.Alignment.trailing
        /// How far a poster-shaped picture sits from the area's edges.
        var margin: CGFloat = 28
        @Environment(\.titlePage) private var page
        @Environment(\.posterLoader) private var loader
        @Environment(\.artFit) private var fit
        @State private var image: Poster?

        var body: some View {
            let backdrop = page?.state.metadata.backdropURL
            Color.black
                .overlay {
                    GeometryReader { proxy in
                        if let image = image?.image {
                            Placed(image: image, size: proxy.size, insets: insets, alignment: alignment, margin: margin)
                                .transition(.opacity)
                        } else if backdrop == nil, let page {
                            ShelfView.PosterArt(name: page.state.metadata.name, url: page.state.posterURL)
                                .frame(width: poster.width, height: poster.height)
                                .accessibilityIdentifier("title.poster")
                                .frame(width: proxy.size.width, height: proxy.size.height)
                        }
                    }
                }
                .clipped()
                .animation(.easeOut(duration: 0.25), value: image == nil)
                .accessibilityHidden(true)
                .accessibilityIdentifier("title.backdrop")
                .task(id: backdrop) {
                    image = nil
                    guard let backdrop, let loader else { return }
                    image = await loader.load(backdrop, fit)
                }
        }
    }

    /// The picture at its placement over a darkened blurred copy that fills
    /// `size`. Distances run from the leading edge, so a picture placed at
    /// the trailing edge sits on the left in a right-to-left language, away
    /// from the copy.
    struct Placed: View {
        let image: CGImage
        let size: CGSize
        let insets: EdgeInsets
        let alignment: TitleArtPlacement.Alignment
        let margin: CGFloat

        /// How far a picture that stops short of the area's sides fades into the blur.
        private static let fade: CGFloat = 24

        var body: some View {
            let area = TitleArtPlacement.Box(
                x: insets.leading, y: insets.top, width: max(0, size.width - insets.leading - insets.trailing),
                height: max(0, size.height - insets.top - insets.bottom))
            let placed = TitleArtPlacement.place(
                pictureWidth: Double(image.width), pictureHeight: Double(image.height), in: area, alignment: alignment,
                margin: margin)
            ZStack(alignment: .topLeading) {
                FilledArt(image: image, background: .black)
                    .blur(radius: max(size.height / 12, 16), opaque: true)
                    .overlay(Palette.ground.opacity(0.35))
                    .frame(width: size.width, height: size.height)
                picture(placed, in: area)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }

        @ViewBuilder
        private func picture(_ placed: TitleArtPlacement, in area: TitleArtPlacement.Box) -> some View {
            let box = placed.picture
            let drawn = Image(decorative: image, scale: 1).resizable().frame(width: box.width, height: box.height)
            switch placed.look {
            case .fills:
                drawn
                    .padding(.leading, box.x - area.x)
                    .padding(.top, box.y - area.y)
                    .frame(width: area.width, height: area.height, alignment: .topLeading)
                    .clipped()
                    .padding(.leading, area.x)
                    .padding(.top, area.y)
            case .whole:
                drawn
                    .mask { Self.edges(box, in: area) }
                    .padding(.leading, box.x)
                    .padding(.top, box.y)
            case .framed:
                drawn
                    .clipShape(RoundedRectangle(cornerRadius: box.height * 0.03, style: .continuous))
                    .shadow(color: .black.opacity(0.5), radius: box.height / 20, y: box.height / 60)
                    .padding(.leading, box.x)
                    .padding(.top, box.y)
            }
        }

        /// Opaque, fading over `fade` at a side that stops short of the area.
        private static func edges(_ box: TitleArtPlacement.Box, in area: TitleArtPlacement.Box) -> some View {
            let share = min(fade / max(box.width, 1), 0.5)
            let leading = box.x > area.x + 0.5
            let trailing = box.maxX < area.maxX - 0.5
            return LinearGradient(
                stops: [
                    .init(color: leading ? .clear : .black, location: 0),
                    .init(color: .black, location: leading ? share : 0),
                    .init(color: .black, location: trailing ? 1 - share : 1),
                    .init(color: trailing ? .clear : .black, location: 1),
                ], startPoint: .leading, endPoint: .trailing
            )
            .flipsForRightToLeftLayoutDirection(true)
        }
    }
}
