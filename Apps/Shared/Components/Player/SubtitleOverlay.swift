import AntennaCore
import SwiftUI

/// The subtitles over the picture (`iPhone-FullScreen-Subtitles`,
/// `TV-Player-Subtitles`; playback-engine/audio-and-subtitle-languages).
/// Text lines sit centered near the bottom of the picture, white on a dark
/// backdrop, sized to the picture. Broadcast subtitle pictures sit where the
/// stream places them, scaled with the picture
/// (playback-engine/picture-subtitles-in-broadcast-streams). The picture's
/// rect is fitted into the overlay's bounds as the player fits it, so
/// letterboxing never moves them.
struct SubtitleOverlay: View {
    let cues: [SubtitleCue]
    /// The picture's width over its height; nil fills the bounds.
    let aspect: Double?
    /// Points the lines move up while controls cover the bottom.
    var raised: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let picture = Self.pictureRect(in: proxy.size, aspect: aspect)
            let lines = cues.map(\.text).filter { !$0.isEmpty }
            ForEach(Array(cues.compactMap(\.image).enumerated()), id: \.offset) { _, image in
                if let bitmap = Self.cgImage(image) {
                    let place = Self.place(image.frame, in: picture)
                    Image(decorative: bitmap, scale: 1)
                        .resizable()
                        .interpolation(.medium)
                        .frame(width: place.width, height: place.height)
                        .position(x: place.midX, y: place.midY)
                        .accessibilityIdentifier("player.subtitles.picture")
                }
            }
            if !lines.isEmpty {
                Text(lines.joined(separator: "\n"))
                    .font(.system(size: Self.textSize(pictureHeight: picture.height), weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, picture.height * 0.015)
                    .padding(.vertical, picture.height * 0.008)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: picture.height * 0.01))
                    .frame(maxWidth: picture.width * 0.9)
                    .position(x: picture.midX, y: min(picture.maxY, proxy.size.height - raised) - picture.height * 0.12)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("player.subtitles.cue")
            }
        }
        .allowsHitTesting(false)
    }

    /// Where a picture of `aspect` sits when fitted into `size`, centered.
    static func pictureRect(in size: CGSize, aspect: Double?) -> CGRect {
        guard let aspect, aspect > 0, size.width > 0, size.height > 0 else { return CGRect(origin: .zero, size: size) }
        let width = min(size.width, size.height * aspect)
        let height = width / aspect
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    /// Where a subtitle picture placed by `frame` sits on `picture`.
    static func place(_ frame: SubtitleImage.Frame, in picture: CGRect) -> CGRect {
        CGRect(
            x: picture.minX + frame.x * picture.width, y: picture.minY + frame.y * picture.height, width: frame.width * picture.width,
            height: frame.height * picture.height)
    }

    /// The picture's RGBA bytes as an image, nil when they do not add up.
    static func cgImage(_ image: SubtitleImage) -> CGImage? {
        guard image.width > 0, image.height > 0, image.rgba.count == image.width * image.height * 4,
            let provider = CGDataProvider(data: image.rgba as CFData)
        else { return nil }
        return CGImage(
            width: image.width, height: image.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    /// 4.5 percent of the picture's height, never under the platform's
    /// caption floor (design-system/text-stays-above-the-platform-caption-floor).
    static func textSize(pictureHeight: CGFloat) -> CGFloat {
        max(pictureHeight * 0.045, captionFloor)
    }

    private static var captionFloor: CGFloat {
        #if os(tvOS)
            18
        #else
            13
        #endif
    }
}

#Preview("Subtitles, one line on a 16:9 picture", traits: .fixedLayout(width: 844, height: 390)) {
    SubtitleOverlay(cues: [SubtitleCue(text: "I didn't see you yesterday.")], aspect: 16 / 9)
        .background(Palette.ground)
}

#Preview("Subtitles, a broadcast picture", traits: .fixedLayout(width: 844, height: 390)) {
    SubtitleOverlay(cues: [SubtitleCue(text: "", image: SubtitleOverlay.previewPicture)], aspect: 16 / 9)
        .background(Palette.ground)
}

extension SubtitleOverlay {
    /// A white bar with a dark band, a fifth of the page wide near its
    /// bottom, as the DVB test stream draws.
    static let previewPicture: SubtitleImage = {
        let width = 144
        let height = 48
        var rgba = Data(count: width * height * 4)
        for row in 0..<height {
            let shade: UInt8 = (16..<32).contains(row) ? 40 : 235
            for column in 0..<width {
                let offset = (row * width + column) * 4
                rgba[offset] = shade
                rgba[offset + 1] = shade
                rgba[offset + 2] = shade
                rgba[offset + 3] = 255
            }
        }
        return SubtitleImage(width: width, height: height, rgba: rgba, frame: .init(x: 0.4, y: 0.83, width: 0.2, height: 0.083))
    }()
}

#Preview("Subtitles, two lines letterboxed", traits: .fixedLayout(width: 390, height: 300)) {
    SubtitleOverlay(cues: [SubtitleCue(text: "Ich habe dich gestern nicht gesehen."), SubtitleCue(text: "Wo warst du?")], aspect: 16 / 9)
        .background(Palette.ground)
}
