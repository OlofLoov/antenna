#if DEBUG
    import AntennaCore
    import Foundation
    import SwiftUI

    extension UITestingShelf {
        /// Scripted playback for any UI testing launch, or nil. Titles play
        /// from `/fixture/<raw id>.mp4` on an engine that records what it
        /// loaded and where it started.
        @MainActor
        static func playback(willPlay: @escaping @MainActor () async -> Void) -> ShelfPlayback? {
            guard ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-ui-testing-") }) else { return nil }
            return ShelfPlayback(
                .init(
                    engine: Engine(),
                    address: { _, target in
                        let raw: Int? =
                            switch target {
                            case .movie(let movie): XtreamTitleID(parsing: movie.id)?.rawID
                            case .episode(let episode, _): episode.episodeID
                            }
                        return URL(fileURLWithPath: "/fixture/\(raw ?? 0).mp4")
                    },
                    willPlay: willPlay))
        }

        /// The links the title page opened, instead of leaving the app.
        @MainActor @Observable
        final class Opened {
            static let shared = Opened()
            private(set) var last = ""

            /// Records `url` and keeps the app in front.
            var action: OpenURLAction {
                OpenURLAction { url in
                    self.last = url.absoluteString
                    return .handled
                }
            }
        }

        /// The last link the page opened, read by the UI tests through
        /// `shelf.debug.opened`.
        struct OpenedProbe: View {
            var body: some View {
                Text(Opened.shared.last)
                    .font(.system(size: 8))
                    .foregroundStyle(Palette.textMuted)
                    .accessibilityIdentifier("shelf.debug.opened")
                    .accessibilityValue(Opened.shared.last)
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }

        /// Records what the Movies and Series sections ask of the player.
        @MainActor @Observable
        final class Engine: PlaybackEngine {
            private(set) var state: PlaybackState = .idle {
                didSet { stateCast.send(state) }
            }
            @ObservationIgnored private let stateCast = Broadcast(PlaybackState.idle)
            @ObservationIgnored private let positionCast = Broadcast(PlaybackPosition.zero)
            private(set) var loaded = ""
            private(set) var start = 0

            var capabilities: EngineCapabilities { EngineCapabilities(supportsPictureInPicture: false) }

            func load(_ url: URL, options: PlaybackOptions) async throws {
                loaded = url.lastPathComponent
                start = Int(options.startPosition.map { ShelfPlayback.seconds($0) } ?? 0)
                state = .loading
            }

            func play() async {
                state = .playing
                positionCast.send(PlaybackPosition(time: .seconds(start), duration: .seconds(5400), isLive: false))
            }

            func pause() async { state = .paused }
            func stop() async { state = .idle }
            func seek(to time: Duration) async throws {}
            func selectAudio(_ id: MediaTrack.ID) async {}
            func selectSubtitle(_ id: MediaTrack.ID?) async {}
            func states() async -> AsyncStream<PlaybackState> { stateCast.stream() }
            func presentation() async -> AsyncStream<PresentationInfo?> { Broadcast(PresentationInfo?.none).stream() }
            func tracks() async -> AsyncStream<TrackList> { Broadcast(TrackList.empty).stream() }
            func position() async -> AsyncStream<PlaybackPosition> { positionCast.stream() }
            func subtitleCues() async -> AsyncStream<[SubtitleCue]> { Broadcast([SubtitleCue]()).stream() }

            /// `"<state> <file> from <seconds>"`.
            var summary: String {
                let name =
                    switch state {
                    case .idle: "idle"
                    case .loading: "loading"
                    case .playing: "playing"
                    case .paused: "paused"
                    case .buffering: "buffering"
                    case .reconnecting: "reconnecting"
                    case .ended: "ended"
                    case .failed: "failed"
                    }
                return "\(name) \(loaded) from \(start)"
            }
        }

        /// A tiny text the UI tests read through `shelf.debug.engine`. Draws
        /// nothing outside UI tests.
        struct Probe: View {
            let engine: any PlaybackEngine

            var body: some View {
                if let engine = engine as? Engine {
                    Text(engine.summary)
                        .font(.system(size: 8))
                        .foregroundStyle(Palette.textMuted)
                        .accessibilityIdentifier("shelf.debug.engine")
                        .accessibilityValue(engine.summary)
                        .allowsHitTesting(false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
        }
    }
#endif
