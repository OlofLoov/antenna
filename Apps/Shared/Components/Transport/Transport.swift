import SwiftUI

/// The pieces that show and move the time of a movie or episode
/// (player-controls-and-playback-errors/move-around-in-a-movie-or-episode;
/// `TV-Title-Player-Transport`, `TV-Title-Player-Scrub`,
/// `iPhone-Title-Player-Transport`, `iPad-Title-Player-Transport`). They
/// take values and closures only.
enum Transport {
    /// The times the controls show, worked out by the screen.
    struct Times: Equatable {
        /// "12:04", on the left of the bar.
        let elapsed: String
        /// "-1:17:56", nil when the length is not known.
        let remaining: String?
        /// How far in, 0 to 1; nil leaves out the bar.
        let fraction: Double?
        /// "12 minutes, 4 seconds of 1 hour, 30 minutes", for VoiceOver.
        let spoken: String
    }

    /// A line over the picture for a few seconds, read aloud by VoiceOver.
    struct Notice: View {
        let text: String

        var body: some View {
            Text(text)
                .font(.headline)
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Palette.scrimTint.opacity(0.88), in: Capsule())
                .accessibilityIdentifier("title.transport.notice")
                .task(id: text) {
                    AccessibilityNotification.Announcement(text).post()
                }
        }
    }
}

#if os(tvOS)
    extension Transport {
        /// The Apple TV bar along the bottom of the picture: the title, the
        /// played part in the accent with the knob, the elapsed time under
        /// its left end and the remaining time under its right. While a
        /// slide moves a target, a second knob and its time show above the
        /// bar. Never focusable; the remote reaches the picture behind it.
        struct Bar: View {
            let title: String
            let times: Times
            let isPaused: Bool
            /// Where a slide points, 0 to 1, and its time; nil when none.
            var target: (fraction: Double, time: String)?

            var body: some View {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 16) {
                        Image(systemName: isPaused ? "pause.fill" : "play.fill")
                            .font(.headline)
                            .foregroundStyle(Palette.textMuted)
                            .accessibilityLabel(isPaused ? "Paused" : "Playing")
                            .accessibilityIdentifier("title.transport.stateGlyph")
                        Text(title)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    if let fraction = times.fraction {
                        Track(fraction: fraction, target: target)
                    }
                    HStack {
                        Text(times.elapsed)
                            .accessibilityIdentifier("title.transport.elapsed")
                        Spacer()
                        if let remaining = times.remaining {
                            Text(remaining)
                                .accessibilityIdentifier("title.transport.remaining")
                        }
                    }
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(Palette.textMuted)
                }
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 90)
                .padding(.top, 120)
                .padding(.bottom, 60)
                .background {
                    LinearGradient(colors: [.clear, Palette.scrimTint.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("title.transport")
            }
        }

        /// The bar's line: played in the accent up to the knob, and the
        /// target's knob with its time above while a slide moves it.
        struct Track: View {
            let fraction: Double
            var target: (fraction: Double, time: String)?

            var body: some View {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.surface(0.25)).frame(height: 10)
                        Capsule().fill(Palette.accent).frame(width: width * clamp(fraction), height: 10)
                        Circle().fill(Palette.text)
                            .frame(width: 24, height: 24)
                            .offset(x: width * clamp(fraction) - 12)
                        if let target {
                            let at = width * clamp(target.fraction)
                            Capsule().fill(Palette.text)
                                .frame(width: 6, height: 40)
                                .offset(x: at - 3)
                            Text(target.time)
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(Palette.ground)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(Palette.text, in: Capsule())
                                .fixedSize()
                                .alignmentGuide(.leading) { $0.width / 2 - at }
                                .offset(y: -64)
                                .accessibilityIdentifier("title.transport.target")
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(height: 40)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("title.transport.track")
            }

            private func clamp(_ value: Double) -> Double {
                min(1, max(0, value))
            }
        }
    }

    private let previewTimes = Transport.Times(
        elapsed: "12:04", remaining: "-1:17:56", fraction: 724.0 / 5400, spoken: "12 minutes, 4 seconds of 1 hour, 30 minutes")

    #Preview("Transport bar, Apple TV, playing", traits: .fixedLayout(width: 1920, height: 360)) {
        Transport.Bar(title: "The Long Way Home", times: previewTimes, isPaused: false)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .background(Color(white: 0.2))
    }

    #Preview("Transport bar, Apple TV, sliding while paused", traits: .fixedLayout(width: 1920, height: 360)) {
        Transport.Bar(title: "The Long Way Home", times: previewTimes, isPaused: true, target: (0.42, "37:48"))
            .frame(maxHeight: .infinity, alignment: .bottom)
            .background(Color(white: 0.2))
    }
