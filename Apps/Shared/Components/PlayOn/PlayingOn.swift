import AntennaCore
import SwiftUI

/// What the phone shows while it is connected to an Apple TV
/// (play-on-apple-tv/connected-to-a-tv): the bar over every tab but Live
/// (`playOn.bar`, `iPhone-Title-Connected`, `iPad-PlayOn-Bar`), the picture
/// area in Live (`playOn.live`, `iPhone-Live-Connected`) and the sheet the
/// bar opens (`playOn.sheet`, `iPhone-PlayOn-Sheet`). Values and closures only.
enum PlayingOn {
    /// What the TV plays, as the phone draws it.
    struct State: Equatable {
        /// "Playing on Living Room", or "Stopped on Living Room" once it stopped.
        var headline: String
        /// The channel or title, and the programme or episode after a dot.
        var line: String
        /// Nil once the TV stopped: no play or pause button then.
        var playing: Bool?
        var initials: String
        var logoURL: URL?
    }

    /// What the controls do.
    struct Actions {
        var playPause: () -> Void
        var open: () -> Void
    }

    /// The glass capsule above the tab bar, or at the bottom of an iPad or Mac window.
    struct Bar: View {
        @Environment(\.accent) private var accent
        let state: State
        let actions: Actions

        var body: some View {
            HStack(spacing: 12) {
                Button(action: actions.open) {
                    HStack(spacing: 12) {
                        Image(systemName: "tv")
                            .foregroundStyle(accent.color)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(state.headline)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .layoutPriority(1)
                            Text(state.line)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Opens what plays on the TV")
                // VoiceOver reads "Playing on Living Room" and the item, and offers play or pause here
                // (play-on-apple-tv/connected-to-a-tv).
                .accessibilityActions {
                    if let playing = state.playing {
                        Button(playing ? "Pause" : "Play", action: actions.playPause)
                    }
                }
                .accessibilityIdentifier("playOn.bar")
                if let playing = state.playing {
                    PlayPauseButton(playing: playing, action: actions.playPause)
                        .accessibilityIdentifier("playOn.bar.playPause")
                }
            }
            .padding(.leading, 20)
            .padding(.trailing, 8)
            .frame(maxWidth: 520, minHeight: 56)
            .glassEffect(.regular, in: Capsule())
            .padding(.horizontal, 16)
        }
    }

    /// Live's picture area while connected: the channel's logo on the dark
    /// ground with "Playing on Living Room" and play or pause, with no video
    /// or sound (play-on-apple-tv/the-phone-opens-no-stream-while-connected).
    struct Picture: View {
        let state: State
        let actions: Actions

        var body: some View {
            ZStack {
                Palette.ground
                VStack(spacing: 14) {
                    LogoImage(url: state.logoURL) {
                        Text(state.initials)
                            .font(.title.weight(.bold))
                            .foregroundStyle(Palette.text)
                    }
                    .frame(width: 96, height: 64)
                    .padding(12)
                    .background(Palette.surface(0.12), in: cornerShape(.medium))
                    .accessibilityHidden(true)
                    Text(state.headline)
                        .font(.headline)
                        .foregroundStyle(Palette.text)
                    Text(state.line)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textMuted)
                        .lineLimit(1)
                    if let playing = state.playing {
                        PlayPauseButton(playing: playing, action: actions.playPause)
                            .accessibilityIdentifier("playOn.live.playPause")
                    }
                }
                .padding()
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: actions.open)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("playOn.live")
        }
    }

    /// The sheet the bar opens: the item, play or pause, "Play on this
    /// iPhone" and "Disconnect" (play-on-apple-tv/play-on-this-iphone).
    struct Sheet: View {
        let state: State
        /// "Play on this iPhone", "this iPad" or "this Mac".
        let playHere: String
        let actions: Actions
        let moveHere: () -> Void
        let disconnect: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    LogoImage(url: state.logoURL) {
                        Text(state.initials)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Palette.text)
                    }
                    .frame(width: 72, height: 72)
                    .background(Palette.surface(0.12), in: cornerShape(.medium))
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.headline)
                            .font(.footnote.weight(.semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.textMuted)
                        Text(state.line)
                            .font(.title3.weight(.bold))
                            .lineLimit(2)
                    }
                }
                if let playing = state.playing {
                    Button(action: actions.playPause) {
                        Label(playing ? "Pause" : "Play", systemImage: playing ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .primaryActionStyle()
                    .controlSize(.large)
                    .accessibilityIdentifier("playOn.sheet.playPause")
                }
                Button(action: moveHere) {
                    Text(playHere).frame(maxWidth: .infinity)
                }
                .secondaryActionStyle()
                .controlSize(.large)
                .accessibilityIdentifier("playOn.sheet.playHere")
                Button(action: disconnect) {
                    Text("Disconnect").frame(maxWidth: .infinity)
                }
                .secondaryActionStyle()
                .controlSize(.large)
                .accessibilityIdentifier("playOn.sheet.disconnect")
            }
            .padding(EdgeInsets(top: 24, leading: 20, bottom: 20, trailing: 20))
            .foregroundStyle(Palette.text)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("playOn.sheet")
        }
    }

    /// Play or pause for the TV, a 44 pt target
    /// (design-system/targets-are-large-enough-to-hit).
    struct PlayPauseButton: View {
        let playing: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playing ? "Pause" : "Play")
        }
    }
}

private let previewState = PlayingOn.State(
    headline: "Playing on Living Room", line: "Sport One · Premier League: Arsenal v Liverpool", playing: true, initials: "SO",
    logoURL: nil)
@MainActor private var previewActions: PlayingOn.Actions { PlayingOn.Actions(playPause: {}, open: {}) }

#Preview("Playing on bar") {
    PlayingOn.Bar(state: previewState, actions: previewActions)
        .padding(.vertical)
        .background(Palette.ground)
}

#Preview("Playing on bar, stopped") {
    var stopped = previewState
    stopped.headline = "Stopped on Living Room"
    stopped.playing = nil
    return PlayingOn.Bar(state: stopped, actions: previewActions)
        .padding(.vertical)
        .background(Palette.ground)
}

#Preview("Connected picture", traits: .fixedLayout(width: 390, height: 220)) {
    PlayingOn.Picture(state: previewState, actions: previewActions)
}

#Preview("Connected sheet") {
    PlayingOn.Sheet(state: previewState, playHere: "Play on this iPhone", actions: previewActions, moveHere: {}, disconnect: {})
        .background(Palette.ground)
}
