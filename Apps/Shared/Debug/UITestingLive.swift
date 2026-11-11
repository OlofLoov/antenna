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
        /// Seconds a tap keeps the player controls up. Unset, they stay up
        /// for a minute, so a slow runner can read them before they hide.
        static let controlsVariable = "UITESTING_CONTROLS_SECONDS"

        enum Scenario: String {
            /// Home (M3U) with News One and News Two in News, Sport One in
            /// Sport and Kids One with no group; Cabin (Xtream) with Cabin
            /// Film in Films, which has seven days of catch-up.
            case channels
            /// As `channels`, with Sport One a favorite.
            case favorites
            /// Home loads; Cabin never finishes.
            case loading
            /// Both sources fail because the device is offline.
            case offline
            /// Home loads; Cabin's first load fails and the next succeeds.
            case failing
            /// Home fails; Cabin has no login on this device.
            case error
            /// Home loads no channels; Cabin has no login on this device.
            case empty
            /// Home loads; Cabin's login arrives 6 seconds after launch.
            case waiting
        }

        static let homeID = UUID(uuidString: "00000000-0000-0000-0000-0000000000D1") ?? UUID()
        static let cabinID = UUID(uuidString: "00000000-0000-0000-0000-0000000000D2") ?? UUID()

        static func scenario(arguments: [String] = ProcessInfo.processInfo.arguments) -> Scenario? {
            guard let index = arguments.firstIndex(of: argument) else { return nil }
            let next = arguments.index(after: index)
            guard next < arguments.endIndex, let scenario = Scenario(rawValue: arguments[next]) else {
                fatalError("\(argument) takes channels, favorites, loading, offline, failing, error, empty or waiting")
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
                id: "fixture/\(id)", name: name, streamURL: URL(fileURLWithPath: "/fixture/\(id).\(streamExtension)"), group: group,
                number: number, hasCatchup: catchUp != nil, catchupDays: catchUp)
        }

        /// "m3u8" with `UITESTING_HLS=1`, so every stream goes to Apple's
        /// player and can go to AirPlay; "ts" otherwise.
        static var streamExtension: String {
            ProcessInfo.processInfo.environment["UITESTING_HLS"] == "1" ? "m3u8" : "ts"
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
            guard let scenario = scenario() else { return nil }
            let environment = ProcessInfo.processInfo.environment
            let log = environment[logVariable].map { URL(fileURLWithPath: $0) }
            let script = Script(scenario: scenario)
            var dependencies = LiveModel.Dependencies(
                engine: Engine(log: log),
                load: { try await script.load($0) },
                hasLogin: { script.hasLogin($0) },
                guide: nil,
                programmes: guide)
            dependencies.touchHold = .seconds(environment[controlsVariable].flatMap(Double.init) ?? 60)
            dependencies.network = UITestingPlayback.network
            dependencies.slowDelay = UITestingPlayback.slowDelay
            return dependencies
        }

        /// What each scenario's sources answer.
        @MainActor
        final class Script {
            let scenario: Scenario
            private var cabinLoads = 0

            init(scenario: Scenario) {
                self.scenario = scenario
            }

            func hasLogin(_ source: SourceDescriptor) -> Bool {
                guard source.id == cabinID else { return true }
                switch scenario {
                case .error, .empty: return false
                case .waiting: return Date.now.timeIntervalSince(launched) > 6
                case .channels, .favorites, .loading, .offline, .failing: return true
                }
            }

            func load(_ source: SourceDescriptor) async throws -> Playlist {
                let isHome = source.id == homeID
                if !isHome { cabinLoads += 1 }
                switch scenario {
                case .channels, .favorites, .waiting:
                    return Playlist(channels: isHome ? home : cabin)
                case .loading:
                    if !isHome { try await Task.sleep(for: .seconds(3600)) }
                    return Playlist(channels: home)
                case .offline:
                    throw URLError(.notConnectedToInternet)
                case .failing:
                    if !isHome, cabinLoads == 1 { throw URLError(.badServerResponse) }
                    return Playlist(channels: isHome ? home : cabin)
                case .error:
                    throw URLError(.cannotFindHost)
                case .empty:
                    return Playlist(channels: [])
                }
            }
        }

        /// News One has a programme on now and four after it. Sport One's
        /// First Half ends 15 seconds after launch and Second Half follows.
        /// News Two's guide is still loading, the rest have none.
        @MainActor static var guide: OverlayGuide {
            OverlayGuide(
                state: { channel in channel.id == "fixture/news-two" ? .loading : .loaded },
                current: { channel, date in programmes(for: channel).first { $0.start <= date && date < $0.stop } },
                next: { channel, date, count in Array(programmes(for: channel).filter { $0.start >= date }.prefix(count)) })
        }

        @MainActor private static func programmes(for channel: Channel) -> [Programme] {
            switch channel.id {
            case "fixture/news-one":
                let morning = Programme(
                    channelID: channel.id, start: launched.addingTimeInterval(-1800), stop: launched.addingTimeInterval(1800),
                    title: "Morning News", summary: "Headlines and weather.")
                let titles = ["Weather", "Business", "Sport Tonight", "Late Film"]
                return [morning]
                    + zip(titles.indices, titles).map { index, title in
                        let start = launched.addingTimeInterval(1800 + Double(index) * 1800)
                        return Programme(channelID: channel.id, start: start, stop: start.addingTimeInterval(1800), title: title)
                    }
            case "fixture/sport-one":
                let change = launched.addingTimeInterval(15)
                return [
                    Programme(channelID: channel.id, start: launched.addingTimeInterval(-600), stop: change, title: "First Half"),
                    Programme(channelID: channel.id, start: change, stop: change.addingTimeInterval(3600), title: "Second Half"),
                ]
            default:
                return []
            }
        }

        /// Records what Live asks of the player.
        @MainActor @Observable
        final class Engine: PlaybackEngine {
            private(set) var state: PlaybackState = .idle {
                didSet { stateCast.send(state) }
            }
            @ObservationIgnored private let stateCast = Broadcast(PlaybackState.idle)
            @ObservationIgnored private let trackList = UITestingPlayback.Tracks()
            private(set) var loads = 0
            private let log: URL?

            init(log: URL?) {
                self.log = log
            }

            var capabilities: EngineCapabilities { EngineCapabilities(supportsPictureInPicture: false) }

            func load(_ url: URL, options: PlaybackOptions) async throws {
                loads += 1
                append(url.lastPathComponent)
                trackList.reset()
                switch UITestingPlayback.afterLoad(url.lastPathComponent) {
                case .success(let next):
                    state = next
                case .failure(let reason):
                    state = .failed(reason)
                    throw reason
                }
            }

            func play() async {
                if case .failed = state { return }
                guard UITestingPlayback.plays else { return }
                state = .playing
                guard UITestingPlayback.drops else { return }
                let loaded = loads
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(1))
                    guard let self, loads == loaded, state == .playing else { return }
                    state = .reconnecting(attempt: 2, of: 3)
                }
            }

            func pause() async {
                state = .paused
            }

            func stop() async {
                state = .idle
            }

            func seek(to time: Duration) async throws { throw SeekRefusal.live }
            func selectAudio(_ id: MediaTrack.ID) async { trackList.selectAudio(id) }
            func selectSubtitle(_ id: MediaTrack.ID?) async { trackList.selectSubtitle(id) }
            func states() async -> AsyncStream<PlaybackState> { stateCast.stream() }
            func presentation() async -> AsyncStream<PresentationInfo?> { trackList.format.stream() }
            func tracks() async -> AsyncStream<TrackList> { trackList.cast.stream() }
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
