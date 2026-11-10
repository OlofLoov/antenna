#if DEBUG
    import AntennaCore
    import Foundation
    import SwiftData
    import SwiftUI

    /// Scripted sources, guide and engine for the Live screen's UI tests on
    /// iPhone, iPad and Mac (live-tv-on-iphone-ipad-mac capability),
    /// compiled into Debug builds only.
    ///
    /// `-ui-testing-live <scenario>` starts the app on an in-memory store.
    /// Nothing reaches the network, iCloud or the Keychain. When the
    /// environment names a file in `UITESTING_ENGINE_LOG`, the engine
    /// appends the file name of each stream it loads to it, one per line,
    /// so a test can check what played without the app putting anything
    /// from a stream link on screen.
    enum UITestingLive {
        static let argument = "-ui-testing-live"
        static let logVariable = "UITESTING_ENGINE_LOG"

        enum Scenario: String {
            /// Home (M3U) with News One and News Two in News, Sport One in
            /// Sport and Kids One with no group; Cabin (Xtream) with Cabin
            /// Film in Films, which has seven days of catch-up.
            case channels
            /// As `channels`, with Sport One a favorite.
            case favorites
        }

        static let homeID = UUID(uuidString: "00000000-0000-0000-0000-0000000000D1") ?? UUID()
        static let cabinID = UUID(uuidString: "00000000-0000-0000-0000-0000000000D2") ?? UUID()

        static func scenario(arguments: [String] = ProcessInfo.processInfo.arguments) -> Scenario? {
            guard let index = arguments.firstIndex(of: argument) else { return nil }
            let next = arguments.index(after: index)
            guard next < arguments.endIndex, let scenario = Scenario(rawValue: arguments[next]) else {
                fatalError("\(argument) takes channels or favorites")
            }
            return scenario
        }

        /// The seeded store, or nil when the app was not launched for these tests.
        static func container() -> ModelContainer? {
            guard let scenario = scenario() else { return nil }
            let schema = Schema(AntennaSchema.models)
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                let container = try ModelContainer(for: schema, configurations: [config])
                let context = ModelContext(container)
                context.insert(
                    SourceRecord(
                        descriptor: SourceDescriptor(id: homeID, name: "Home", kind: .m3u, url: URL(fileURLWithPath: "/fixture/home.m3u")),
                        sortOrder: 0))
                context.insert(
                    SourceRecord(
                        descriptor: SourceDescriptor(
                            id: cabinID, name: "Cabin", kind: .xtream, url: URL(fileURLWithPath: "/fixture/cabin"), credentialKey: "fixture"
                        ),
                        sortOrder: 1))
                if scenario == .favorites {
                    context.insert(FavoriteRecord(channelID: "fixture/sport-one", sourceID: homeID, sortOrder: 0))
                }
                try context.save()
                return container
            } catch {
                fatalError("Could not create the Live UI testing store: \(error)")
            }
        }

        static func channel(_ id: String, _ name: String, group: String?, number: Int, catchUp: Int? = nil) -> Channel {
            Channel(
                id: "fixture/\(id)", name: name, streamURL: URL(fileURLWithPath: "/fixture/\(id).ts"), group: group, number: number,
                hasCatchup: catchUp != nil, catchupDays: catchUp)
        }

        static let home = [
            channel("news-one", "News One", group: "News", number: 1),
            channel("news-two", "News Two", group: "News", number: 2),
            channel("sport-one", "Sport One", group: "Sport", number: 3),
            channel("kids-one", "Kids One", group: nil, number: 4),
        ]
        static let cabin = [channel("cabin-film", "Cabin Film", group: "Films", number: 5, catchUp: 7)]

        /// When the app launched, so the scripted programmes are on now.
        @MainActor static let launched = Date.now

        /// The Live screen's dependencies for the launch scenario, or nil.
        @MainActor
        static func dependencies() -> LiveModel.Dependencies? {
            guard scenario() != nil else { return nil }
            let log = ProcessInfo.processInfo.environment[logVariable].map { URL(fileURLWithPath: $0) }
            return LiveModel.Dependencies(
                engine: Engine(log: log),
                load: { source in Playlist(channels: source.id == homeID ? home : cabin) },
                hasLogin: { _ in true },
                guide: nil,
                programmes: guide)
        }

        /// News One has a programme on now and four after it, News Two's
        /// guide is still loading, the rest have none.
        @MainActor static var guide: OverlayGuide {
            OverlayGuide(
                state: { channel in channel.id == "fixture/news-two" ? .loading : .loaded },
                current: { channel, _ in
                    guard channel.id == "fixture/news-one" else { return nil }
                    return Programme(
                        channelID: channel.id, start: launched.addingTimeInterval(-1800), stop: launched.addingTimeInterval(1800),
                        title: "Morning News", summary: "Headlines and weather.")
                },
                next: { channel, _, count in
                    guard channel.id == "fixture/news-one" else { return [] }
                    let titles = ["Weather", "Business", "Sport Tonight", "Late Film"]
                    return zip(titles.indices, titles).prefix(count).map { index, title in
                        let start = launched.addingTimeInterval(1800 + Double(index) * 1800)
                        return Programme(channelID: channel.id, start: start, stop: start.addingTimeInterval(1800), title: title)
                    }
                })
        }

        /// Records what Live asks of the player.
        @MainActor @Observable
        final class Engine: PlaybackEngine {
            private(set) var state: PlaybackState = .idle {
                didSet { stateCast.send(state) }
            }
            @ObservationIgnored private let stateCast = Broadcast(PlaybackState.idle)
            private(set) var loads = 0
            private let log: URL?

            init(log: URL?) {
                self.log = log
            }

            var capabilities: EngineCapabilities { EngineCapabilities(supportsPictureInPicture: false) }

            func load(_ url: URL, options: PlaybackOptions) async throws {
                loads += 1
                state = .loading
                append(url.lastPathComponent)
            }

            func play() async {
                state = .playing
            }

            func pause() async {
                state = .paused
            }

            func stop() async {
                state = .idle
            }

            func seek(to time: Duration) async throws { throw SeekRefusal.live }
            func selectAudio(_ id: MediaTrack.ID) async {}
            func selectSubtitle(_ id: MediaTrack.ID?) async {}
            func states() async -> AsyncStream<PlaybackState> { stateCast.stream() }
            func presentation() async -> AsyncStream<PresentationInfo?> { Broadcast(PresentationInfo?.none).stream() }
            func tracks() async -> AsyncStream<TrackList> { Broadcast(TrackList.empty).stream() }
            func position() async -> AsyncStream<PlaybackPosition> { Broadcast(PlaybackPosition.zero).stream() }
            func subtitleCues() async -> AsyncStream<[SubtitleCue]> { Broadcast([SubtitleCue]()).stream() }

            private func append(_ line: String) {
                guard let log else { return }
                let data = Data((line + "\n").utf8)
                if let handle = try? FileHandle(forWritingTo: log) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                } else {
                    try? data.write(to: log)
                }
            }

            /// `"<state> loads=<n>"`.
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
                return "\(name) loads=\(loads)"
            }
        }

        /// Lets a UI test switch an iPad window between the narrow and the
        /// wide layout, which XCUITest cannot do by resizing the window.
        @MainActor @Observable
        final class Layout {
            static let shared = Layout()
            /// True shows the narrow layout whatever the window's size.
            var compact = false
        }

        /// A tiny text the UI tests read through `browse.debug.engine`, and
        /// a button, `browse.debug.switchLayout`, that flips `Layout.compact`.
        /// Draws nothing outside UI tests.
        struct Probe: View {
            let engine: any PlaybackEngine

            var body: some View {
                if let engine = engine as? Engine {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(engine.summary)
                            .font(.system(size: 8))
                            .foregroundStyle(Palette.textMuted)
                            .accessibilityIdentifier("browse.debug.engine")
                            .accessibilityValue(engine.summary)
                            .allowsHitTesting(false)
                        Button("Switch layout") { Layout.shared.compact.toggle() }
                            .font(.system(size: 8))
                            .foregroundStyle(Palette.textMuted)
                            .frame(minWidth: 44, minHeight: 24)
                            .contentShape(Rectangle())
                            .accessibilityIdentifier("browse.debug.switchLayout")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
        }
    }
#endif