#else
    extension Transport {
        /// The iPhone, iPad and Mac controls over the middle and bottom of
        /// the picture: back 10, play or pause and forward 10 in the middle,
        /// and the scrubber between the elapsed and the remaining time at
        /// the bottom. The scrubber follows a finger or the pointer from
        /// anywhere on its 44 pt height and seeks once on release, as Live's
        /// timeshift scrubber does; VoiceOver swipes on it skip 10 seconds.
        struct Controls: View {
            let times: Times
            let isPaused: Bool
            let playPause: () -> Void
            let skip: (_ forward: Bool) -> Void
            let drag: (_ fraction: Double) -> Void
            let endDrag: () -> Void

            var body: some View {
                VStack {
                    Spacer()
                    HStack(spacing: 36) {
                        round("gobackward.10", label: "Back 10 seconds", id: "title.transport.skipBack", font: .title2) { skip(false) }
                        round(
                            isPaused ? "play.fill" : "pause.fill", label: isPaused ? "Play" : "Pause", id: "title.transport.playPause",
                            font: .largeTitle, action: playPause)
                        round("goforward.10", label: "Forward 10 seconds", id: "title.transport.skipForward", font: .title2) { skip(true) }
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        Text(times.elapsed)
                            .accessibilityIdentifier("title.transport.elapsed")
                        if let fraction = times.fraction {
                            scrubber(fraction)
                        } else {
                            Spacer()
                        }
                        if let remaining = times.remaining {
                            Text(remaining)
                                .accessibilityIdentifier("title.transport.remaining")
                        }
                    }
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("title.transport")
            }

            private func scrubber(_ fraction: Double) -> some View {
                GeometryReader { proxy in
                    let width = max(1, proxy.size.width)
                    let at = width * min(1, max(0, fraction))
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.surface(0.3)).frame(height: 4)
                        Capsule().fill(Palette.accent).frame(width: at, height: 4)
                        Circle().fill(Palette.text)
                            .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
                            .frame(width: 18, height: 18)
                            .offset(x: at - 9)
                    }
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag($0.location.x / width) }
                            .onEnded { _ in endDrag() })
                }
                .frame(height: 44)
                .accessibilityElement()
                .accessibilityLabel("Position")
                .accessibilityValue(times.spoken)
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: skip(true)
                    case .decrement: skip(false)
                    @unknown default: break
                    }
                }
                .accessibilityIdentifier("title.transport.scrubber")
            }

            private func round(_ symbol: String, label: String, id: String, font: Font, action: @escaping () -> Void) -> some View {
                Button(action: action) {
                    Image(systemName: symbol)
                        .font(font)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel(label)
                .accessibilityIdentifier(id)
            }
        }
    }

    private let previewTimes = Transport.Times(
        elapsed: "12:04", remaining: "-1:17:56", fraction: 724.0 / 5400, spoken: "12 minutes, 4 seconds of 1 hour, 30 minutes")

    #Preview("Transport controls, iPhone, playing", traits: .fixedLayout(width: 390, height: 844)) {
        Transport.Controls(times: previewTimes, isPaused: false, playPause: {}, skip: { _ in }, drag: { _ in }, endDrag: {})
            .background(Color(white: 0.2))
    }

    #Preview("Transport controls, iPad, paused", traits: .fixedLayout(width: 1180, height: 820)) {
        Transport.Controls(times: previewTimes, isPaused: true, playPause: {}, skip: { _ in }, drag: { _ in }, endDrag: {})
            .background(Color(white: 0.2))
    }

    #Preview("Transport controls, no length yet", traits: .fixedLayout(width: 390, height: 300)) {
        Transport.Controls(
            times: .init(elapsed: "0:42", remaining: nil, fraction: nil, spoken: "42 seconds"), isPaused: false, playPause: {},
            skip: { _ in }, drag: { _ in }, endDrag: {}
        )
        .background(Color(white: 0.2))
    }
#endif

#Preview("Transport notice", traits: .fixedLayout(width: 500, height: 80)) {
    Transport.Notice(text: "This stream can't skip")
        .padding()
        .background(Palette.ground)
}
