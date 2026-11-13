import CoreGraphics
import SwiftUI

/// A movie or series poster at 2:3, or the title's name on a plain tile while
/// the poster is missing, loading or broken, never an empty frame
/// (movies-and-series-browsing/rows-in-a-predictable-order).
struct PosterTile: View {
    let name: String
    let image: CGImage?
    var cornerRadius: CGFloat = 8
    /// The name's size on the plain tile; Apple TV posters use a larger one.
    var nameSize: CGFloat = 15

    var body: some View {
        FilledArt(image: image, background: Browse.tile) {
            Text(name)
                .font(.system(size: nameSize, weight: .semibold))
                .foregroundStyle(Palette.text)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.8)
                .padding(10)
        }
        .aspectRatio(2 / 3, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

#if DEBUG
    #Preview("Poster tile without a poster") {
        HStack(spacing: 12) {
            PosterTile(name: "Dune: Part Two", image: nil)
            PosterTile(name: "A title long enough to wrap onto several lines of the tile", image: nil)
        }
        .frame(width: 280)
        .padding()
        .background(Palette.ground)
    }
#endif
