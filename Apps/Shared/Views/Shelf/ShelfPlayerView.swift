import AntennaCore
import SwiftUI

/// A movie or episode full screen over the section. Close on iPhone, iPad
/// and Mac, or Menu on Apple TV, saves the place and goes back to the
/// poster that started it (movies-and-series-browsing/resume-where-you-left-off).
/// A tap, or play/pause on the remote, pauses and plays.
struct ShelfPlayerView: View {
    let playback: ShelfPlayback
    let target: ShelfPlayback.Target
    #if os(tvOS)
        /// The picture takes focus so Menu and play/pause reach it.
        @FocusState private var focused: Bool
    #endif

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            PlayerSurfaceView(engine: playback.engine)
                .overlay { PlayerSubtitles(engine: playback.engine) }
                .ignoresSafeArea()
                .accessibilityElement()
                .accessibilityLabel(title)
                .accessibilityIdentifier("\(target.title.kind.prefix).player")
            #if os(tvOS)
                Color.clear
                    .focusable()
                    .focusEffectDisabled()
                    .focused($focused)
                    .task { focused = true }
                    .onExitCommand { Task { await playback.close() } }
                    .onPlayPauseCommand { Task { await playback.playPause() } }
                    .accessibilityHidden(true)
            #else
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { Task { await playback.playPause() } }
                    .accessibilityHidden(true)
                Button {
                    Task { await playback.close() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.text)
                        .frame(width: 44, height: 44)
                        .background(Palette.scrimTint.opacity(0.6), in: Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .padding(16)
                .accessibilityLabel("Close")
                .accessibilityIdentifier("\(target.title.kind.prefix).player.close")
            #endif
        }
        .overlay {
            #if DEBUG
                UITestingShelf.Probe(engine: playback.engine)
            #endif
        }
    }

    private var title: String {
        switch target {
        case .movie(let movie): movie.name
        case .episode(let episode, let series): "\(series.name), \(ShelfText.episodeCode(episode) ?? episode.title)"
        }
    }
}
