import CoreGraphics
import SwiftUI

/// A movie or series poster at 2:3. While the picture loads it is a quiet
/// shape in the surface color with nothing on it, and the picture fades in
/// over it. A title with no poster, or one that failed, shows its name on
/// a plain tile, never an empty frame
/// (movies-and-series-browsing/rows-in-a-predictable-order).
struct PosterTile: View {
    let name: String
    let phase: PosterPhase
    var cornerRadius: CGFloat = 8
    /// The name's size on the plain tile; Apple TV posters use a larger one.
    var nameSize: CGFloat = 15

    /// The shape a poster holds while its picture loads.
    static let placeholder = Palette.surface(0.06)

    var body: some View {
        Self.placeholder
            .overlay {
                switch phase {
                case .loading:
                    EmptyView()
                case .shown(let image):
                    FilledArt(image: image, background: Browse.tile)
                        .transition(.opacity)
                case .missing:
                    FilledArt(image: nil, background: Browse.tile) {
                        Text(name)
                            .font(.boardStyle(nameSize, weight: .semibold))
                            .foregroundStyle(Palette.text)
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                            .minimumScaleFactor(0.8)
                            .padding(10)
                    }
                    .transition(.opacity)
                }
            }
            .aspectRatio(2 / 3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

#if DEBUG
    #Preview("Poster tile loading, shown and without a poster") {
        HStack(spacing: 12) {
            PosterTile(name: "Quiet Engines", phase: .loading)
            PosterTile(name: "Quiet Engines", phase: PreviewArt.tallPoster.map(PosterPhase.shown) ?? .missing)
            PosterTile(name: "Dune: Part Two", phase: .missing)
            PosterTile(name: "A title long enough to wrap onto several lines of the tile", phase: .missing)
        }
        .frame(width: 560)
        .padding()
        .background(Palette.ground)
    }
#endif
