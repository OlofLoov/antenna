import CoreGraphics
import SwiftUI

/// A picture scaled to fill the frame it is given and cut to that frame, on
/// a background color, with `fallback` over the color while there is no
/// picture. The color sets the size, so a picture of any shape never makes
/// the view larger than its frame or draws outside it
/// (movies-and-series-browsing/new-titles-up-front).
struct FilledArt<Fallback: View>: View {
    let image: CGImage?
    let background: Color
    @ViewBuilder var fallback: Fallback

    var body: some View {
        background
            .overlay {
                if let image {
                    Image(decorative: image, scale: 1).resizable().scaledToFill()
                } else {
                    fallback
                }
            }
            .clipped()
    }
}

extension FilledArt where Fallback == EmptyView {
    init(image: CGImage?, background: Color) {
        self.init(image: image, background: background) { EmptyView() }
    }
}

/// Pictures drawn in code for previews and tests: stripes, so any part
/// drawn outside its frame shows.
enum PreviewArt {
    /// A 2:3 poster, much taller than any banner.
    static let tallPoster = stripes(width: 200, height: 300)
    /// A 16:9 backdrop.
    static let backdrop = stripes(width: 320, height: 180)
    /// An address for previews whose loader ignores it.
    static let address = URL(fileURLWithPath: "/preview-art")

    static func stripes(width: Int, height: Int) -> CGImage? {
        guard
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let band = max(1, height / 6)
        for index in 0..<6 {
            let red = index.isMultiple(of: 2) ? 0.85 : 0.2
            context.setFillColor(CGColor(srgbRed: red, green: 0.35, blue: 0.3 + Double(index) * 0.1, alpha: 1))
            context.fill(CGRect(x: 0, y: index * band, width: width, height: band))
        }
        return context.makeImage()
    }

    /// A loader that hands back `image` for every address, for previews
    /// that show artwork.
    static func loader(_ image: CGImage?) -> ShelfView.PosterLoader {
        ShelfView.PosterLoader { _ in image.map(Poster.init(image:)) }
    }
}

#Preview("Filled art, a tall poster in a wide frame", traits: .fixedLayout(width: 640, height: 400)) {
    VStack(spacing: 0) {
        Color.clear.frame(height: 100)
        FilledArt(image: PreviewArt.tallPoster, background: TitlePage.placeholder)
            .frame(height: 200)
        Color.clear.frame(height: 100)
    }
    .background(Palette.ground)
}
