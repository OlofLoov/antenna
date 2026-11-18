import AntennaCore
import CoreGraphics
import SwiftUI

/// A banner or title page picture laid out by its own shape
/// (movies-and-series-browsing/new-titles-up-front,
/// title-detail-and-episode-picker/what-the-title-is-about). It fills the
/// frame, or, when filling a wide frame would hide more than half of it,
/// shows whole at the bottom right over a blurred copy of itself. It keeps
/// its proportions either way and stays inside the frame; `fallback` shows
/// while there is no picture.
struct FittedArt<Fallback: View>: View {
    let image: CGImage?
    let background: Color
    @ViewBuilder var fallback: Fallback

    var body: some View {
        background
            .overlay {
                GeometryReader { proxy in
                    let size = proxy.size
                    if let image, Self.fit(image, in: size) == .whole {
                        Whole(image: image, size: size, background: background)
                    } else {
                        FilledArt(image: image, background: background) { fallback }
                    }
                }
            }
            .clipped()
    }

    static func fit(_ image: CGImage, in size: CGSize) -> ArtFit {
        ArtFit.choose(
            pictureWidth: Double(image.width), pictureHeight: Double(image.height), frameWidth: size.width, frameHeight: size.height)
    }

    /// The whole picture, at most 70% of the frame's height and half its
    /// width, 12% of the height from the right and 10% from the bottom.
    private struct Whole: View {
        let image: CGImage
        let size: CGSize
        let background: Color

        var body: some View {
            ZStack(alignment: .bottomTrailing) {
                FilledArt(image: image, background: background)
                    .blur(radius: size.height / 12, opaque: true)
                    .overlay(Palette.ground.opacity(0.35))
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: size.width * 0.5, maxHeight: size.height * 0.7, alignment: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: size.height * 0.03, style: .continuous))
                    .shadow(color: .black.opacity(0.5), radius: size.height / 20, y: size.height / 60)
                    .padding(.trailing, size.height * 0.12)
                    .padding(.bottom, size.height * 0.1)
            }
            .frame(width: size.width, height: size.height)
        }
    }
}

extension FittedArt where Fallback == EmptyView {
    init(image: CGImage?, background: Color) {
        self.init(image: image, background: background) { EmptyView() }
    }
}

extension PreviewArt {
    /// A 2:3 picture, white with a black square in the middle, so a
    /// stretched copy shows as a rectangle.
    static let tallSquare = square(width: 200, height: 300, side: 100)
    /// A 16:9 picture with the same square.
    static let wideSquare = square(width: 320, height: 180, side: 90)

    static func square(width: Int, height: Int, side: Int) -> CGImage? {
        guard
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: (width - side) / 2, y: (height - side) / 2, width: side, height: side))
        return context.makeImage()
    }
}

#Preview("Fitted art, a poster in a wide frame", traits: .fixedLayout(width: 960, height: 320)) {
    FittedArt(image: PreviewArt.tallSquare, background: TitlePage.placeholder)
        .background(Palette.ground)
}

#Preview("Fitted art, a backdrop in a wide frame", traits: .fixedLayout(width: 960, height: 320)) {
    FittedArt(image: PreviewArt.wideSquare, background: TitlePage.placeholder)
        .background(Palette.ground)
}
