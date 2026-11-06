#if DEBUG
    import AntennaCore
    import Foundation
    import SwiftData
    import SwiftUI

    /// Scripted sources and a recording engine for the Apple TV shell's UI
    /// tests (tvos-shell capability), compiled into Debug builds only.
    ///
    /// `-ui-testing-shell <scenario>` starts the app on an in-memory store
    /// with two sources. Nothing reaches the network, iCloud or the Keychain.
    enum UITestingShell {
        static let argument = "-ui-testing-shell"

        enum Scenario: String {
            /// An M3U source with three channels and an Xtream source with one.
            case channels
            /// As `channels`, but every engine load fails.
            case failing
            /// Two sources whose loads never finish.
            case loading
            /// An M3U source with no channels and an Xtream source with no
            /// login. Later loads never finish, so Retry shows the loading screen.
            case empty
        }

        static let playlistID = UUID(uuidString: "00000000-0000-0000-0000-00000000000A") ?? UUID()
        static let xtreamID = UUID(uuidString: "00000000-0000-0000-0000-00000000000B") ?? UUID()

        static func scenario(arguments: [String] = ProcessInfo.processInfo.arguments) -> Scenario? {
            guard let index = arguments.firstIndex(of: argument) else { return nil }
            let next = arguments.index(after: index)
            guard next < arguments.endIndex, let scenario = Scenario(rawValue: arguments[next]) else {
                fatalError("\(argument) takes channels, failing, loading or empty")
            }
            return scenario
        }

        /// The seeded store, or nil when the app was not launched for these tests.
        static func container() -> ModelContainer? {
            guard scenario() != nil else { return nil }
            let schema = Schema([SourceRecord.self, FavoriteRecord.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                let container = try ModelContainer(for: schema, configurations: [config])
                let context = ModelContext(container)
                for (order, descriptor) in sources.enumerated() {
                    context.insert(SourceRecord(descriptor: descriptor, sortOrder: order))
                }
                try context.save()
                return container
            } catch {
                fatalError("Could not create the shell UI testing store: \(error)")
            }
        }

        private static var sources: [SourceDescriptor] {
            [
                SourceDescriptor(
                    id: playlistID, name: "Home playlist", kind: .m3u,
                    url: URL(fileURLWithPath: "/fixture/home.m3u")),
                SourceDescriptor(
                    id: xtreamID, name: "Cabin", kind: .xtream,
                    url: URL(fileURLWithPath: "/fixture/cabin"), credentialKey: "fixture"),
            ]
        }

        static func channel(_ id: String) -> Channel {
            Channel(id: "fixture/\(id)", name: "Channel \(id)", streamURL: URL(fileURLWithPath: "/fixture/\(id).ts"))
        }
    }

    #if os(tvOS)
        extension UITestingShell {
            /// The shell's dependencies for the launch scenario, or nil.
            @MainActor
            static func dependencies() -> ShellModel.Dependencies? {
                guard let scenario = scenario() else { return nil }
                let engine = Engine(failing: scenario == .failing)
                let script = Script(scenario: scenario)
                let defaults = UserDefaults(suiteName: "ui-testing-shell") ?? .standard
                defaults.removePersistentDomain(forName: "ui-testing-shell")
                return ShellModel.Dependencies(
                    engine: engine,
                    load: { try await script.load($0) },
                    hasLogin: { source in scenario != .empty || source.id != xtreamID },
                    lastChannel: LastChannelStore(defaults: defaults),
                    sleep: { try await Task.sleep(for: $0) },
                    guide: nil)
            }

            /// What each scenario's sources answer.
            @MainActor
            final class Script {
                let scenario: Scenario
                private var calls = 0

                init(scenario: Scenario) {
                    self.scenario = scenario
                }

                func load(_ source: SourceDescriptor) async throws -> Playlist {
                    calls += 1
                    switch scenario {
                    case .channels, .failing:
                        return source.id == playlistID
                            ? Playlist(channels: ["a1", "a2", "a3"].map(channel))
                            : Playlist(channels: [channel("b1")])
                    case .loading:
                        try await Task.sleep(for: .seconds(3600))
                        return Playlist(channels: [])
                    case .empty:
                        if calls > 1 { try await Task.sleep(for: .seconds(3600)) }
                        return Playlist(channels: [])
                    }
                }
            }

            /// Records what the shell asks of the player, for the probe.
            @MainActor @Observable
            final class Engine: PlaybackEngine {
                private(set) var state: PlaybackState = .idle
                private(set) var loads = 0
                private(set) var lastFile = ""
                private let failing: Bool

                init(failing: Bool) {
                    self.failing = failing
                }

                var capabilities: EngineCapabilities { EngineCapabilities(supportsPictureInPicture: false) }

                func load(_ url: URL, options: PlaybackOptions) async throws {
                    loads += 1
                    lastFile = url.lastPathComponent
                    if failing {
                        state = .failed(.unreadable)
                        throw PlaybackFailure.unreadable
                    }
                    state = .loading
                }

                func play() async {
                    if case .failed = state { return }
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
                func states() async -> AsyncStream<PlaybackState> { Broadcast(state).stream() }
                func presentation() async -> AsyncStream<PresentationInfo?> { Broadcast(PresentationInfo?.none).stream() }
                func tracks() async -> AsyncStream<TrackList> { Broadcast(TrackList.empty).stream() }
                func position() async -> AsyncStream<PlaybackPosition> { Broadcast(PlaybackPosition.zero).stream() }
                func subtitleCues() async -> AsyncStream<[SubtitleCue]> { Broadcast([SubtitleCue]()).stream() }

                /// `"<state> loads=<n> file=<last file name>"`.
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
                    return "\(name) loads=\(loads) file=\(lastFile)"
                }
            }

            /// A tiny text the UI tests read through `shell.debug.engine`.
            /// Draws nothing outside UI tests.
            struct Probe: View {
                let engine: any PlaybackEngine

                var body: some View {
                    if let engine = engine as? Engine {
                        Text(engine.summary)
                            .font(.system(size: 18))
                            .foregroundStyle(Palette.textMuted)
                            .accessibilityIdentifier("shell.debug.engine")
                            .accessibilityValue(engine.summary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
    #endif
#endif
