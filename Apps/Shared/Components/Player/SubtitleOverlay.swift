import AntennaCore
import SwiftUI

/// The subtitles over the picture (`iPhone-FullScreen-Subtitles`,
/// `TV-Player-Subtitles`; playback-engine/audio-and-subtitle-languages).
/// Text lines sit centered near the bottom of the picture, white on a dark
/// backdrop, sized to the picture. The picture's rect is fitted into the
/// overlay's bounds as the player fits it, so letterboxing never moves them.
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

#Preview("Subtitles, two lines letterboxed", traits: .fixedLayout(width: 390, height: 300)) {
    SubtitleOverlay(cues: [SubtitleCue(text: "Ich habe dich gestern nicht gesehen."), SubtitleCue(text: "Wo warst du?")], aspect: 16 / 9)
        .background(Palette.ground)
}
