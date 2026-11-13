import SwiftUI

extension Browse {
    /// The strip along the bottom of the picture
    /// (live-tv-on-iphone-ipad-mac/player-controls-when-you-want-them):
    /// pause or play, the programme's progress, the time of day, the LIVE
    /// badge, the extras the platform adds (Picture in Picture on iPhone and
    /// iPad), and full screen. Controls drawn 30 to 40 pt get a 44 pt hit area.
    struct Controls<Extras: View>: View {
        let isPaused: Bool
        /// How far into the programme, 0 to 1; nil leaves the bar empty.
        let progress: Double?
        let clock: String
        let isFullScreen: Bool
        let playPause: () -> Void
        let toggleFullScreen: () -> Void
        @ViewBuilder var extras: Extras
        @Environment(\.browseMetrics) private var metrics

        var body: some View {
            let regular = metrics == .regular
            HStack(spacing: regular ? 14 : 10) {
                Button(action: playPause) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: regular ? 14 : 12, weight: .bold))
                        .foregroundStyle(Palette.ground)
                        .frame(width: regular ? 36 : 32, height: regular ? 36 : 32)
                        .background(Palette.text, in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPaused ? "Play" : "Pause")
                .accessibilityIdentifier("browse.player.playPause")
                ProgressTrack(fraction: progress ?? 0, height: regular ? 4 : 3)
                    .accessibilityElement()
                    .accessibilityLabel("Programme progress")
                    .accessibilityValue(progress.map { "\(Int(($0 * 100).rounded())) percent" } ?? "No programme information")
                    .accessibilityIdentifier("browse.player.progress")
                Text(clock)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Browse.textSecondary)
                    .accessibilityIdentifier("browse.player.clock")
                LiveBadge()
                extras
                FullScreenButton(isFullScreen: isFullScreen, toggle: toggleFullScreen)
            }
            .foregroundStyle(Palette.text)
            .padding(.horizontal, regular ? 12 : 6)
            .padding(.vertical, 2)
            .background(Palette.scrimTint.opacity(0.72))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("browse.player.controls")
        }
    }

    /// The channel line at the top of the full-screen picture, shown and
    /// hidden with the strip
    /// (live-tv-on-iphone-ipad-mac/the-full-screen-channel-line-fades-with-the-controls).
    struct PictureTitle<Logo: View>: View {
        let title: String
        let detail: String
        @ViewBuilder var logo: Logo

        var body: some View {
            HStack(spacing: 12) {
                logo
                    .frame(width: 48, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Browse.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Palette.scrimTint.opacity(0.72))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("browse.player.title")
        }
    }

    /// Full screen, or Exit full screen while the picture fills the screen.
    struct FullScreenButton: View {
        let isFullScreen: Bool
        let toggle: () -> Void

        var body: some View {
            Button(action: toggle) {
                Image(
                    systemName: isFullScreen
                        ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
                )
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.text)
            .accessibilityLabel(isFullScreen ? "Exit full screen" : "Full screen")
            .accessibilityIdentifier("browse.player.fullscreen")
        }
    }

    /// Exit full screen alone, over the error in full screen.
    struct ExitFullScreenButton: View {
        let exit: () -> Void

        var body: some View {
            FullScreenButton(isFullScreen: true, toggle: exit)
        }
    }

    /// The red dot and LIVE on the surface fill.
    struct LiveBadge: View {
        var body: some View {
            HStack(spacing: 5) {
                Circle().fill(Color(red: 0xFF / 255, green: 0x5F / 255, blue: 0x57 / 255)).frame(width: 6, height: 6)
                Text("LIVE")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 7)
            .background(Palette.surface(0.14), in: RoundedRectangle(cornerRadius: 5))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("browse.player.live")
        }
    }

    /// Previous channel, dimmed when there is no other channel to go back to
    /// (live-tv-on-iphone-ipad-mac/go-back-to-the-previous-channel).
    struct PreviousChannelButton: View {
        let isAvailable: Bool
        let goBack: () -> Void

        var body: some View {
            Button(action: goBack) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isAvailable)
            .opacity(isAvailable ? 1 : 0.4)
            .accessibilityLabel("Previous channel")
            .accessibilityIdentifier("browse.player.previous")
        }
    }

    /// The Picture in Picture button, grayed out when the player cannot do it.
    struct PictureInPictureButton: View {
        let isAvailable: Bool
        let start: () -> Void

        var body: some View {
            Button(action: start) {
                Image(systemName: "pip.enter")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isAvailable)
            .opacity(isAvailable ? 1 : 0.4)
            .accessibilityLabel("Picture in picture")
            .accessibilityIdentifier("browse.player.pip")
        }
    }

    /// The star among the full-screen controls (favorites/favorite-from-full-screen),
    /// filled in the accent while the playing channel is a favorite.
    struct PlayerFavoriteButton: View {
        let isFavorite: Bool
        let toggle: () -> Void

        var body: some View {
            Button(action: toggle) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isFavorite ? Palette.accent : Palette.text)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
            .accessibilityAddTraits(isFavorite ? .isSelected : [])
            .accessibilityIdentifier("browse.player.favorite")
        }
    }

    struct ProgressTrack: View {
        let fraction: Double
        let height: CGFloat

        var body: some View {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.surface(0.2))
                    Capsule().fill(Palette.accent)
                        .frame(width: proxy.size.width * min(1, max(0, fraction)))
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: height)
        }
    }
}

#Preview("Controls, iPhone", traits: .fixedLayout(width: 390, height: 60)) {
    Browse.Controls(
        isPaused: false, progress: 0.78, clock: "21:34", isFullScreen: false, playPause: {}, toggleFullScreen: {}
    ) {
        Browse.PreviousChannelButton(isAvailable: true) {}
        Browse.PictureInPictureButton(isAvailable: true) {}
    }
}

#Preview("Controls, iPad, paused, no Picture in Picture", traits: .fixedLayout(width: 570, height: 60)) {
    Browse.Controls(
        isPaused: true, progress: 0.4, clock: "21:34", isFullScreen: false, playPause: {}, toggleFullScreen: {}
    ) {
        Browse.PreviousChannelButton(isAvailable: false) {}
        Browse.PictureInPictureButton(isAvailable: false) {}
    }
    .environment(\.browseMetrics, .regular)
}

#Preview("Picture title, full screen", traits: .fixedLayout(width: 844, height: 60)) {
    Browse.PictureTitle(title: "News One", detail: "Now: Evening News") {
        Browse.Logo(url: nil, initials: "NO", isSelected: true)
    }
}

#Preview("Controls, full screen", traits: .fixedLayout(width: 844, height: 60)) {
    Browse.Controls(
        isPaused: false, progress: nil, clock: "21:34", isFullScreen: true, playPause: {}, toggleFullScreen: {}
    ) {
        Browse.PlayerFavoriteButton(isFavorite: false) {}
        Browse.PreviousChannelButton(isAvailable: true) {}
    }
}

#Preview("Controls, full screen, a favorite", traits: .fixedLayout(width: 844, height: 60)) {
    Browse.Controls(
        isPaused: false, progress: 0.3, clock: "21:34", isFullScreen: true, playPause: {}, toggleFullScreen: {}
    ) {
        Browse.PlayerFavoriteButton(isFavorite: true) {}
    }
}
